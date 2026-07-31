"""
DFU MobileNetV3-Small — Training & ONNX Export Pipeline
========================================================
Dataset layout expected (already downloaded):
  dfu_dataset/
    Grade0/  *.jpg / *.jpeg / *.png  ...
    Grade1/  ...
    Grade2/  ...
    Grade3/  ...
    Grade4/  ...
    Grade5/  ...

Steps:
  1. Split dfu_dataset into train / val (80/20 stratified)
  2. Train MobileNetV3-Small (pretrained ImageNet, 6-class head)
     - Weighted CrossEntropy to handle class imbalance
     - CosineAnnealing LR scheduler
     - Best-checkpoint saved
  3. Evaluate on validation set (per-class accuracy)
  4. Export best weights to ONNX (opset 17)
  5. Copy ONNX + PTH into dfu_backend/models/ (replaces old files)

Usage:
    python train_and_export.py
"""

import os
import random
import shutil
import time

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
import torchvision.models as models
import torchvision.transforms as transforms
from PIL import Image
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
# Absolute/relative source folder for each grade (new Google-Drive export dirs)
GRADE_DIRS = {
    0: "GR 0-20260719T092049Z-1-001/GR 0",
    1: "GR 1-20260719T092355Z-1-001/GR 1",
    2: "GR 2-20260719T092358Z-1-001/GR 2",
    3: "GR 3-20260719T092401Z-1-001/GR 3",
    4: "GR 4-20260719T092404Z-1-001/GR 4",
    5: "GR 5-20260719T092407Z-1-001/GR 5",
}

CLASS_LABELS = [
    "Grade 0 - Healthy",
    "Grade 1 - Surface Ulcer",
    "Grade 2 - Deep Ulcer",
    "Grade 3 - Osteomyelitis",
    "Grade 4 - Localized Gangrene",
    "Grade 5 - Extensive Gangrene",
]

RAW_DIR    = "dfu_dataset"          # already downloaded — do NOT delete
TRAIN_DIR  = "dfu_train"
VAL_DIR    = "dfu_val"
MODEL_DIR  = os.path.join("dfu_backend", "models")

ONNX_NAME  = "ulcer_classification_mobilenetv3.onnx"
PTH_NAME   = "ulcer_classification_mobilenetv3.pth"

IMG_SIZE    = 224
BATCH_SIZE  = 16          # small dataset → smaller batch is fine
NUM_EPOCHS  = 25          # more epochs since dataset is small
LR          = 5e-4
VAL_SPLIT   = 0.20
SEED        = 42
NUM_CLASSES = 6

VALID_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

random.seed(SEED)
np.random.seed(SEED)
torch.manual_seed(SEED)

# ---------------------------------------------------------------------------
# 1. Train / Val split  (stratified per grade)
# ---------------------------------------------------------------------------
def build_splits():
    print("\n=== Step 1: Building train/val splits ===")
    for split_dir in [TRAIN_DIR, VAL_DIR]:
        if os.path.exists(split_dir):
            shutil.rmtree(split_dir)

    for grade, folder_name in GRADE_DIRS.items():
        src = folder_name
        if not os.path.exists(src):
            print(f"  WARNING: {src} not found — skipping grade {grade}")
            continue

        files = [f for f in os.listdir(src)
                 if os.path.splitext(f)[1].lower() in VALID_EXTS]
        random.shuffle(files)

        split_idx = max(1, int(len(files) * (1 - VAL_SPLIT)))
        train_files = files[:split_idx]
        val_files   = files[split_idx:]

        # Ensure at least 1 val sample even for tiny classes
        if len(val_files) == 0 and len(train_files) > 1:
            val_files   = [train_files.pop()]

        # destination sub-dir is always grade_N for the Dataset class
        dest_name = f"grade_{grade}"
        for split_dir, split_files in [(TRAIN_DIR, train_files), (VAL_DIR, val_files)]:
            dest = os.path.join(split_dir, dest_name)
            os.makedirs(dest, exist_ok=True)
            for f in split_files:
                shutil.copy2(os.path.join(src, f), os.path.join(dest, f))

        print(f"  Grade {grade} ({folder_name}): "
              f"{len(train_files)} train / {len(val_files)} val")


