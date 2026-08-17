from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, Response
import os
import time
import json
import base64
from io import BytesIO
from dotenv import load_dotenv
from pydantic import BaseModel, Field
from pymongo import MongoClient, DESCENDING
from bson import ObjectId
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.lib.utils import ImageReader
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image as RLImage
import socketio

try:
    import chromadb
except Exception:
    chromadb = None

# Load environment variables from .env file
load_dotenv()

from utils.logger import get_logger, log_performance, log_error_with_context
from utils.metrics import track_request, track_inference, record_request, record_error, record_prediction, get_metrics

logger = get_logger("main")

from agents.preprocessor import preprocessor_agent
from agents.diagnostician import diagnostician_agent
from agents.reporter import reporting_agent
from agents.assistant import assistant_agent
from agents.vlm_fallback import vlm_fallback_agent
from agents.ensemble import combine_predictions

fastapi_app = FastAPI(
    title="DFU Screening Platform API",
    description="Agentic AI pathway for Diabetic Foot Ulcer detection — powered by Groq Llama-4.",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS — allow all origins so Flutter web/mobile can connect
fastapi_app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@fastapi_app.middleware("http")
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

@fastapi_app.on_event("startup")
async def startup_event():
    logger.info("FastAPI application starting up...")

@fastapi_app.on_event("shutdown")
async def shutdown_event():
    logger.info("FastAPI application shutting down...")

DEFAULT_MONGODB_URI = "mongodb+srv://aizenera2025:aizenera@traehackathon.wu9n7jq.mongodb.net/?appName=TraeHackathon"
MONGODB_URI = os.getenv("MONGODB_URI", DEFAULT_MONGODB_URI)
MONGODB_DB = os.getenv("MONGODB_DB", "dfu_screening")
PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "http://localhost:8000")
CHROMA_PATH = os.getenv("CHROMA_PATH", "./chroma_dfu_reports")

mongo_client = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=5000)
db = mongo_client[MONGODB_DB]
reports_collection = db["patient_reports"]
reports_collection.create_index([("created_at", DESCENDING)])
reports_collection.create_index("file_no", unique=True)

chroma_collection = None
if chromadb is not None:
    try:
        chroma_client = chromadb.PersistentClient(path=CHROMA_PATH)
        chroma_collection = chroma_client.get_or_create_collection("dfu_patient_reports")
    except Exception as exc:
        print(f"ChromaDB unavailable: {exc}")

sio = socketio.AsyncServer(async_mode="asgi", cors_allowed_origins="*")


class ReportCreate(BaseModel):
    patient: dict = Field(default_factory=dict)
    medical_history: dict = Field(default_factory=dict)
    diabetic_foot_history: dict = Field(default_factory=dict)
    examination: dict = Field(default_factory=dict)
    prediction: dict = Field(default_factory=dict)
    clinical_report: str = ""
    ai_insights: str = ""
    image_path: str = ""
    image_base64: str = ""
    image_content_type: str = "image/jpeg"


def _file_no() -> str:
    return f"ILS-{time.strftime('%Y%m%d')}-{str(ObjectId())[-6:].upper()}"


def _stage_from_prediction(prediction: dict) -> int:
    condition = str(prediction.get("condition", "")).lower()
    if "extensive gangrene" in condition:
        return 5
    if "localized gangrene" in condition:
        return 4
    if "osteomyelitis" in condition or "grade 3" in condition:
        return 3
    if "deep ulcer" in condition or "grade 2" in condition:
        return 2
    if "surface ulcer" in condition or "superficial ulcer" in condition or "grade 1" in condition:
        return 1
    if "healthy" in condition or "grade 0" in condition:
        return 0
    return int(prediction.get("stage", 0) or 0)


