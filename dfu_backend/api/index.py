"""
Vercel serverless entry point — all routes embedded directly.
Avoids importing main.py (which needs chromadb/socketio that crash on Vercel).
"""
import sys
import os
import time
import json
import base64
import traceback
from io import BytesIO

# Add parent directory so agents/ can be found
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response, JSONResponse
from pydantic import BaseModel, Field
from dotenv import load_dotenv

# ── Utils (optional — no-op fallbacks if packages missing) ───────────
try:
    from utils.logger import get_logger, log_performance, log_error_with_context
    logger = get_logger("vercel_api")
except Exception as _le:
    import logging as _logging
    _logging.basicConfig(level=_logging.INFO)
    _base_logger = _logging.getLogger("vercel_api")
    def get_logger(name="vercel_api"): return _base_logger
    def log_performance(stage, ms, extra=None): _base_logger.info(f"{stage}: {ms:.0f}ms")
    def log_error_with_context(e, ctx=None): _base_logger.error(f"{e} ctx={ctx}")
    logger = _base_logger
    print(f"Logger unavailable (using stdlib): {_le}")

try:
    from utils.metrics import track_request, track_inference, record_request, record_error, record_prediction, get_metrics
    METRICS_OK = True
except Exception as _me:
    from contextlib import contextmanager
    @contextmanager
    def track_request(endpoint): yield
    @contextmanager
    def track_inference(stage): yield
    def record_request(method, endpoint, status): pass
    def record_error(error_type, endpoint): pass
    def record_prediction(grade, confidence): pass
    def get_metrics(): return b""
    METRICS_OK = False
    print(f"Metrics unavailable: {_me}")


load_dotenv()

# ── MongoDB ──────────────────────────────────────────────────────────
try:
    from pymongo import MongoClient, DESCENDING
    from bson import ObjectId

    MONGODB_URI = os.getenv(
        "MONGODB_URI",
        "mongodb+srv://aizenera2025:aizenera@traehackathon.wu9n7jq.mongodb.net/?appName=TraeHackathon",
    )
    MONGODB_DB = os.getenv("MONGODB_DB", "dfu_screening")
    _mongo = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=8000)
    _db = _mongo[MONGODB_DB]
    reports_col = _db["patient_reports"]
    reports_col.create_index([("created_at", DESCENDING)])
    try:
        reports_col.create_index("file_no", unique=True)
    except Exception:
        pass
    MONGO_OK = True
except Exception as _me:
    MONGO_OK = False
    print(f"MongoDB unavailable: {_me}")

# ── PDF (reportlab) ───────────────────────────────────────────────────
try:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.lib.units import cm
    from reportlab.platypus import (
        SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak,
    )
    PDF_OK = True
except Exception:
    PDF_OK = False

# ── Agents ────────────────────────────────────────────────────────────
# reporter and assistant are lightweight (no onnxruntime/opencv) — safe to
# import eagerly. preprocessor (cv2) and diagnostician (onnxruntime) are
# heavy and must stay unimported on Vercel; they are loaded lazily inside
# the /predict handler which already returns 503 on Vercel anyway.
try:
    from agents.reporter import reporting_agent
    from agents.assistant import assistant_agent
    AGENTS_OK = True
except Exception as _ae:
    reporting_agent = None  # type: ignore
    assistant_agent = None  # type: ignore
    AGENTS_OK = False
    print(f"Agents unavailable: {_ae}")

# These are only used inside /predict — imported lazily at call time
preprocessor_agent = None  # type: ignore
diagnostician_agent = None  # type: ignore

PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "https://dfu-app-z513.vercel.app")

# ── App ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="DFU Screening Platform API",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def prometheus_middleware(request, call_next):
    endpoint = request.url.path
    method = request.method
    if endpoint == "/metrics":
        return await call_next(request)
    
    with track_request(endpoint):
        try:
            response = await call_next(request)
            record_request(method, endpoint, response.status_code)
            return response
        except Exception as e:
            record_error(type(e).__name__, endpoint)
            record_request(method, endpoint, 500)
            log_error_with_context(e, {"endpoint": endpoint, "method": method})
            raise e


# ── Helpers ───────────────────────────────────────────────────────────
def _file_no() -> str:
    return f"ILS-{time.strftime('%Y%m%d')}-{str(ObjectId())[-6:].upper()}" if MONGO_OK else f"ILS-{int(time.time())}"


def _stage_from_prediction(prediction: dict) -> int:
    condition = str(prediction.get("condition", "")).lower()
    if "extensive gangrene" in condition: return 5
    if "localized gangrene" in condition: return 4
    if "osteomyelitis" in condition or "grade 3" in condition: return 3
    if "deep ulcer" in condition or "grade 2" in condition: return 2
    if "surface ulcer" in condition or "superficial ulcer" in condition or "grade 1" in condition: return 1
    if "healthy" in condition or "grade 0" in condition: return 0
    return int(prediction.get("stage", 0) or 0)


