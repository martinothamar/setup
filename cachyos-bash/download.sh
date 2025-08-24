#!/bin/bash

set -euo pipefail

REPO_URL="https://github.com/martinothamar/setup/archive/refs/heads/main.zip"
TEMP_DIR=$(mktemp -d)
EXTRACT_DIR="$TEMP_DIR/setup-main"

echo "Downloading setup repository..."
curl -L "$REPO_URL" -o "$TEMP_DIR/main.zip"

echo "Extracting archive..."
unzip -q "$TEMP_DIR/main.zip" -d "$TEMP_DIR"

echo "Copying cachyos folder..."
if [ -d "$EXTRACT_DIR/cachyos" ]; then
    cp -r "$EXTRACT_DIR/cachyos"/* ./
    echo "Successfully extracted cachyos folder contents"
else
    echo "Error: cachyos folder not found in repository"
    exit 1
fi

echo "Cleaning up..."
rm -rf "$TEMP_DIR"

echo "Done!"


