#!/bin/bash
# MLOps Setup Script for DFU Backend
# This script sets up logging, metrics, and model quantization

set -e

echo "================================"
echo "DFU MLOps Setup"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Install dependencies
echo -e "${BLUE}Step 1: Installing Python dependencies...${NC}"
pip install -r requirements.txt
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Step 2: Create logs directory
echo -e "${BLUE}Step 2: Creating logs directory...${NC}"
mkdir -p logs
echo -e "${GREEN}✓ Logs directory created${NC}"
echo ""

# Step 3: Model quantization (optional)
echo -e "${BLUE}Step 3: Model Quantization${NC}"
echo "Do you want to quantize the model for faster inference? (y/n)"
read -r quantize_choice

if [ "$quantize_choice" = "y" ] || [ "$quantize_choice" = "Y" ]; then
    echo "Starting model quantization..."
    python quantize_model.py
    echo -e "${GREEN}✓ Model quantization complete${NC}"
else
    echo -e "${YELLOW}⊘ Skipping model quantization${NC}"
fi
echo ""

# Step 4: Monitoring stack setup
echo -e "${BLUE}Step 4: Monitoring Stack Setup${NC}"
echo "Do you want to set up Prometheus + Grafana? (requires Docker) (y/n)"
read -r monitoring_choice

if [ "$monitoring_choice" = "y" ] || [ "$monitoring_choice" = "Y" ]; then
    if command -v docker &> /dev/null; then
        echo "Starting monitoring stack..."
        docker-compose -f docker-compose.monitoring.yml up -d
        echo -e "${GREEN}✓ Monitoring stack started${NC}"
        echo "  - Prometheus: http://localhost:9090"
        echo "  - Grafana: http://localhost:3000 (admin/admin)"
    else
        echo -e "${YELLOW}⊘ Docker not found. Skipping monitoring stack${NC}"
    fi
else
    echo -e "${YELLOW}⊘ Skipping monitoring stack${NC}"
fi
echo ""

# Step 5: Summary
echo -e "${BLUE}Setup Complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Start the backend: python main.py"
echo "2. View API docs: http://localhost:8000/docs"
echo "3. Check metrics: http://localhost:8000/metrics"
echo "4. View logs: tail -f logs/app_*.log"
echo ""
echo "For detailed information, see MLOPS_GUIDE.md"
echo ""