def _kv_table(title, rows):
    styles = getSampleStyleSheet()
    story = [Paragraph(f"<b>{title}</b>", styles["Heading3"])]
    if not rows:
        return story
    table = Table(rows, colWidths=[6.2 * cm, 10.2 * cm], hAlign="LEFT")
    table.setStyle(TableStyle([
        ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
        ("BACKGROUND", (0, 0), (0, -1), colors.whitesmoke),
        ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 8),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ]))
    story += [table, Spacer(1, 0.35 * cm)]
    return story


def _generate_pdf(doc: dict) -> bytes:
    if not PDF_OK:
        return b""
    buffer = BytesIO()
    pdf = SimpleDocTemplate(
        buffer, pagesize=A4,
        rightMargin=1.2 * cm, leftMargin=1.2 * cm,
        topMargin=1 * cm, bottomMargin=1 * cm,
    )
    styles = getSampleStyleSheet()
    patient = doc.get("patient", {})
    prediction = doc.get("prediction", {})
    story = [
        Paragraph("<b>ILS HOSPITAL</b>", styles["Title"]),
        Paragraph("DD-6 Sector-1 Saltlake City Kolkata-700 064", styles["Normal"]),
        Spacer(1, 0.4 * cm),
    ]
    story += _kv_table("Patient Information", [
        ["Date", patient.get("date", "")],
        ["File No.", doc.get("file_no", "")],
        ["Name", patient.get("name", "")],
        ["Age", str(patient.get("age", ""))],
        ["Sex", patient.get("sex", "")],
        ["Address", patient.get("address", "")],
        ["Mobile No.", patient.get("mobile", "")],
        ["Referring Dr.", patient.get("referringDoctor", "")],
    ])
    mh = doc.get("medical_history", {})
    if mh:
        story += _kv_table("Medical History", [[k, str(v)] for k, v in mh.items()])
    dfh = doc.get("diabetic_foot_history", {})
    if dfh:
        story += _kv_table("Diabetic Foot History", [[k, str(v)] for k, v in dfh.items()])
    story.append(PageBreak())
    exam = doc.get("examination", {})
    if exam:
        story += _kv_table("Examination Of Foot", [[k, str(v)] for k, v in exam.items()])
    story += _kv_table("Foot Scan Report", [
        ["Wagner Classification", f"Grade-{doc.get('stage', 0)}"],
        ["Detected Condition", prediction.get("condition", "")],
        ["Confidence", str(prediction.get("confidence", ""))],
        ["Clinical Report", doc.get("clinical_report", "")],
        ["AI Insights", doc.get("ai_insights", "")],
    ])
    pdf.build(story)
    return buffer.getvalue()


# ── Models ─────────────────────────────────────────────────────────────
class ReportCreate(BaseModel):
    patient: dict = Field(default_factory=dict)
    medical_history: dict = Field(default_factory=dict)
    diabetic_foot_history: dict = Field(default_factory=dict)
    examination: dict = Field(default_factory=dict)
    prediction: dict = Field(default_factory=dict)
    clinical_report: str = ""
    ai_insights: str = ""
    image_path: str = ""


# ── Routes ─────────────────────────────────────────────────────────────
@app.get("/metrics")
async def metrics():
    return Response(get_metrics(), media_type="text/plain")

@app.get("/")
async def root():
    return {
        "status": "online",
        "service": "DFU Screening API",
        "version": "2.0.0",
        "agents": ["Preprocessor", "Diagnostician", "Reporter", "Assistant"],
        "mongo": MONGO_OK,
        "pdf": PDF_OK,
        "agents_ok": AGENTS_OK,
        "docs": "/docs",
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "mongo": MONGO_OK,
    }