def _report_text(doc: dict) -> str:
    patient = doc.get("patient", {})
    prediction = doc.get("prediction", {})
    parts = [
        f"File No: {doc.get('file_no')}",
        f"Date: {patient.get('date', '')}",
        f"Patient: {patient.get('name', '')}, age {patient.get('age', '')}, sex {patient.get('sex', '')}",
        f"Address: {patient.get('address', '')}",
        f"Mobile: {patient.get('mobile', '')}",
        f"Referring Doctor: {patient.get('referringDoctor', '')}",
        f"Wagner Stage: {doc.get('stage', 0)}",
        f"Condition: {prediction.get('condition', '')}",
        f"Confidence: {prediction.get('confidence', '')}",
        f"Clinical Report: {doc.get('clinical_report', '')}",
        f"AI Insights: {doc.get('ai_insights', '')}",
        json.dumps(doc.get("medical_history", {}), ensure_ascii=True),
        json.dumps(doc.get("diabetic_foot_history", {}), ensure_ascii=True),
        json.dumps(doc.get("examination", {}), ensure_ascii=True),
    ]
    return "\n".join(parts)


def _kv_table(title: str, rows: list[list[str]]) -> list:
    story = []
    styles = getSampleStyleSheet()
    story.append(Paragraph(f"<b>{title}</b>", styles["Heading3"]))
    if not rows:
        return story
    table = Table(rows, colWidths=[6.2 * cm, 10.2 * cm], hAlign="LEFT")
    table.setStyle(TableStyle([
        ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
        ("BACKGROUND", (0, 0), (0, -1), colors.whitesmoke),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 8),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
    ]))
    story.extend([table, Spacer(1, 0.35 * cm)])
    return story


def _embed_photo(image_b64: str):
    """Return reportlab flowables that embed the foot photograph, or [] if absent/unreadable."""
    if not image_b64:
        return []
    try:
        img_bytes = base64.b64decode(image_b64)
        reader = ImageReader(BytesIO(img_bytes))
        iw, ih = reader.getSize()
        max_w, max_h = 8.5 * cm, 10 * cm
        scale = min(max_w / iw, max_h / ih)
        w, h = iw * scale, ih * scale
        return [
            Paragraph("<b>Foot Photograph</b>", getSampleStyleSheet()["Heading3"]),
            RLImage(BytesIO(img_bytes), width=w, height=h),
            Spacer(1, 0.35 * cm),
        ]
    except Exception as e:
        print(f"Photo embed failed (non-fatal): {e}")
        return []


def _generate_pdf(doc: dict) -> bytes:
    buffer = BytesIO()
    pdf = SimpleDocTemplate(buffer, pagesize=A4, rightMargin=1.2 * cm, leftMargin=1.2 * cm, topMargin=1 * cm, bottomMargin=1 * cm)
    styles = getSampleStyleSheet()
    story = [
        Paragraph("<b>ILS HOSPITAL</b>", styles["Title"]),
        Paragraph("DD-6 Sector-1 Saltlake City Kolkata-700 064", styles["Normal"]),
        Spacer(1, 0.4 * cm),
    ]

    patient = doc.get("patient", {})
    story.extend(_kv_table("Patient Information", [
        ["Date", patient.get("date", "")],
        ["File No.", doc.get("file_no", "")],
        ["Name", patient.get("name", "")],
        ["Age", str(patient.get("age", ""))],
        ["Sex", patient.get("sex", "")],
        ["Address", patient.get("address", "")],
        ["Mobile No.", patient.get("mobile", "")],
        ["Referring Dr.", patient.get("referringDoctor", "")],
    ]))

    mh = doc.get("medical_history", {})
    story.extend(_kv_table("Medical History", [[k, str(v)] for k, v in mh.items()]))

    dfh = doc.get("diabetic_foot_history", {})
    story.extend(_kv_table("Diabetic Foot History", [[k, str(v)] for k, v in dfh.items()]))

    story.append(PageBreak())
    exam = doc.get("examination", {})
    story.extend(_kv_table("Examination Of Foot", [[k, str(v)] for k, v in exam.items()]))
    story.extend(_embed_photo(doc.get("image_base64", "")))

    prediction = doc.get("prediction", {})
    story.extend(_kv_table("Foot Scan Report", [
        ["Wagner Classification", f"Grade-{doc.get('stage', 0)}"],
        ["Detected Condition", prediction.get("condition", "")],
        ["Confidence", str(prediction.get("confidence", ""))],
        ["Model", doc.get("model", "MobileNetV3-Small ONNX")],
        ["How it is working", "The app preprocesses the uploaded foot image, runs the trained ONNX MobileNetV3 classifier, maps the output to Wagner diabetic-foot-ulcer staging, then generates a clinical summary and AI insights."],
        ["Clinical Report", doc.get("clinical_report", "")],
        ["AI Insights", doc.get("ai_insights", "")],
    ]))
    pdf.build(story)
    return buffer.getvalue()


