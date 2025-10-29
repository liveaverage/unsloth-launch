# Clean Restart Guide

When you modify the entrypoint script or environment configuration, you need to clear cached state for changes to take effect.

## Full Clean Restart (Recommended for Testing Changes)

```bash
cd /path/to/unsloth-launch

# 1. Stop and remove containers
docker compose down

# 2. Remove the persistent volume (contains kernel configs and IPython startup scripts)
docker volume rm unsloth-launch_unsloth-home 2>/dev/null || docker volume rm unsloth-network_unsloth-home 2>/dev/null || true

# 3. Remove any dangling volumes
docker volume prune -f

# 4. Start fresh
docker compose up -d

# 5. Wait for startup (20 seconds)
sleep 20

# 6. Check logs
docker compose logs -f | tail -30
```

## What Gets Cleared

The volume `unsloth-home` contains:
- `/home/unsloth/.jupyter/` - Jupyter configuration
- `/home/unsloth/.ipython/profile_default/startup/` - IPython startup scripts **← GPU fix**
- `/home/unsloth/.local/share/jupyter/kernels/` - Kernel configurations **← GPU fix**
- Jupyter server cache and kernel state

## What Persists (Your Work)

These are in mounted directories and **will NOT be deleted**:
- `./work/` - Your notebooks
- `./data/` - Datasets
- `./models/` - Downloaded models
- `./outputs/` - Training outputs
- `./scripts/` - Scripts
- `./configs/` - Configs

## Quick Restart (No Volume Clear)

If you just changed docker compose.yml environment variables:

```bash
docker compose down && docker compose up -d
```

## Nuclear Option (Full Cleanup)

**⚠️ WARNING: This removes EVERYTHING including your work!**

```bash
cd /path/to/unsloth-launch

# Stop everything
docker compose down -v

# Remove all containers with unsloth in the name
docker ps -a | grep unsloth | awk '{print $1}' | xargs -r docker rm -f

# Remove all volumes
docker volume ls | grep unsloth | awk '{print $2}' | xargs -r docker volume rm

# Clear work directories (BE CAREFUL!)
rm -rf work/* data/* models/* outputs/*

# Start fresh
docker compose up -d
```

## After Clean Restart

1. **Wait ~20 seconds** for the container to fully start
2. **Refresh your browser** (Ctrl+Shift+R to clear cache)
3. **Create a new notebook** or **restart the kernel** in existing notebooks
4. The GPU fix scripts will run automatically on first kernel start

## Verify the Fix Applied

In a new or restarted notebook:

```python
import os
print(f"LD_LIBRARY_PATH: {os.environ.get('LD_LIBRARY_PATH', 'NOT SET')[:80]}...")
print(f"CUDA_HOME: {os.environ.get('CUDA_HOME', 'NOT SET')}")
print(f"NVIDIA_VISIBLE_DEVICES: {os.environ.get('NVIDIA_VISIBLE_DEVICES', 'NOT SET')}")

import torch
torch.cuda.init()
print(f"\nCUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
```

If `LD_LIBRARY_PATH` shows "NOT SET", the kernel config didn't apply → try full clean restart above.

## Why Kernel State Persists

Jupyter stores kernel state in:
- `~/.local/share/jupyter/runtime/` - Active kernel connections
- `~/.ipython/profile_default/history.sqlite` - Command history
- Kernel process memory

A **fresh volume** ensures the startup scripts and kernel configs are regenerated from your updated entrypoint script.

