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

# Set the password for the unsloth user (if we have sudo access)
if sudo -n true 2>/dev/null; then
    echo "unsloth:${FINAL_PASSWORD}" | sudo chpasswd
    echo "User 'unsloth' password set."
else
    echo "Note: Cannot set user password (no sudo access)"
fi

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
    if sudo -n true 2>/dev/null; then
        echo "Generating SSH host keys..."
        # Remove any existing (possibly corrupted) keys
        sudo rm -f /etc/ssh/ssh_host_*
        # Generate fresh keys
        sudo ssh-keygen -A
        # Verify they were created
        sudo ls -la /etc/ssh/ssh_host_* 2>/dev/null || echo "Warning: SSH host keys may not have been generated properly"
    else
        echo "Note: Cannot generate SSH host keys (no sudo access)"
    fi
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

# Create SSH run directory if we have permissions
if [ -w /var/run ]; then
    mkdir -p /var/run/sshd
elif sudo -n true 2>/dev/null; then
    sudo mkdir -p /var/run/sshd
else
    echo "Note: Cannot create /var/run/sshd (no write access)"
fi

# Fix Jupyter kernel to always have CUDA environment variables
echo "Configuring Jupyter kernels with CUDA environment..."

# Dynamically detect CUDA installation
CUDA_PATHS=""
CUDA_HOME_DETECTED=""

# Check common CUDA installation locations
for cuda_dir in /usr/local/cuda* /opt/cuda*; do
    if [ -d "$cuda_dir/lib64" ]; then
        echo "Found CUDA installation at: $cuda_dir"
        CUDA_PATHS="$cuda_dir/lib64:$CUDA_PATHS"
        if [ -z "$CUDA_HOME_DETECTED" ]; then
            CUDA_HOME_DETECTED="$cuda_dir"
        fi
    fi
done

# Add system library paths
CUDA_PATHS="${CUDA_PATHS}/usr/lib/x86_64-linux-gnu:/opt/conda/lib"

# Use detected or fallback to environment variable
CUDA_HOME_FINAL="${CUDA_HOME_DETECTED:-${CUDA_HOME:-/usr/local/cuda}}"

echo "Using CUDA_HOME: $CUDA_HOME_FINAL"
echo "Using LD_LIBRARY_PATH: $CUDA_PATHS"

# Create kernel spec directory
mkdir -p /home/unsloth/.local/share/jupyter/kernels/python3-cuda

# Create a kernel with dynamically detected CUDA paths
cat > /home/unsloth/.local/share/jupyter/kernels/python3-cuda/kernel.json << KERNEL_EOF
{
  "argv": [
    "/opt/conda/bin/python3",
    "-m",
    "ipykernel_launcher",
    "-f",
    "{connection_file}"
  ],
  "display_name": "Python 3 (CUDA)",
  "language": "python",
  "env": {
    "LD_LIBRARY_PATH": "${CUDA_PATHS}",
    "CUDA_HOME": "${CUDA_HOME_FINAL}",
    "CUDA_ROOT": "${CUDA_HOME_FINAL}",
    "CUDA_PATH": "${CUDA_HOME_FINAL}",
    "CUDA_VISIBLE_DEVICES": "0",
    "NVIDIA_VISIBLE_DEVICES": "0",
    "PATH": "${CUDA_HOME_FINAL}/bin:/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  }
}
KERNEL_EOF

# Also try to update the default Python 3 kernel if we have write access
if [ -d "/opt/conda/share/jupyter/kernels/python3" ] && [ -w "/opt/conda/share/jupyter/kernels/python3" ]; then
    echo "Updating default Python 3 kernel with CUDA environment..."
    cp /home/unsloth/.local/share/jupyter/kernels/python3-cuda/kernel.json /opt/conda/share/jupyter/kernels/python3/kernel.json
else
    echo "Note: Cannot update system kernel (no write access), but user kernel 'Python 3 (CUDA)' is available"
fi

# Create IPython startup script for CUDA initialization
mkdir -p /home/unsloth/.ipython/profile_default/startup
cat > /home/unsloth/.ipython/profile_default/startup/00-cuda-setup.py << IPYTHON_EOF
import os
import sys
import glob

# Dynamically detect CUDA installation
cuda_dirs = glob.glob('/usr/local/cuda*') + glob.glob('/opt/cuda*')
cuda_paths = []
cuda_home = None

for cuda_dir in cuda_dirs:
    lib64_path = os.path.join(cuda_dir, 'lib64')
    if os.path.exists(lib64_path):
        cuda_paths.append(lib64_path)
        if cuda_home is None:
            cuda_home = cuda_dir

# Add system library paths
cuda_paths.extend(['/usr/lib/x86_64-linux-gnu', '/opt/conda/lib'])

# Build LD_LIBRARY_PATH
ld_library_path = ':'.join(cuda_paths)
if 'LD_LIBRARY_PATH' in os.environ:
    ld_library_path = ld_library_path + ':' + os.environ['LD_LIBRARY_PATH']

# Use detected CUDA or fallback
if cuda_home is None:
    cuda_home = os.environ.get('CUDA_HOME', '/usr/local/cuda')

# Set environment variables
os.environ['LD_LIBRARY_PATH'] = ld_library_path
os.environ['CUDA_HOME'] = cuda_home
os.environ['CUDA_ROOT'] = cuda_home
os.environ['CUDA_PATH'] = cuda_home
# Force GPU visibility - override any 'void' settings
os.environ['CUDA_VISIBLE_DEVICES'] = '0'
os.environ['NVIDIA_VISIBLE_DEVICES'] = '0'

print(f"CUDA environment configured: {cuda_home}")

# CRITICAL FIX: Force PyTorch CUDA initialization in Docker environments
# This must happen before any other PyTorch operations
def _force_cuda_init():
    try:
        import torch
        # Force CUDA initialization - required in Docker environments
        # where lazy initialization fails
        torch.cuda.init()
        
        if torch.cuda.is_available():
            device_name = torch.cuda.get_device_name(0)
            print(f"✅ PyTorch CUDA initialized: {device_name}")
            # Pre-warm CUDA to ensure it stays initialized
            _ = torch.zeros(1).cuda()
            return True
        else:
            print("⚠️ CUDA not available after forced init")
            return False
    except Exception as e:
        print(f"Note: CUDA initialization: {e}")
        return False

# Run initialization
_cuda_available = _force_cuda_init()

# Clean up namespace
del _force_cuda_init
IPYTHON_EOF

echo "✓ Jupyter kernels configured with CUDA environment"

echo "Handing over control to supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