async def _emit_report(doc: dict):
    payload = {
        "id": str(doc["_id"]),
        "file_no": doc["file_no"],
        "patient": doc.get("patient", {}),
        "stage": doc.get("stage", 0),
        "condition": doc.get("prediction", {}).get("condition", ""),
        "confidence": doc.get("prediction", {}).get("confidence", 0),
        "clinical_report": doc.get("clinical_report", ""),
        "ai_insights": doc.get("ai_insights", ""),
        "pdf_url": f"{PUBLIC_BASE_URL}/reports/{str(doc['_id'])}/pdf",
        "pdf_base64": doc.get("pdf_base64", ""),
        "created_at": doc.get("created_at", ""),
    }
    await sio.emit("doctor_pdf_report", payload, room="doctors")


@sio.event
async def connect(sid, environ):
    await sio.emit("connected", {"status": "ok"}, to=sid)


@sio.event
async def join_doctor_portal(sid, data=None):
    await sio.enter_room(sid, "doctors")
    await sio.emit("doctor_portal_ready", {"status": "listening"}, to=sid)


@fastapi_app.get("/metrics")
async def metrics():
    return Response(get_metrics(), media_type="text/plain")

@fastapi_app.get("/")
async def root():
    return {
        "status": "online",
        "service": "DFU Screening API",
        "version": "2.0.0",
        "agents": ["Preprocessor", "Diagnostician", "Reporter", "Assistant"],
        "docs": "/docs",
    }


