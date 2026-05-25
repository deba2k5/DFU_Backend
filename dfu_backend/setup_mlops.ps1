# MLOps Setup Script for DFU Backend (PowerShell)
# This script sets up logging, metrics, and model quantization

Write-Host "================================" -ForegroundColor Cyan
Write-Host "DFU MLOps Setup (Windows)" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Install dependencies
Write-Host "Step 1: Installing Python dependencies..." -ForegroundColor Blue
pip install -r requirements.txt
Write-Host "✓ Dependencies installed" -ForegroundColor Green
Write-Host ""

# Step 2: Create logs directory
Write-Host "Step 2: Creating logs directory..." -ForegroundColor Blue
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" | Out-Null
}
Write-Host "✓ Logs directory created" -ForegroundColor Green
Write-Host ""

# Step 3: Model quantization (optional)
Write-Host "Step 3: Model Quantization" -ForegroundColor Blue
$quantize_choice = Read-Host "Do you want to quantize the model for faster inference? (y/n)"

if ($quantize_choice -eq "y" -or $quantize_choice -eq "Y") {
    Write-Host "Starting model quantization..." -ForegroundColor White
    python quantize_model.py
    Write-Host "✓ Model quantization complete" -ForegroundColor Green
} else {
    Write-Host "⊘ Skipping model quantization" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Monitoring stack setup
Write-Host "Step 4: Monitoring Stack Setup" -ForegroundColor Blue
$monitoring_choice = Read-Host "Do you want to set up Prometheus + Grafana? (requires Docker) (y/n)"

if ($monitoring_choice -eq "y" -or $monitoring_choice -eq "Y") {
    $docker_installed = $null
    try {
        $docker_installed = docker --version 2>$null
    } catch {
        $docker_installed = $null
    }
    
    if ($docker_installed) {
        Write-Host "Starting monitoring stack..." -ForegroundColor White
        docker-compose -f docker-compose.monitoring.yml up -d
        Write-Host "✓ Monitoring stack started" -ForegroundColor Green
        Write-Host "  - Prometheus: http://localhost:9090" -ForegroundColor Cyan
        Write-Host "  - Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor Cyan
    } else {
        Write-Host "⊘ Docker not found. Skipping monitoring stack" -ForegroundColor Yellow
    }
} else {
    Write-Host "⊘ Skipping monitoring stack" -ForegroundColor Yellow
}
Write-Host ""

# Step 5: Summary
Write-Host "Setup Complete!" -ForegroundColor Blue
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Start the backend: python main.py" -ForegroundColor White
Write-Host "2. View API docs: http://localhost:8000/docs" -ForegroundColor White
Write-Host "3. Check metrics: http://localhost:8000/metrics" -ForegroundColor White
Write-Host "4. View logs: Get-Content logs\app_*.log -Tail 20 -Wait" -ForegroundColor White
Write-Host ""
Write-Host "For detailed information, see MLOPS_GUIDE.md" -ForegroundColor Yellow
Write-Host ""
