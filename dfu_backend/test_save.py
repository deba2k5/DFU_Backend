import requests
import json

url = "http://127.0.0.1:8000/reports"
payload = {
    "patient": {
        "name": "Test User",
        "fileNo": "",
        "date": "2026-06-11",
        "age": "30",
        "sex": "Male",
        "address": "123 Main St",
        "mobile": "1234567890",
        "referringDoctor": "Dr. Smith"
    },
    "medical_history": {},
    "diabetic_foot_history": {},
    "examination": {},
    "prediction": {
        "condition": "surface ulcer",
        "confidence": "0.95",
        "stage": 1
    },
    "clinical_report": "Needs care.",
    "ai_insights": "Patient should apply ointment.",
    "image_path": ""
}

res = requests.post(url, json=payload)
print(res.status_code)
print(res.text)