# ---------------------------------------------------------------------------
# 2. Dataset
# ---------------------------------------------------------------------------
TRAIN_TRANSFORMS = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomVerticalFlip(),
    transforms.RandomRotation(20),
    transforms.ColorJitter(brightness=0.3, contrast=0.3,
                           saturation=0.2, hue=0.05),
    transforms.RandomAffine(degrees=0, translate=(0.1, 0.1),
                            scale=(0.85, 1.15)),
    transforms.RandomGrayscale(p=0.05),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                         std=[0.229, 0.224, 0.225]),
])

VAL_TRANSFORMS = transforms.Compose([
    transforms.Resize((IMG_SIZE, IMG_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406],
                         std=[0.229, 0.224, 0.225]),
])


class DFUDataset(Dataset):
    """Loads images from grade_N subdirectories under root."""

    def __init__(self, root: str, transform=None):
        self.transform = transform
        self.samples: list[tuple[str, int]] = []

        for grade in range(NUM_CLASSES):
            grade_dir = os.path.join(root, f"grade_{grade}")
            if not os.path.exists(grade_dir):
                continue
            for fname in os.listdir(grade_dir):
                if os.path.splitext(fname)[1].lower() in VALID_EXTS:
                    self.samples.append(
                        (os.path.join(grade_dir, fname), grade)
                    )

        if not self.samples:
            raise ValueError(f"No images found under {root}")

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        path, label = self.samples[idx]
        try:
            img = Image.open(path).convert("RGB")
        except Exception:
            img = Image.new("RGB", (IMG_SIZE, IMG_SIZE), color=(128, 128, 128))
        if self.transform:
            img = self.transform(img)
        return img, label


# ---------------------------------------------------------------------------
# 3. Build model
# ---------------------------------------------------------------------------
def build_model() -> nn.Module:
    model = models.mobilenet_v3_small(
        weights=models.MobileNet_V3_Small_Weights.IMAGENET1K_V1
    )
    in_features = model.classifier[3].in_features
    # Stronger dropout than the torchvision default (0.2) — the dataset is
    # tiny (92 train images) and the model overfits fast, so we lean on
    # heavier regularization to keep the minority classes (e.g. Grade 1,
    # 8 train images) from being memorized/ignored.
    model.classifier[2] = nn.Dropout(p=0.4, inplace=True)
    model.classifier[3] = nn.Linear(in_features, NUM_CLASSES)
    return model


