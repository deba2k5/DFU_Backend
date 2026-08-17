"""Combines the local ONNX MobileNetV3 grade with Groq's VLM (Qwen) grade
into one final Wagner-scale diagnosis.

The local model was trained on only ~117 images and can be unreliable
out-of-distribution (see diagnostician.py / vlm_fallback.py), so both
models are always consulted and reconciled here instead of only calling
the VLM as a fallback when the local model's confidence is low.
"""

CLASS_LABELS = [
    "Grade 0 - Healthy",
    "Grade 1 - Surface Ulcer",
    "Grade 2 - Deep Ulcer",
    "Grade 3 - Osteomyelitis",
    "Grade 4 - Localized Gangrene",
    "Grade 5 - Extensive Gangrene",
]


def combine_predictions(local: dict, vlm: dict | None) -> dict:
    """
    local: diagnostician_agent.infer() output — always present.
    vlm: vlm_fallback_agent.classify() output, or None if the VLM call
         wasn't attempted or raised.

    Returns a diagnosis dict in the same shape both agents already use
    (stage/label/condition/confidence/wagner_scale), plus `ensemble`
    describing how the two opinions were reconciled and `local_model` /
    `vlm_model` recording both raw grades for transparency in the report.
    """
    if vlm is None:
        result = dict(local)
        result["ensemble"] = "local_only"
        return result

    if local.get("error"):
        result = dict(vlm)
        result["ensemble"] = "vlm_only"
        result["local_model_error"] = local.get("error")
        return result

    local_stage = int(local.get("stage", 0) or 0)
    vlm_stage = int(vlm.get("stage", 0) or 0)
    local_conf = float(local.get("confidence", 0) or 0)
    vlm_conf = float(vlm.get("confidence", 0) or 0)

    if local_stage == vlm_stage:
        final_stage = local_stage
        # Two independent models landing on the same grade is a stronger
        # signal than either alone.
        final_conf = max(local_conf, vlm_conf) + 0.08
        ensemble = "agree"
    elif vlm_conf >= local_conf - 0.05:
        # Disagreement — defer to whichever model is more confident, with a
        # slight bias toward the VLM since the local model's tiny training
        # set makes it unreliable out-of-distribution.
        final_stage = vlm_stage
        final_conf = vlm_conf
        ensemble = "disagree_vlm_preferred"
    else:
        final_stage = local_stage
        final_conf = local_conf
        ensemble = "disagree_local_preferred"

    final_conf = max(0.0, min(1.0, final_conf))
    label = CLASS_LABELS[final_stage]

    return {
        "stage": final_stage,
        "label": label,
        "condition": label,
        "confidence": f"{final_conf:.4f}",
        "wagner_scale": f"Grade {final_stage}",
        "ensemble": ensemble,
        "reasoning": vlm.get("reasoning", ""),
        "local_model": {"stage": local_stage, "confidence": f"{local_conf:.4f}"},
        "vlm_model": {"stage": vlm_stage, "confidence": f"{vlm_conf:.4f}"},
    }
