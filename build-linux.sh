#!/bin/bash

# Build mailchatd for linux-amd64 using Docker

set -e

echo "Building mailchatd for linux-amd64..."

# Clean up any existing container
docker rm -f mailchatd-extract 2>/dev/null || true

# Build using Docker (with platform emulation on M1)
docker build --platform linux/amd64 -f Dockerfile.build -t mailchatd-builder .

# Create a temporary container and copy the binary out
docker create --platform linux/amd64 --name mailchatd-extract mailchatd-builder
docker cp mailchatd-extract:/mailchatd ./mailchatd-linux-amd64
docker rm mailchatd-extract

# Make it executable
chmod +x ./mailchatd-linux-amd64

echo ""
echo "Build complete: ./mailchatd-linux-amd64"
file ./mailchatd-linux-amd64
ls -lh ./mailchatd-linux-amd64
