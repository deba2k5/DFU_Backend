# 🚀 Deploy DFU Backend to Vercel - Step by Step

## ✅ What's Ready

Your backend has been configured for Vercel deployment:
- ✅ `api/index.py` - FastAPI entry point
- ✅ `vercel.json` - Routing & build configuration  
- ✅ `.vercelignore` - Optimized for production
- ✅ Models included (`ulcer_classification_mobilenetv3.onnx`)
- ✅ All dependencies in `requirements-vercel.txt`

---

## 📋 Prerequisites

You need a **Vercel Account**. If you don't have one:
1. Go to https://vercel.com/signup
2. Sign up with GitHub (recommended) or email
3. Create a new team/project

---

## 🎯 Deployment Steps

### Step 1: Install Vercel CLI

Run this in PowerShell (in your project root directory):

```powershell
npm install -g vercel
```

If you don't have Node.js:
- Download from https://nodejs.org/ (LTS version)
- Install it
- Then run the command above

### Step 2: Authenticate with Vercel

```powershell
vercel login
```

This will open your browser to authenticate. Follow the prompts.

### Step 3: Deploy Backend to Vercel

Navigate to your project root and run:

```powershell
cd "c:\Users\Debangshu05\Downloads\projectv2.0 dfu"
vercel
```

**During setup, answer as follows:**
- `Set up and deploy?` → **yes**
- `Which scope?` → Select your account (default is fine)
- `Link to existing project?` → **no** (unless you already have one)
- `Project name?` → `dfu-screening-api` (or your choice)
- `Directory?` → Keep default (current directory)
- `Build command?` → Leave blank (press Enter)
- `Output directory?` → Leave blank (press Enter)

Vercel will build and deploy!

### Step 4: Add Environment Variable (GROQ_API_KEY)

After deployment succeeds, you'll get a URL like: `https://dfu-screening-api-xxx.vercel.app`

Now add your API key:

1. Go to https://vercel.com/dashboard
2. Click on your **dfu-screening-api** project
3. Click **Settings** → **Environment Variables**
4. Click **Add New** and fill in:
   - **Name:** `GROQ_API_KEY`
   - **Value:** *(Copy from your local `.env` file)*
   - **Environments:** Production + Preview
5. Click **Save**

### Step 5: Redeploy with Environment Variable

After adding the variable, redeploy:

```powershell
vercel --prod
```

---

## ✅ Testing Your Deployment

Once deployed, test these endpoints:

### Health Check
```powershell
curl https://your-dfu-api.vercel.app/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "DFU Screening API",
  "version": "2.0.0",
  "timestamp": "2026-05-28T..."
}
```

### View API Documentation
Open in browser:
```
https://your-dfu-api.vercel.app/docs
```

---

## 🔗 Update Frontend to Use Vercel Backend

In your Flutter frontend, update the API base URL:

**File:** `dfu_frontend/lib/core/` (or wherever you define API constants)

Change from:
```dart
const String API_BASE_URL = 'http://localhost:8000';
```

To:
```dart
const String API_BASE_URL = 'https://your-dfu-api.vercel.app';
```

---

## 📊 Monitoring & Logs

View deployment logs anytime:

```powershell
vercel logs https://your-dfu-api.vercel.app
```

Or visit: https://vercel.com/dashboard → Click project → **Deployments** tab

---

## ⚠️ Important Notes

### Model Size
- Your ONNX model (~50-100MB) is included
- Vercel supports up to 15MB per lambda function
- If model is too large, consider:
  1. **Option A:** Host model separately on AWS S3 + load at runtime
  2. **Option B:** Use model quantization to reduce size
  3. **Option C:** Use Vercel's `/public` folder for static files

### Cold Starts
- First request may take 10-15 seconds (initial startup)
- Subsequent requests are fast (~100ms)
- You can upgrade to **Pro plan** for better performance

### CORS
- Already configured: `allow_origins=["*"]`
- Frontend can call from any domain
- For production, restrict to your domain

---

## 🆘 Troubleshooting

### Deployment Fails
```powershell
vercel logs https://your-dfu-api.vercel.app
```
Check logs for import errors or missing dependencies.

### API Returns 500 Error
1. Check Vercel logs
2. Verify GROQ_API_KEY is set
3. Test locally: `python -m uvicorn main:app --reload`

### CORS Errors
- Already fixed in `main.py`
- If still issues, check browser console for exact error

---

## 📞 Your Deployment URL

After step 3, Vercel gives you a URL like:
```
https://dfu-screening-api-xxxxxxxxxxxx.vercel.app
```

**Share this with your frontend team!**

---

## ✨ Next Steps

1. ✅ Deploy backend (you are here)
2. 🔄 Update frontend API URL
3. 🧪 Test image upload & prediction
4. 📱 Deploy frontend to Vercel (similar process)

---

## 🎓 Additional Resources

- Vercel Docs: https://vercel.com/docs/concepts/functions/serverless-functions/python
- FastAPI on Vercel: https://vercel.com/docs/frameworks/fastapi
- Troubleshooting: https://vercel.com/support

Good luck! 🚀
