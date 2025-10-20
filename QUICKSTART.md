# Quick Start Guide

## 1. Prerequisites Check

```bash
# Check Docker
docker --version
docker-compose --version

# Check NVIDIA (if using GPU)
nvidia-smi

# Check NVIDIA Docker support
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi
```

## 2. Setup

```bash
# Create environment configuration
cp .env.template .env

# Optional: Edit configuration
nano .env
```

## 3. Choose Your Path

### Option A: Default Environment (Fastest)
```bash
./scripts/launcher.sh start
```
Access: http://localhost:8888

### Option B: Specific Model
```bash
# Llama 3 8B
./scripts/launcher.sh start llama3-8b

# Mistral 7B  
./scripts/launcher.sh start mistral-7b

# Qwen 2 7B
./scripts/launcher.sh start qwen2-7b

# CodeLlama 7B
./scripts/launcher.sh start codellama-7b
```

### Option C: Custom Configuration
```bash
# Edit .env file with your preferences
export MODEL_NAME=unsloth/llama-3-8b-bnb-4bit
export JUPYTER_PASSWORD=mypassword
export HF_TOKEN=your_token_here

./scripts/launcher.sh start
```

## 4. Access Your Environment

- **Jupyter Lab**: http://localhost:8888
- **SSH** (if configured): `ssh -p 2222 unsloth@localhost`

## 5. File Locations

- **Official notebooks**: `/workspace/unsloth-notebooks/`
- **Your work**: `/workspace/work/` (mounted to `./work/`)
- **Custom notebooks**: `/workspace/custom-notebooks/`
- **Models**: `/workspace/models/`
- **Data**: `/workspace/data/`

## 6. Common Commands

```bash
# View logs
./scripts/launcher.sh logs

# Stop container
./scripts/launcher.sh stop

# Download additional notebooks
./scripts/launcher.sh download

# Clean up everything
./scripts/launcher.sh clean
```

## 7. Troubleshooting

### No GPU detected
```bash
# Install NVIDIA Container Toolkit
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### Port already in use
```bash
# Change ports in .env
JUPYTER_HOST_PORT=8889
SSH_HOST_PORT=2223
```

### Permission issues
```bash
# Fix directory permissions
sudo chown -R $(id -u):$(id -g) work/ data/ models/ outputs/
```

That's it! You should now have a running Unsloth environment ready for fine-tuning.