#!/bin/bash

# Install Build Tools for BoringSSL Android NDK Build
# Script 1: Install essential build tools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Installing Build Tools for BoringSSL ===${NC}"
echo "This script will install all necessary tools for building BoringSSL with Android NDK"
echo

# Update package list
echo -e "${BLUE}Updating package list...${NC}"
sudo apt update

# Install essential build tools
echo -e "${BLUE}Installing essential build tools...${NC}"
sudo apt install -y \
  build-essential \
  cmake \
  ninja-build \
  git \
  wget \
  curl \
  unzip \
  python3 \
  python3-pip \
  pkg-config \
  autotools-dev \
  autoconf \
  automake \
  libtool \
  make \
  gcc \
  g++ \
  clang \
  llvm

# Install Go (required for BoringSSL)
echo -e "${BLUE}Installing Go...${NC}"
if ! command -v go &> /dev/null; then
    GO_VERSION="1.21.5"
    wget -q https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    rm go${GO_VERSION}.linux-amd64.tar.gz
    
    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    
    echo -e "${GREEN}Go ${GO_VERSION} installed successfully${NC}"
else
    echo -e "${YELLOW}Go is already installed: $(go version)${NC}"
fi

# Install additional Python tools
echo -e "${BLUE}Installing Python tools...${NC}"
pip3 install --user setuptools wheel

# Verify installations
echo -e "${GREEN}=== Verifying Installations ===${NC}"
echo "CMake: $(cmake --version | head -1)"
echo "Ninja: $(ninja --version)"
echo "Git: $(git --version)"
echo "Python3: $(python3 --version)"
echo "Go: $(go version 2>/dev/null || echo 'Go not found in current session - restart terminal')"
echo "GCC: $(gcc --version | head -1)"
echo "Clang: $(clang --version | head -1)"

# Create workspace directory
echo -e "${BLUE}Creating workspace directory...${NC}"
mkdir -p ~/android-build
cd ~/android-build

echo -e "${GREEN}=== Build Tools Installation Complete ===${NC}"
echo "Next steps:"
echo "1. Run: source ~/.bashrc (or restart terminal)"
echo "2. Run: ./2_install_ndk.sh"
echo
echo "Workspace created at: ~/android-build"