# ---------------------------------------------------------------------------
# 4. Train
# ---------------------------------------------------------------------------
def train():
    print("\n=== Step 2: Training MobileNetV3-Small ===")
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"  Device: {device}")

    train_ds = DFUDataset(TRAIN_DIR, TRAIN_TRANSFORMS)
    val_ds   = DFUDataset(VAL_DIR,   VAL_TRANSFORMS)
    print(f"  Train samples : {len(train_ds)}")
    print(f"  Val   samples : {len(val_ds)}")

    # Per-class sample counts — used to build a WeightedRandomSampler so that
    # every epoch draws roughly equally from all six grades, instead of the
    # majority classes (e.g. Grade 2, 22 images) dominating gradient updates
    # while the minority classes (e.g. Grade 1, 8 images) are barely seen.
    labels       = [s[1] for s in train_ds.samples]
    class_counts = np.bincount(labels, minlength=NUM_CLASSES).astype(np.float32)
    class_counts = np.where(class_counts == 0, 1.0, class_counts)   # avoid /0
    inv_freq     = 1.0 / class_counts
    print("  Class counts (train):", class_counts.astype(int).tolist())

    sample_weights = torch.tensor(
        [inv_freq[l] for l in labels], dtype=torch.double
    )
    sampler = WeightedRandomSampler(
        weights=sample_weights, num_samples=len(train_ds), replacement=True
    )

    train_loader = DataLoader(train_ds, batch_size=BATCH_SIZE,
                              sampler=sampler, num_workers=0, pin_memory=False)
    val_loader   = DataLoader(val_ds,   batch_size=BATCH_SIZE,
                              shuffle=False, num_workers=0, pin_memory=False)

    model = build_model().to(device)
    # Class balance is now handled by the sampler above, so the loss itself
    # stays unweighted (avoids double-correcting) but adds label smoothing —
    # cheap extra regularization against the severe overfitting seen on a
    # 92-image training set (train acc hit 100% by epoch 25 previously).
    criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
    optimizer = optim.AdamW(model.parameters(), lr=LR, weight_decay=2e-4)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(
        optimizer, T_max=NUM_EPOCHS, eta_min=1e-6
    )

    best_macro_acc = -1.0
    best_val_acc   = 0.0
    best_state     = None

    for epoch in range(1, NUM_EPOCHS + 1):
        # ---- train ----
        model.train()
        run_loss = correct = total = 0
        t0 = time.time()

        for imgs, lbls in train_loader:
            imgs, lbls = imgs.to(device), lbls.to(device)
            optimizer.zero_grad()
            out  = model(imgs)
            loss = criterion(out, lbls)
            loss.backward()
            optimizer.step()
            run_loss += loss.item() * imgs.size(0)
            correct  += (out.argmax(1) == lbls).sum().item()
            total    += imgs.size(0)

        train_loss = run_loss / total
        train_acc  = correct / total

        # ---- val ----
        model.eval()
        v_loss = v_correct = v_total = 0
        per_class_correct = np.zeros(NUM_CLASSES)
        per_class_total   = np.zeros(NUM_CLASSES)
        with torch.no_grad():
            for imgs, lbls in val_loader:
                imgs, lbls = imgs.to(device), lbls.to(device)
                out   = model(imgs)
                preds = out.argmax(1)
                v_loss    += criterion(out, lbls).item() * imgs.size(0)
                v_correct += (preds == lbls).sum().item()
                v_total   += imgs.size(0)
                for c in range(NUM_CLASSES):
                    mask = (lbls == c)
                    per_class_total[c]   += mask.sum().item()
                    per_class_correct[c] += (preds[mask] == c).sum().item()

        val_loss = v_loss / v_total
        val_acc  = v_correct / v_total
        # Macro-average accuracy: mean of per-class accuracy, giving Grade 1
        # (3 val samples) equal weight to Grade 2 (6 val samples) instead of
        # letting overall accuracy be dominated by the larger classes.
        present = per_class_total > 0
        macro_acc = float(np.mean(per_class_correct[present] / per_class_total[present]))
        scheduler.step()

        is_best = macro_acc > best_macro_acc or (
            macro_acc == best_macro_acc and val_acc > best_val_acc
        )
        marker = " <- best" if is_best else ""
        print(f"  [{epoch:02d}/{NUM_EPOCHS}]  "
              f"train {train_loss:.4f}/{train_acc:.4f}  "
              f"val {val_loss:.4f}/{val_acc:.4f}  macro {macro_acc:.4f}  "
              f"[{time.time()-t0:.1f}s]{marker}")

        if is_best:
            best_macro_acc = macro_acc
            best_val_acc   = val_acc
            best_state     = {k: v.cpu().clone()
                              for k, v in model.state_dict().items()}

    print(f"\n  Best val accuracy: {best_val_acc:.4f}  (macro-avg: {best_macro_acc:.4f})")
    model.load_state_dict(best_state)
    return model, device