@app.post("/predict")
async def predict_ulcer(
    file: UploadFile = File(...),
    patient_data: str = Form("{}"),
):
    if not AGENTS_OK:
        raise HTTPException(
            status_code=503,
            detail="AI inference not available on this deployment. "
                   "Send image to the Render backend /predict endpoint instead."
        )
    # Lazy-load heavy agents only when actually called (Render deployment)
    try:
        from agents.preprocessor import preprocessor_agent as _pre
        from agents.diagnostician import diagnostician_agent as _diag
    except ImportError as e:
        raise HTTPException(status_code=503, detail=f"Inference dependencies missing: {e}")

    try:
        contents = await file.read()
        t0 = time.time()

        with track_inference("preprocess"):
            t_start = time.time()
            processed_img = _pre.process(contents)
            preprocess_ms = (time.time() - t_start) * 1000
            log_performance("preprocess", preprocess_ms)

        with track_inference("diagnosis"):
            t_start = time.time()
            diagnosis = _diag.infer(processed_img)
            diagnosis_ms = (time.time() - t_start) * 1000
            log_performance("diagnosis", diagnosis_ms)

        with track_inference("reporting"):
            t_start = time.time()
            base_report = reporting_agent.generate_summary(diagnosis)
            reporting_ms = (time.time() - t_start) * 1000
            log_performance("reporting", reporting_ms)

        with track_inference("ai_summary"):
            t_start = time.time()
            ai_summary = assistant_agent.get_summary(str(diagnosis))
            ai_summary_ms = (time.time() - t_start) * 1000
            log_performance("ai_summary", ai_summary_ms)

        latency = time.time() - t0
        record_prediction(
            grade=f"Grade {diagnosis.get('stage', 0)}",
            confidence=float(diagnosis.get("confidence", 0.0)),
        )

        return {
            "success": True,
            "prediction": diagnosis,
            "clinical_report": base_report,
            "ai_insights": ai_summary,
            "patient_data": json.loads(patient_data or "{}"),
            "metadata": {
                "latency_ms": int(latency * 1000),
                "stages": {
                    "preprocess_ms": int(preprocess_ms),
                    "diagnosis_ms": int(diagnosis_ms),
                    "reporting_ms": int(reporting_ms),
                    "ai_summary_ms": int(ai_summary_ms),
                },
                "model": "MobileNetV3-Small (Trained)",
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            },
        }
    except Exception as e:
        log_error_with_context(e, {"endpoint": "/predict"})
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")


@app.post("/reports")
async def create_report(payload: ReportCreate):
    if not MONGO_OK:
        raise HTTPException(status_code=503, detail="Database not available")
    try:
        doc = payload.model_dump()
        doc["file_no"] = doc.get("patient", {}).get("fileNo") or _file_no()
        doc["created_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        doc["stage"] = _stage_from_prediction(doc.get("prediction", {}))
        doc["model"] = "MobileNetV3-Small ONNX"

        # Try to generate PDF; non-fatal if it fails
        try:
            pdf_bytes = _generate_pdf(doc)
            doc["pdf_base64"] = base64.b64encode(pdf_bytes).decode("ascii") if pdf_bytes else ""
        except Exception as pdf_err:
            print(f"PDF generation failed (non-fatal): {pdf_err}")
            doc["pdf_base64"] = ""

        # Handle duplicate file_no gracefully
        try:
            result = reports_col.insert_one(doc)
        except Exception as db_err:
            if "duplicate" in str(db_err).lower() or "E11000" in str(db_err):
                doc["file_no"] = _file_no()
                result = reports_col.insert_one(doc)
            else:
                raise db_err

        doc["_id"] = result.inserted_id
        return {
            "success": True,
            "id": str(result.inserted_id),
            "file_no": doc["file_no"],
            "stage": doc["stage"],
            "pdf_url": f"{PUBLIC_BASE_URL}/reports/{str(result.inserted_id)}/pdf",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Report save error: {str(e)}\n{traceback.format_exc()}")


@app.get("/reports")
async def list_reports(limit: int = 50):
    if not MONGO_OK:
        return {"success": True, "reports": []}
    try:
        docs = []
        for doc in reports_col.find({}, {"pdf_base64": 0}).sort("created_at", DESCENDING).limit(limit):
            docs.append({
                "id": str(doc["_id"]),
                "file_no": doc.get("file_no", ""),
                "patient": doc.get("patient", {}),
                "stage": doc.get("stage", 0),
                "condition": doc.get("prediction", {}).get("condition", ""),
                "confidence": doc.get("prediction", {}).get("confidence", 0),
                "clinical_report": doc.get("clinical_report", ""),
                "ai_insights": doc.get("ai_insights", ""),
                "image_path": doc.get("image_path", ""),
                "pdf_url": f"{PUBLIC_BASE_URL}/reports/{str(doc['_id'])}/pdf",
                "created_at": doc.get("created_at", ""),
            })
        return {"success": True, "reports": docs}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/reports/{report_id}/pdf")
async def get_report_pdf(report_id: str):
    if not MONGO_OK:
        raise HTTPException(status_code=503, detail="Database not available")
    try:
        doc = reports_col.find_one({"_id": ObjectId(report_id)})
        if not doc:
            raise HTTPException(status_code=404, detail="Report not found")
        raw = doc.get("pdf_base64", "")
        if not raw:
            raise HTTPException(status_code=404, detail="PDF not yet generated for this report")
        pdf_bytes = base64.b64decode(raw)
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={"Content-Disposition": f"inline; filename={doc.get('file_no', report_id)}.pdf"},
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/chat")
async def chat_with_assistant(message: str = Form(...)):
    if not AGENTS_OK:
        raise HTTPException(status_code=503, detail="AI agent not available")
    try:
        from fastapi.responses import StreamingResponse
        def stream_generator():
            for chunk in assistant_agent.chat_stream(message):
                yield chunk
        return StreamingResponse(stream_generator(), media_type="text/plain")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
