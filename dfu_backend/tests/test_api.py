import requests
import os

def test_predict():
    url = "http://127.0.0.1:8000/predict"
    img_path = r"c:\Users\Debangshu05\Downloads\projectv2.0 dfu\assets\banner.png"
    
    if not os.path.exists(img_path):
        print(f"Error: Image not found at {img_path}")
        return

    with open(img_path, 'rb') as f:
        files = {'file': f}
        response = requests.post(url, files=files)
    
    print(f"Status Code: {response.status_code}")
    print(f"Response Body: {response.json()}")

if __name__ == "__main__":
    test_predict()
