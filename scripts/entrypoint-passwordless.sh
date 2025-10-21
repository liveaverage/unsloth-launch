#!/bin/bash
set -e

# Custom Unsloth Entrypoint - Passwordless Jupyter
# This replaces the default Unsloth entrypoint to disable Jupyter authentication

# Mount NVIDIA driver libraries (works across different driver versions)
bash /workspace/scripts/mount-nvidia-libs.sh

# Set LD_LIBRARY_PATH for CUDA libraries (FIX for PyTorch GPU detection)
export LD_LIBRARY_PATH="/usr/local/cuda-12.8/lib64:/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"
export CUDA_HOME="/usr/local/cuda-12.8"

echo "Exporting environment variables for SSH sessions..."
printenv | grep -E '^HF_|^CUDA_|^NCCL_|^JUPYTER_|^SSH_|^PUBLIC_|^USER_|^UNSLOTH_|^PATH=|^LD_LIBRARY_PATH=' | \
    sed 's/^\([^=]*\)=\(.*\)$/export \1="\2"/' > /tmp/unsloth_environment

# Also explicitly set LD_LIBRARY_PATH and CUDA_HOME in bashrc
echo 'export LD_LIBRARY_PATH="/usr/local/cuda-12.8/lib64:/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"' >> /home/unsloth/.bashrc
echo 'export CUDA_HOME="/usr/local/cuda-12.8"' >> /home/unsloth/.bashrc

# Source it in user's bashrc (no sudo needed)
echo 'source /tmp/unsloth_environment' >> /home/unsloth/.bashrc

# Use USER_PASSWORD from env, or default to 'unsloth'.
FINAL_PASSWORD="${USER_PASSWORD:-unsloth}"

# Set the password for the unsloth user
echo "unsloth:${FINAL_PASSWORD}" | sudo chpasswd
echo "User 'unsloth' password set."

# Default values
export JUPYTER_PORT=${JUPYTER_PORT:-8888}

# Configure ssh
if [ ! -z "$SSH_KEY" ]; then
    PUBLIC_SSH_KEY="$SSH_KEY"
elif [ ! -z "$PUBLIC_KEY" ]; then
    PUBLIC_SSH_KEY="$PUBLIC_KEY"
else
    PUBLIC_SSH_KEY=""
fi

if [ ! -z "$PUBLIC_SSH_KEY" ]; then
    echo "Setting up SSH key..."

    mkdir -p /home/unsloth/.ssh
    chmod 700 /home/unsloth/.ssh
    echo "$PUBLIC_SSH_KEY" > /home/unsloth/.ssh/authorized_keys
    chmod 600 /home/unsloth/.ssh/authorized_keys
    chown -R unsloth:runtimeusers /home/unsloth/.ssh
fi

echo "Checking SSH host keys..."
# Check if all required host keys exist and are not empty
HOST_KEYS_OK=true
for key_type in rsa ecdsa ed25519; do
    key_file="/etc/ssh/ssh_host_${key_type}_key"
    if [ ! -f "$key_file" ] || [ ! -s "$key_file" ]; then
        echo "Missing or empty SSH host key: $key_file"
        HOST_KEYS_OK=false
        break
    fi
done

if [ "$HOST_KEYS_OK" = false ]; then
    echo "Generating SSH host keys..."
    # Remove any existing (possibly corrupted) keys
    sudo rm -f /etc/ssh/ssh_host_*
    # Generate fresh keys
    sudo ssh-keygen -A
    # Verify they were created
    sudo ls -la /etc/ssh/ssh_host_* 2>/dev/null || echo "Warning: SSH host keys may not have been generated properly"
else
    echo "SSH host keys already exist and appear valid"
fi

# Configure Jupyter - PASSWORDLESS MODE
echo "Generating Jupyter configuration (PASSWORDLESS MODE)..."
mkdir -p /home/unsloth/.jupyter

python3 << 'EOFPYTHON'
import os

config_file = '/home/unsloth/.jupyter/jupyter_lab_config.py'

config_content = f'''
c.ServerApp.allow_root = False
c.ServerApp.allow_remote_access = True
c.ServerApp.open_browser = False
c.ServerApp.ip = "0.0.0.0"
c.ServerApp.port = {os.getenv('JUPYTER_PORT', '8888')}
c.ServerApp.notebook_dir = "/workspace"
c.ServerApp.terminado_settings = {{"shell_command": ["/bin/bash", "-l"]}}
c.ServerApp.allow_origin = "*"

# Disable authentication - passwordless access
c.ServerApp.token = ""
c.ServerApp.password = ""
c.IdentityProvider.token = ""
'''

with open(config_file, 'w') as f:
    f.write(config_content)

print(f'✓ Jupyter configured for PASSWORDLESS ACCESS')
print(f'✓ Config written to {config_file}')
EOFPYTHON

sudo mkdir -p /var/run/sshd

echo "Handing over control to supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