@fastapi_app.get("/health")
async def health():
    return {"status": "healthy", "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}


@fastapi_app.post("/predict")
async def predict_ulcer(file: UploadFile = File(...), patient_data: str = Form("{}")):
    """
    Full Agentic AI Pipeline:
    1. Preprocessor — normalizes the clinical image (Pillow-based)
    2. Diagnostician — classifies DFU severity (Wagner Scale)
    3. Reporter — generates structured clinical guidelines
    4. Assistant — Groq Llama-4 AI insights summary
    """
    try:
        contents = await file.read()
        start_time = time.time()

        # Stage 1: Preprocess
        with track_inference("preprocess"):
            t_start = time.time()
            processed_img = preprocessor_agent.process(contents)
            preprocess_ms = (time.time() - t_start) * 1000
            log_performance("preprocess", preprocess_ms)

        # Stage 2: Diagnose
        with track_inference("diagnosis"):
            t_start = time.time()
            diagnosis = diagnostician_agent.infer(processed_img)
            diagnosis_ms = (time.time() - t_start) * 1000
            log_performance("diagnosis", diagnosis_ms)

        # Stage 2b: Groq VLM (Qwen) — always consulted alongside the local
        # ONNX model and reconciled into one final grade (see
        # agents/ensemble.py). The local model was trained on only ~117
        # images, so a second, independent opinion on every request catches
        # out-of-distribution misclassifications instead of only kicking in
        # when the local model already reports low confidence.
        vlm_fallback_ms = 0
        used_vlm_fallback = False
        vlm_result = None
        try:
            with track_inference("vlm_fallback"):
                t_start = time.time()
                vlm_result = vlm_fallback_agent.classify(contents)
                vlm_fallback_ms = (time.time() - t_start) * 1000
            log_performance("vlm_fallback", vlm_fallback_ms)
        except Exception as fallback_err:
            log_error_with_context(fallback_err, {"endpoint": "/predict", "stage": "vlm_fallback"})
            # Keep the local model's result — better than failing the request.

        diagnosis = combine_predictions(diagnosis, vlm_result)
        used_vlm_fallback = vlm_result is not None

        # Stage 3: Clinical report
        with track_inference("reporting"):
            t_start = time.time()
            base_report = reporting_agent.generate_summary(diagnosis)
            reporting_ms = (time.time() - t_start) * 1000
            log_performance("reporting", reporting_ms)

        # Stage 4: Groq AI summary
        with track_inference("ai_summary"):
            t_start = time.time()
            ai_clinical_summary = assistant_agent.get_summary(str(diagnosis))
            ai_summary_ms = (time.time() - t_start) * 1000
            log_performance("ai_summary", ai_summary_ms)

        latency = time.time() - start_time

        # Record prediction metrics
        record_prediction(
            grade=f"Grade {diagnosis.get('stage', 0)}",
            confidence=float(diagnosis.get('confidence', 0.0))
        )

        return {
            "success": True,
            "prediction": diagnosis,
            "clinical_report": base_report,
            "ai_insights": ai_clinical_summary,
            "patient_data": json.loads(patient_data or "{}"),
            "metadata": {
                "latency_ms": int(latency * 1000),
                "stages": {
                    "preprocess_ms": int(preprocess_ms),
                    "diagnosis_ms": int(diagnosis_ms),
                    "vlm_fallback_ms": int(vlm_fallback_ms),
                    "reporting_ms": int(reporting_ms),
                    "ai_summary_ms": int(ai_summary_ms)
                },
                "model": "MobileNetV3 + Groq VLM (ensemble)" if used_vlm_fallback else "MobileNetV3-Small (Trained)",
                "used_vlm_fallback": used_vlm_fallback,
                "ensemble": diagnosis.get("ensemble", "local_only"),
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            },
        }

    except Exception as e:
        log_error_with_context(e, {"endpoint": "/predict"})
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")


@fastapi_app.post("/reports")
async def create_report(payload: ReportCreate):
    patient_name = str(payload.patient.get("name", "")).strip()
    if not patient_name:
        raise HTTPException(status_code=400, detail="Patient name is required")
    if len(payload.image_base64) > 8_000_000:  # ~6MB raw — guard against oversized Mongo docs
        raise HTTPException(status_code=400, detail="Image too large (max ~6MB)")
    try:
        doc = payload.model_dump()
        doc["patient"]["name"] = patient_name
        doc["file_no"] = doc.get("patient", {}).get("fileNo") or _file_no()
        doc["created_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        doc["stage"] = _stage_from_prediction(doc.get("prediction", {}))
        doc["model"] = "MobileNetV3-Small ONNX"
        doc["has_image"] = bool(doc.get("image_base64"))
        pdf_bytes = _generate_pdf(doc)
        doc["pdf_base64"] = base64.b64encode(pdf_bytes).decode("ascii")

        try:
            result = reports_collection.insert_one(doc)
            doc["_id"] = result.inserted_id
        except Exception as db_err:
            if "duplicate" in str(db_err).lower() or "E11000" in str(db_err):
                existing = reports_collection.find_one({"file_no": doc["file_no"]})
                if existing:
                    doc["_id"] = existing["_id"]
                else:
                    doc.pop("_id", None)
                    doc["file_no"] = _file_no()
                    result = reports_collection.insert_one(doc)
                    doc["_id"] = result.inserted_id
            else:
                raise db_err

        if chroma_collection is not None:
            chroma_collection.upsert(
                ids=[str(result.inserted_id)],
                documents=[_report_text(doc)],
                metadatas=[{
                    "file_no": doc["file_no"],
                    "patient_name": doc.get("patient", {}).get("name", ""),
                    "mobile": doc.get("patient", {}).get("mobile", ""),
                    "stage": doc.get("stage", 0),
                    "created_at": doc["created_at"],
                }],
            )

        await _emit_report(doc)
        return {
            "success": True,
            "id": str(result.inserted_id),
            "file_no": doc["file_no"],
            "stage": doc["stage"],
            "pdf_url": f"{PUBLIC_BASE_URL}/reports/{str(result.inserted_id)}/pdf",
            "image_url": f"{PUBLIC_BASE_URL}/reports/{str(result.inserted_id)}/image" if doc["has_image"] else "",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Report save error: {str(e)}")


def _serialize_report(doc: dict) -> dict:
    rid = str(doc["_id"])
    return {
        "id": rid,
        "file_no": doc.get("file_no", ""),
        "patient": doc.get("patient", {}),
        "stage": doc.get("stage", 0),
        "condition": doc.get("prediction", {}).get("condition", ""),
        "confidence": doc.get("prediction", {}).get("confidence", 0),
        "clinical_report": doc.get("clinical_report", ""),
        "ai_insights": doc.get("ai_insights", ""),
        "image_path": doc.get("image_path", ""),
        "pdf_url": f"{PUBLIC_BASE_URL}/reports/{rid}/pdf",
        "image_url": f"{PUBLIC_BASE_URL}/reports/{rid}/image" if doc.get("has_image") else "",
        "created_at": doc.get("created_at", ""),
    }


@fastapi_app.get("/reports")
async def list_reports(limit: int = 50):
    docs = []
    for doc in reports_collection.find({}, {"pdf_base64": 0, "image_base64": 0}).sort("created_at", DESCENDING).limit(limit):
        docs.append(_serialize_report(doc))
    return {"success": True, "reports": docs}


@fastapi_app.get("/reports/search")
async def search_reports(name: str, limit: int = 100):
    name = name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name is required")
    import re
    pattern = re.compile(re.escape(name), re.IGNORECASE)
    docs = []
    for doc in reports_collection.find({"patient.name": pattern}, {"pdf_base64": 0, "image_base64": 0}).sort("created_at", DESCENDING).limit(limit):
        docs.append(_serialize_report(doc))
    return {"success": True, "reports": docs}


@fastapi_app.get("/reports/{report_id}/pdf")
async def get_report_pdf(report_id: str):
    doc = reports_collection.find_one({"_id": ObjectId(report_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Report not found")
    pdf_bytes = base64.b64decode(doc.get("pdf_base64", ""))
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f"inline; filename={doc.get('file_no', report_id)}.pdf"},
    )


@fastapi_app.get("/reports/{report_id}/image")
async def get_report_image(report_id: str):
    doc = reports_collection.find_one({"_id": ObjectId(report_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Report not found")
    raw = doc.get("image_base64", "")
    if not raw:
        raise HTTPException(status_code=404, detail="No photo stored for this report")
    img_bytes = base64.b64decode(raw)
    content_type = doc.get("image_content_type") or "image/jpeg"
    ext = "png" if "png" in content_type else "jpg"
    return Response(
        content=img_bytes,
        media_type=content_type,
        headers={"Content-Disposition": f"inline; filename={doc.get('file_no', report_id)}.{ext}"},
    )


@fastapi_app.post("/chat")
async def chat_with_assistant(message: str = Form(...)):
    """
    Streams real-time Groq Llama-4 tokens to the frontend.
    Uses chunked transfer encoding (SSE-compatible).
    """
    try:
        def stream_generator():
            for chunk in assistant_agent.chat_stream(message):
                yield chunk

        return StreamingResponse(stream_generator(), media_type="text/plain")

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


app = socketio.ASGIApp(sio, other_asgi_app=fastapi_app, socketio_path="socket.io")
