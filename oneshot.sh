#!/bin/bash
# One-shot setup and launch for Unsloth Launch
# Usage: bash oneshot.sh
set -e

REPO_URL="https://github.com/liveaverage/unsloth-launch.git"
REPO_DIR="unsloth-launch"

# 1. Clone the repo if not already present
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning $REPO_URL ..."
    git clone "$REPO_URL"
else
    echo "Repo already cloned: $REPO_DIR"
fi
cd "$REPO_DIR"

# 2. Set up environment for no Jupyter password
echo "Setting up .env for no Jupyter password..."
if [ ! -f .env ]; then
    cp .env.template .env
fi
sed -i 's/^JUPYTER_PASSWORD=.*/JUPYTER_PASSWORD=/' .env

# 3. Build and start the container with restart policy always
# Detect docker compose command
if docker compose version &> /dev/null; then
    export DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    export DOCKER_COMPOSE_CMD="docker-compose"
else
    echo "Docker Compose not found. Please install Docker Compose."
    exit 1
fi


# 4. Start the container
$DOCKER_COMPOSE_CMD up -d unsloth-jupyter

# 5. Show status and access info
echo "\nUnsloth Launch is running!"
echo "Access Jupyter Lab at: http://localhost:8888 (no password)"
$DOCKER_COMPOSE_CMD ps
