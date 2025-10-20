#!/bin/bash

# Setup script for first-time users
# This script helps set up the Unsloth Docker environment

set -e

echo "🦥 Unsloth Docker Framework Setup"
echo "=================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found. Please run this script from the project root.${NC}"
    exit 1
fi

echo "Setting up your Unsloth environment..."
echo ""

# 1. Check dependencies
echo -e "${BLUE}1. Checking dependencies...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
else
    echo -e "${GREEN}✅ Docker found${NC}"
fi

# Check for Docker Compose (both new and legacy formats)
if docker compose version &> /dev/null; then
    echo -e "${GREEN}✅ Docker Compose found (docker compose)${NC}"
    export DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✅ Docker Compose found (docker-compose)${NC}"
    export DOCKER_COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}❌ Docker Compose is not available${NC}"
    echo "Please install Docker Compose or update Docker to a version that includes 'docker compose'"
    exit 1
fi

# Check NVIDIA support
if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✅ NVIDIA GPU detected${NC}"
    
    # Check if NVIDIA Container Toolkit is installed
    if docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✅ NVIDIA Container Toolkit working${NC}"
    else
        echo -e "${YELLOW}⚠️  NVIDIA Container Toolkit may not be properly configured${NC}"
        echo "You might need to install it: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html"
    fi
else
    echo -e "${YELLOW}⚠️  No NVIDIA GPU detected (CPU-only mode)${NC}"
fi

# 2. Create directories
echo ""
echo -e "${BLUE}2. Creating directories...${NC}"

directories=("work" "custom-notebooks" "data" "models" "outputs")
for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}✅ Created $dir/${NC}"
    else
        echo -e "${YELLOW}📁 $dir/ already exists${NC}"
    fi
done

# 3. Set up environment file
echo ""
echo -e "${BLUE}3. Setting up environment configuration...${NC}"

if [ ! -f ".env" ]; then
    cp .env.template .env
    echo -e "${GREEN}✅ Created .env from template${NC}"
    
    # Prompt for basic configuration
    echo ""
    echo -e "${YELLOW}Let's configure some basic settings:${NC}"
    
    read -p "Enter a Jupyter password (or press Enter for no password): " jupyter_password
    if [ ! -z "$jupyter_password" ]; then
        sed -i "s/JUPYTER_PASSWORD=/JUPYTER_PASSWORD=$jupyter_password/" .env
    fi
    
    read -p "Enter your Hugging Face token (optional, press Enter to skip): " hf_token
    if [ ! -z "$hf_token" ]; then
        sed -i "s/HF_TOKEN=/HF_TOKEN=$hf_token/" .env
    fi
    
    read -p "Enter your Wandb API key (optional, press Enter to skip): " wandb_key
    if [ ! -z "$wandb_key" ]; then
        sed -i "s/WANDB_API_KEY=/WANDB_API_KEY=$wandb_key/" .env
    fi
    
else
    echo -e "${YELLOW}📄 .env already exists${NC}"
fi

# 4. Make scripts executable
echo ""
echo -e "${BLUE}4. Setting up scripts...${NC}"

if [ -d "scripts" ]; then
    chmod +x scripts/*.sh
    echo -e "${GREEN}✅ Made scripts executable${NC}"
fi

# 5. Test Docker setup
echo ""
echo -e "${BLUE}5. Testing Docker setup...${NC}"

if docker info &> /dev/null; then
    echo -e "${GREEN}✅ Docker daemon is running${NC}"
else
    echo -e "${RED}❌ Docker daemon is not running${NC}"
    echo "Please start Docker and try again"
    exit 1
fi

# 6. Show next steps
echo ""
echo -e "${GREEN}🎉 Setup complete!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Start the environment:"
echo -e "   ${YELLOW}./scripts/launcher.sh start${NC}"
echo ""
echo "2. Access Jupyter Lab:"
echo -e "   ${YELLOW}http://localhost:8888${NC}"
echo ""
echo "3. Check out the examples:"
echo -e "   ${YELLOW}ls examples/${NC}"
echo ""
echo "4. Read the documentation:"
echo -e "   ${YELLOW}cat README.md${NC}"
echo ""
echo -e "${BLUE}For quick start:${NC}"
echo -e "   ${YELLOW}cat QUICKSTART.md${NC}"

echo ""
echo "Happy fine-tuning! 🦥"