# ---------------------------------------------------------------------------
# 5. Evaluate
# ---------------------------------------------------------------------------
def evaluate(model, device):
    print("\n=== Step 3: Final Evaluation (best checkpoint) ===")
    val_ds     = DFUDataset(VAL_DIR, VAL_TRANSFORMS)
    val_loader = DataLoader(val_ds, batch_size=BATCH_SIZE,
                            shuffle=False, num_workers=0)
    model.eval()
    all_preds, all_labels = [], []
    with torch.no_grad():
        for imgs, lbls in val_loader:
            preds = model(imgs.to(device)).argmax(1).cpu().numpy()
            all_preds.extend(preds)
            all_labels.extend(lbls.numpy())

    all_preds  = np.array(all_preds)
    all_labels = np.array(all_labels)
    overall    = (all_preds == all_labels).mean()
    print(f"  Overall accuracy: {overall:.4f}")

    for g in range(NUM_CLASSES):
        mask = all_labels == g
        if mask.sum() == 0:
            print(f"    Grade {g}: no val samples")
            continue
        acc = (all_preds[mask] == all_labels[mask]).mean()
        print(f"    Grade {g}: {acc:.4f}  ({mask.sum()} samples)")

    return overall


# ---------------------------------------------------------------------------
# 6. Export to ONNX
# ---------------------------------------------------------------------------
def export_onnx(model, device):
    print("\n=== Step 4: Exporting to ONNX (opset 17) ===")
    model.eval()
    dummy = torch.randn(1, 3, IMG_SIZE, IMG_SIZE, device=device)
    os.makedirs(MODEL_DIR, exist_ok=True)

    onnx_path = os.path.join(MODEL_DIR, ONNX_NAME)
    pth_path  = os.path.join(MODEL_DIR, PTH_NAME)

    # Save PyTorch checkpoint
    torch.save({
        "model_state_dict": model.state_dict(),
        "num_classes": NUM_CLASSES,
        "img_size": IMG_SIZE,
        "class_labels": CLASS_LABELS,
    }, pth_path)
    print(f"  Saved .pth  ->  {pth_path}")

    # Remove stale ONNX files
    for old in [onnx_path, onnx_path + ".data"]:
        if os.path.exists(old):
            os.remove(old)
            print(f"  Removed old: {old}")

    # Export
    torch.onnx.export(
        model,
        dummy,
        onnx_path,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes={"input":  {0: "batch_size"},
                      "output": {0: "batch_size"}},
        opset_version=17,
        do_constant_folding=True,
    )
    size_mb = os.path.getsize(onnx_path) / (1024 * 1024)
    print(f"  Saved .onnx ->  {onnx_path}  ({size_mb:.1f} MB)")

    # Sanity-check with onnxruntime
    import onnxruntime as ort
    opts = ort.SessionOptions()
    opts.log_severity_level = 3
    sess = ort.InferenceSession(onnx_path,
                                providers=["CPUExecutionProvider"],
                                sess_options=opts)
    dummy_np = np.random.randn(1, 3, IMG_SIZE, IMG_SIZE).astype(np.float32)
    out = sess.run(None, {"input": dummy_np})[0]
    assert out.shape == (1, NUM_CLASSES), \
        f"Unexpected ONNX output shape: {out.shape}"
    print(f"  ONNX sanity-check passed — output shape: {out.shape}")

    # Remove stale quantized model if present
    quantized = os.path.join(MODEL_DIR,
                             "ulcer_classification_mobilenetv3_quantized.onnx")
    if os.path.exists(quantized):
        os.remove(quantized)
        print(f"  Removed stale quantized model: {quantized}")

    return onnx_path


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    print("=" * 62)
    print("  DFU MobileNetV3-Small  |  6-class Wagner Scale  |  ONNX")
    print("=" * 62)

    build_splits()
    model, device = train()
    evaluate(model, device)
    export_onnx(model, device)

    print("\n" + "=" * 62)
    print("  DONE — model exported to dfu_backend/models/")
    print("  Restart the backend server to load the new model.")
    print("=" * 62)
