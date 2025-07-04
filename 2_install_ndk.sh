#!/bin/bash

# Install Android NDK for BoringSSL Build
# Script 2: Download and setup Android NDK

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NDK_VERSION="28b"
NDK_URL="https://dl.google.com/android/repository/android-ndk-r${NDK_VERSION}-linux.zip"
INSTALL_DIR="$HOME/android-build"
NDK_DIR="$INSTALL_DIR/android-ndk-r${NDK_VERSION}"

echo -e "${GREEN}=== Installing Android NDK r${NDK_VERSION} ===${NC}"
echo "Installation directory: $INSTALL_DIR"
echo "NDK URL: $NDK_URL"
echo

# Create installation directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Check if NDK already exists
if [ -d "$NDK_DIR" ]; then
    echo -e "${YELLOW}Android NDK r${NDK_VERSION} already exists at $NDK_DIR${NC}"
    echo -e "${YELLOW}Skipping download. Delete the directory to reinstall.${NC}"
else
    # Download NDK
    echo -e "${BLUE}Downloading Android NDK r${NDK_VERSION}...${NC}"
    echo "This may take several minutes depending on your connection speed."
    
    if wget --progress=bar:force:noscroll -O "android-ndk-r${NDK_VERSION}-linux.zip" "$NDK_URL"; then
        echo -e "${GREEN}Download completed successfully${NC}"
    else
        echo -e "${RED}Download failed! Please check your internet connection.${NC}"
        exit 1
    fi

    # Extract NDK
    echo -e "${BLUE}Extracting Android NDK...${NC}"
    if unzip -q "android-ndk-r${NDK_VERSION}-linux.zip"; then
        echo -e "${GREEN}Extraction completed successfully${NC}"
        
        # Clean up zip file
        rm "android-ndk-r${NDK_VERSION}-linux.zip"
        echo "Cleaned up zip file"
    else
        echo -e "${RED}Extraction failed!${NC}"
        exit 1
    fi
fi

# Set up environment variables
echo -e "${BLUE}Setting up environment variables...${NC}"

# Add to .bashrc if not already present
if ! grep -q "ANDROID_NDK_HOME.*android-ndk-r${NDK_VERSION}" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Android NDK Environment" >> ~/.bashrc
    echo "export ANDROID_NDK_HOME=\"$NDK_DIR\"" >> ~/.bashrc
    echo "export ANDROID_NDK_ROOT=\"$NDK_DIR\"" >> ~/.bashrc
    echo "export PATH=\"\$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:\$PATH\"" >> ~/.bashrc
    echo -e "${GREEN}Environment variables added to ~/.bashrc${NC}"
else
    echo -e "${YELLOW}Environment variables already exist in ~/.bashrc${NC}"
fi

# Export for current session
export ANDROID_NDK_HOME="$NDK_DIR"
export ANDROID_NDK_ROOT="$NDK_DIR"
export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"

# Verify installation
echo -e "${GREEN}=== Verifying NDK Installation ===${NC}"
if [ -f "$NDK_DIR/ndk-build" ]; then
    echo "✓ NDK installed successfully"
    echo "✓ NDK Location: $NDK_DIR"
    echo "✓ NDK Version: $(cat $NDK_DIR/source.properties | grep Pkg.Revision | cut -d'=' -f2 | tr -d ' ')"
    
    # Check toolchain
    if [ -f "$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang" ]; then
        echo "✓ ARM64 toolchain found"
    else
        echo -e "${YELLOW}⚠ ARM64 toolchain not found${NC}"
    fi
    
    # Show disk usage
    echo "NDK Size: $(du -sh $NDK_DIR | cut -f1)"
    
else
    echo -e "${RED}✗ NDK installation verification failed${NC}"
    exit 1
fi

# Create NDK info script
cat > ndk_info.sh << 'EOF'
#!/bin/bash
echo "=== Android NDK Information ==="
echo "NDK Home: $ANDROID_NDK_HOME"
echo "NDK Root: $ANDROID_NDK_ROOT"
echo "NDK Build: $(which ndk-build 2>/dev/null || echo 'Not in PATH')"
echo "ARM64 Clang: $(which aarch64-linux-android21-clang 2>/dev/null || echo 'Not in PATH')"
echo ""
echo "Available Android APIs:"
ls $ANDROID_NDK_HOME/platforms/ 2>/dev/null | head -10
EOF
chmod +x ndk_info.sh

echo -e "${GREEN}=== Android NDK Installation Complete ===${NC}"
echo "Environment variables set for current session."
echo "To make them permanent, run: source ~/.bashrc"
echo ""
echo "Next steps:"
echo "1. Run: source ~/.bashrc"
echo "2. Run: ./ndk_info.sh (to verify NDK setup)"
echo "3. Run: ./3_download_boringssl.sh"
echo ""
echo "NDK installation directory: $NDK_DIR"