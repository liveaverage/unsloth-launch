# Quick Start - Unsloth Passwordless Jupyter

## 🚀 Get Started in 3 Steps

### Step 1: Start the Container
```bash
cd /home/jr/Documents/VS/brev-unsloth
docker compose up -d
```

### Step 2: Wait for Startup
```bash
# Watch the logs
docker compose logs -f

# Look for: "Jupyter configured for PASSWORDLESS ACCESS"
```

### Step 3: Access Jupyter
Open your browser and go to:
```
http://localhost:8888
```

**✅ No password required!** - You should have direct access to Jupyter Lab

---

## 📊 Verify Everything is Working

Check that Jupyter is running:
```bash
docker compose ps
```

Check the Jupyter config is correct:
```bash
docker exec unsloth-notebook cat /home/unsloth/.jupyter/jupyter_lab_config.py | grep -E "token|password"
```

Should show:
```
c.ServerApp.token = ""
c.ServerApp.password = ""
c.IdentityProvider.token = ""
```

---

## 🛑 Stop the Container

```bash
docker compose down
```

---

## 📝 Environment Variables

Key variables in `.env`:

```bash
# Jupyter Configuration
JUPYTER_PORT=8888
JUPYTER_PASSWORD=          # Leave blank for passwordless mode
JUPYTER_TOKEN=             # Leave blank for passwordless mode

# GPU Configuration
GPU_COUNT=all              # Use all GPUs
MEMORY_RESERVATION=8G

# SSH Configuration (optional)
SSH_KEY=                   # Paste your public SSH key here
```

---

## 🔧 Advanced: Re-enable Password Protection

If you want password protection again, comment out the custom entrypoint in `docker-compose.yml`:

```yaml
# Remove or comment out these lines:
# entrypoint:
#   - /bin/bash
#   - /workspace/scripts/entrypoint-passwordless.sh
```

Then set `USER_PASSWORD` or `JUPYTER_PASSWORD` in `.env`:
```bash
USER_PASSWORD=mypassword123
JUPYTER_PASSWORD=
# Don't set JUPYTER_PASSWORD - let it use USER_PASSWORD instead
```

---

## ⚙️ What's Running Inside

The container includes:

- **Unsloth** - Fast LLM finetuning framework
- **Jupyter Lab** - Passwordless web IDE
- **SSH Server** - Remote access (optional)
- **CUDA 12.8** - GPU support
- **Conda environment** - Pre-configured with ML libraries

---

## 📂 Directory Structure

```
/workspace/
├── work/                  # Your working files
├── custom-notebooks/      # Custom Jupyter notebooks
├── data/                  # Data storage
├── models/                # Model cache
└── outputs/               # Training outputs
```

All directories are mounted from your host machine.

---

## 🐛 Troubleshooting

### Still getting password prompt?

1. **Restart the container:**
   ```bash
   docker compose down
   docker compose up -d
   ```

2. **Check the entrypoint is being used:**
   ```bash
   docker compose logs | grep "PASSWORDLESS"
   ```

3. **Verify Jupyter config:**
   ```bash
   docker exec unsloth-notebook ls -la /home/unsloth/.jupyter/
   ```

### GPU not detected?

```bash
docker exec unsloth-notebook nvidia-smi
```

If no GPU shows, check your Docker daemon's GPU configuration.

### Port already in use?

Change the port in `.env`:
```bash
JUPYTER_HOST_PORT=8889    # Change from 8888 to 8889
```

Then access: `http://localhost:8889`

---

## 📚 Next Steps

1. **Upload a notebook** to `/workspace/work/` on your host machine
2. **Start coding** - Jupyter will auto-reload
3. **Use Unsloth APIs** - Import and use Unsloth for LLM finetuning

Example:
```python
from unsloth import FastLanguageModel
from transformers import AutoTokenizer

# Your model finetuning code here
```

---

**Everything is ready to go! Enjoy your passwordless Jupyter environment! 🎉**
