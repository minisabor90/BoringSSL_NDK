#!/bin/bash

# Download BoringSSL Source Code
# Script 3: Clone BoringSSL repository and prepare for build

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="$HOME/android-build"
BORINGSSL_DIR="$WORKSPACE_DIR/boringssl"
BORINGSSL_REPO="https://boringssl.googlesource.com/boringssl"

echo -e "${GREEN}=== Downloading BoringSSL Source Code ===${NC}"
echo "Workspace: $WORKSPACE_DIR"
echo "BoringSSL Directory: $BORINGSSL_DIR"
echo "Repository: $BORINGSSL_REPO"
echo

# Ensure workspace exists
mkdir -p "$WORKSPACE_DIR"
cd "$WORKSPACE_DIR"

# Check if BoringSSL already exists
if [ -d "$BORINGSSL_DIR" ]; then
    echo -e "${YELLOW}BoringSSL directory already exists${NC}"
    echo "Do you want to:"
    echo "1. Update existing repository (git pull)"
    echo "2. Delete and re-clone"
    echo "3. Skip and use existing"
    read -p "Choose option (1/2/3): " choice
    
    case $choice in
        1)
            echo -e "${BLUE}Updating existing BoringSSL repository...${NC}"
            cd "$BORINGSSL_DIR"
            git pull origin main || git pull origin master
            ;;
        2)
            echo -e "${BLUE}Removing existing directory and re-cloning...${NC}"
            rm -rf "$BORINGSSL_DIR"
            git clone "$BORINGSSL_REPO" boringssl
            ;;
        3)
            echo -e "${YELLOW}Using existing BoringSSL directory${NC}"
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
else
    # Clone BoringSSL
    echo -e "${BLUE}Cloning BoringSSL repository...${NC}"
    if git clone "$BORINGSSL_REPO" boringssl; then
        echo -e "${GREEN}BoringSSL cloned successfully${NC}"
    else
        echo -e "${RED}Failed to clone BoringSSL repository${NC}"
        exit 1
    fi
fi

# Enter BoringSSL directory
cd "$BORINGSSL_DIR"

# Show repository information
echo -e "${GREEN}=== BoringSSL Repository Information ===${NC}"
echo "Current branch: $(git branch --show-current 2>/dev/null || echo 'detached HEAD')"
echo "Latest commit: $(git log --oneline -1)"
echo "Repository status: $(git status --porcelain | wc -l) modified files"
echo

# Check Go installation (required for BoringSSL)
echo -e "${BLUE}Checking Go installation...${NC}"
if command -v go &> /dev/null; then
    echo "✓ Go version: $(go version)"
else
    echo -e "${RED}✗ Go is not installed or not in PATH${NC}"
    echo "Please ensure Go is installed and run: source ~/.bashrc"
    exit 1
fi

# Check required tools
echo -e "${BLUE}Checking build tools...${NC}"
tools_ok=true

check_tool() {
    if command -v "$1" &> /dev/null; then
        echo "✓ $1: $(which $1)"
    else
        echo -e "${RED}✗ $1: not found${NC}"
        tools_ok=false
    fi
}

check_tool cmake
check_tool ninja
check_tool git
check_tool python3

if [ "$tools_ok" = false ]; then
    echo -e "${RED}Some required tools are missing. Please run 1_install_tools.sh first.${NC}"
    exit 1
fi

# Check Android NDK
echo -e "${BLUE}Checking Android NDK...${NC}"
if [ -n "$ANDROID_NDK_HOME" ] && [ -d "$ANDROID_NDK_HOME" ]; then
    echo "✓ Android NDK: $ANDROID_NDK_HOME"
    if [ -f "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang" ]; then
        echo "✓ ARM64 toolchain available"
    else
        echo -e "${YELLOW}⚠ ARM64 toolchain not found${NC}"
    fi
else
    echo -e "${RED}✗ Android NDK not found${NC}"
    echo "Please run 2_install_ndk.sh and source ~/.bashrc"
    exit 1
fi

# Create build directory structure
echo -e "${BLUE}Preparing build environment...${NC}"
mkdir -p build-android-arm64-static
mkdir -p build-logs

# Create a simple test to verify BoringSSL source
echo -e "${BLUE}Verifying BoringSSL source code...${NC}"
if [ -f "CMakeLists.txt" ] && [ -d "crypto" ] && [ -d "ssl" ] && [ -d "include" ]; then
    echo "✓ BoringSSL source structure verified"
    echo "✓ CMakeLists.txt found"
    echo "✓ crypto/ directory found"
    echo "✓ ssl/ directory found"
    echo "✓ include/ directory found"
else
    echo -e "${RED}✗ BoringSSL source structure incomplete${NC}"
    exit 1
fi

# Show directory contents
echo -e "${GREEN}=== BoringSSL Directory Contents ===${NC}"
ls -la | head -15

# Create environment info script
cat > build_env_info.sh << 'EOF'
#!/bin/bash
echo "=== Build Environment Information ==="
echo "Working Directory: $(pwd)"
echo "BoringSSL Version: $(git describe --tags --always 2>/dev/null || echo 'unknown')"
echo "Android NDK: $ANDROID_NDK_HOME"
echo "Go Version: $(go version 2>/dev/null || echo 'not found')"
echo "CMake Version: $(cmake --version | head -1)"
echo "Ninja Version: ninja $(ninja --version)"
echo ""
echo "Ready for build: $([ -f CMakeLists.txt ] && echo 'YES' || echo 'NO')"
EOF
chmod +x build_env_info.sh

echo -e "${GREEN}=== BoringSSL Download Complete ===${NC}"
echo "BoringSSL source code is ready for building."
echo ""
echo "Next steps:"
echo "1. Run: ./build_env_info.sh (to verify environment)"
echo "2. Run: ./4_build_boringssl.sh (to start building)"
echo ""
echo "Build directory: $BORINGSSL_DIR"
echo "Environment script created: build_env_info.sh"