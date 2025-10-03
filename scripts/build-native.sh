#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."

echo "Building Zig native addon..."

# Detect Node.js include path
if command -v node &>/dev/null; then
  NODE_BIN=$(command -v node)
  NODE_INCLUDE_PATH="$(dirname "$(dirname "$NODE_BIN")")/include/node"
  export NODE_INCLUDE_PATH
  echo "Using Node.js headers from: $NODE_INCLUDE_PATH"
else
  echo "Warning: node not found in PATH, using default include path"
fi

cd native

# Build the addon
zig build -Doptimize=ReleaseSafe

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
  if [[ $(uname -m) == "arm64" ]]; then
    PLATFORM="darwin-arm64"
    EXT="dylib"
  else
    PLATFORM="darwin-x64"
    EXT="dylib"
  fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  PLATFORM="linux-x64"
  EXT="so"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
  PLATFORM="win32-x64"
  EXT="dll"
else
  echo "Unknown platform: $OSTYPE"
  exit 1
fi

# Create platform directory
mkdir -p ../lib/$PLATFORM

# Copy the built library and rename to .node
cp zig-out/lib/libpossess.$EXT ../lib/$PLATFORM/possess.node

echo "✓ Built native addon for $PLATFORM"
