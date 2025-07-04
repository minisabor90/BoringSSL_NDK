#!/bin/bash

# BoringSSL Android NDK Multi-ABI Build Script
# Builds for x86, x86_64, armeabi-v7a, arm64-v8a
# Fixed compiler crash with conservative optimization

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== BoringSSL Android NDK Multi-ABI Build Script ===${NC}"

export ANDROID_NDK_HOME=/compile/boring/android-ndk-r28b

# Configuration
ANDROID_NDK_HOME=/compile/boring/android-ndk-r28b
WORKSPACE_DIR="/compile/boring/"
BORINGSSL_DIR="$WORKSPACE_DIR/boringssl"
OUTPUT_DIR="$BORINGSSL_DIR/android-build"
ANDROID_MIN_API=23  # Android 6.0

# Supported ABIs
ABIS=("x86" "x86_64" "armeabi-v7a" "arm64-v8a")

# Check directory
if [ ! -d "$BORINGSSL_DIR" ]; then
    echo -e "${RED}Error: BoringSSL directory not found: $BORINGSSL_DIR${NC}"
    echo "Please run 3_download_boringssl.sh first"
    exit 1
fi

cd "$BORINGSSL_DIR"

if [ ! -f "CMakeLists.txt" ] || [ ! -d "crypto" ]; then
    echo -e "${RED}Error: Please run this script from the BoringSSL root directory${NC}"
    exit 1
fi

# Set Android NDK path
if [ -z "$ANDROID_NDK_HOME" ]; then
    export ANDROID_NDK_HOME="$HOME/android-build/android-ndk-r28b"
fi

if [ ! -d "$ANDROID_NDK_HOME" ]; then
    echo -e "${RED}Error: Android NDK not found at $ANDROID_NDK_HOME${NC}"
    echo "Please run 2_install_ndk.sh first"
    exit 1
fi

echo -e "${YELLOW}Using Android NDK: $ANDROID_NDK_HOME${NC}"
echo -e "${YELLOW}Target Android API: $ANDROID_MIN_API (Android 6.0+)${NC}"
echo -e "${YELLOW}Building for ABIs: ${ABIS[*]}${NC}"
echo

# Fix the sources.json path issue BEFORE running generate_build_files.py
echo -e "${BLUE}Fixing sources.json path for Android build files generation...${NC}"
if [ -f "gen/sources.json" ]; then
    mkdir -p src/gen
    cp gen/sources.json src/gen/sources.json
    echo -e "${GREEN}Fixed sources.json path: gen/sources.json -> src/gen/sources.json${NC}"
else
    echo -e "${YELLOW}gen/sources.json not found, generating...${NC}"
    python3 util/generate_build_files.py gn
    if [ -f "gen/sources.json" ]; then
        mkdir -p src/gen
        cp gen/sources.json src/gen/sources.json
        echo -e "${GREEN}Generated and fixed sources.json path${NC}"
    else
        echo -e "${RED}Error: Failed to generate gen/sources.json${NC}"
        exit 1
    fi
fi

# Generate Android build files (source.mk, Android.mk, etc.)
echo -e "${BLUE}Generating Android build files (source.mk, Android.mk)...${NC}"
python3 util/generate_build_files.py android

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Android build files generated successfully!${NC}"
    echo -e "${YELLOW}Generated files:${NC}"
    [ -f "source.mk" ] && echo "✓ source.mk"
    [ -f "Android.mk" ] && echo "✓ Android.mk"
    [ -f "crypto/Android.mk" ] && echo "✓ crypto/Android.mk"
    [ -f "ssl/Android.mk" ] && echo "✓ ssl/Android.mk"
else
    echo -e "${RED}Failed to generate Android build files!${NC}"
    exit 1
fi

# Clean and create output directory
if [ -d "$OUTPUT_DIR" ]; then
    echo -e "${YELLOW}Cleaning previous builds...${NC}"
    rm -rf "$OUTPUT_DIR"
fi

mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}Created output directory: $OUTPUT_DIR${NC}"

# Function to get optimization flags for each ABI
get_opt_flags() {
    local abi=$1
    case $abi in
        "x86")
            echo "-O2 -ffunction-sections -fdata-sections -DNDEBUG -m32"
            ;;
        "x86_64")
            echo "-O2 -ffunction-sections -fdata-sections -DNDEBUG -m64"
            ;;
        "armeabi-v7a")
            echo "-O2 -ffunction-sections -fdata-sections -DNDEBUG -mfpu=neon"
            ;;
        "arm64-v8a")
            echo "-O2 -ffunction-sections -fdata-sections -DNDEBUG"
            ;;
    esac
}

# Function to get ASM flags for each ABI
get_asm_flags() {
    local abi=$1
    case $abi in
        "x86"|"x86_64")
            echo ""
            ;;
        "armeabi-v7a")
            echo "-mfpu=neon"
            ;;
        "arm64-v8a")
            echo ""
            ;;
    esac
}

# Build function for each ABI
build_abi() {
    local abi=$1
    local build_dir="$OUTPUT_DIR/build-$abi"
    local lib_dir="$OUTPUT_DIR/lib/$abi"
    
    echo -e "${GREEN}=== Building for $abi ===${NC}"
    
    # Create build directory
    mkdir -p "$build_dir"
    mkdir -p "$lib_dir"
    cd "$build_dir"
    
    # Get optimization flags
    local opt_flags=$(get_opt_flags $abi)
    local asm_flags=$(get_asm_flags $abi)
    
    echo -e "${BLUE}Configuring CMake for $abi...${NC}"
    echo "Optimization flags: $opt_flags"
    echo "ASM flags: $asm_flags"
    
    # Configure with conservative optimization to avoid compiler crashes
    cmake -GNinja \
      -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI="$abi" \
      -DANDROID_PLATFORM="android-$ANDROID_MIN_API" \
      -DANDROID_NDK="$ANDROID_NDK_HOME" \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DCMAKE_C_FLAGS="$opt_flags" \
      -DCMAKE_CXX_FLAGS="$opt_flags" \
      -DCMAKE_ASM_FLAGS="$asm_flags" \
      -DCMAKE_EXE_LINKER_FLAGS="-Wl,--gc-sections" \
      -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--gc-sections" \
      -DOPENSSL_SMALL=ON \
      "$BORINGSSL_DIR"

    if [ $? -ne 0 ]; then
        echo -e "${RED}CMake configuration failed for $abi!${NC}"
        return 1
    fi

    echo -e "${GREEN}CMake configuration successful for $abi!${NC}"

    # Build the libraries
    echo -e "${BLUE}Building BoringSSL libraries for $abi...${NC}"
    ninja -j$(nproc)

    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Build failed with parallel jobs, trying single thread for $abi...${NC}"
        ninja -j1
        if [ $? -ne 0 ]; then
            echo -e "${RED}Build failed for $abi even with single thread!${NC}"
            return 1
        fi
    fi

    echo -e "${GREEN}Build successful for $abi!${NC}"

    # Find and copy libraries
    local crypto_lib=""
    local ssl_lib=""

    # Check common locations
    if [ -f "crypto/libcrypto.a" ]; then
        crypto_lib="crypto/libcrypto.a"
    elif [ -f "libcrypto.a" ]; then
        crypto_lib="libcrypto.a"
    fi

    if [ -f "ssl/libssl.a" ]; then
        ssl_lib="ssl/libssl.a"
    elif [ -f "libssl.a" ]; then
        ssl_lib="libssl.a"
    fi

    # Verify libraries were created
    if [ -z "$crypto_lib" ] || [ -z "$ssl_lib" ]; then
        echo -e "${RED}Error: Libraries not found after build for $abi${NC}"
        echo -e "${YELLOW}Available .a files:${NC}"
        find . -name "*.a" -type f
        return 1
    fi

    echo -e "${GREEN}Found libraries for $abi:${NC}"
    echo "✓ Crypto: $crypto_lib"
    echo "✓ SSL: $ssl_lib"

    # Copy libraries to output directory
    cp "$crypto_lib" "$lib_dir/libcrypto.a"
    cp "$ssl_lib" "$lib_dir/libssl.a"

    # Strip symbols for smaller size
    echo -e "${BLUE}Stripping symbols for $abi...${NC}"
    "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" "$lib_dir/libcrypto.a"
    "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" "$lib_dir/libssl.a"

    # Display library information
    echo -e "${YELLOW}Library sizes for $abi:${NC}"
    ls -lh "$lib_dir/libcrypto.a" "$lib_dir/libssl.a"

    # Verify architecture
    echo -e "${BLUE}Verifying architecture for $abi...${NC}"
    "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump" -f "$lib_dir/libcrypto.a" | head -3

    echo -e "${GREEN}✓ $abi build completed successfully${NC}"
    echo
    
    return 0
}

# Build all ABIs
echo -e "${GREEN}=== Starting Multi-ABI Build ===${NC}"
failed_abis=()
successful_abis=()

for abi in "${ABIS[@]}"; do
    if build_abi "$abi"; then
        successful_abis+=("$abi")
    else
        failed_abis+=("$abi")
        echo -e "${RED}Failed to build $abi${NC}"
    fi
done

# Copy shared include directory
echo -e "${BLUE}Copying shared include directory...${NC}"
cp -r "$BORINGSSL_DIR/include" "$OUTPUT_DIR/"
echo -e "${GREEN}✓ Shared include directory copied${NC}"

# Create build summary
echo -e "${GREEN}=== Multi-ABI Build Summary ===${NC}"
echo -e "${GREEN}Successful builds: ${#successful_abis[@]}/${#ABIS[@]}${NC}"
for abi in "${successful_abis[@]}"; do
    echo -e "${GREEN}✓ $abi${NC}"
done

if [ ${#failed_abis[@]} -gt 0 ]; then
    echo -e "${RED}Failed builds: ${#failed_abis[@]}${NC}"
    for abi in "${failed_abis[@]}"; do
        echo -e "${RED}✗ $abi${NC}"
    done
fi

# Show directory structure
echo -e "${BLUE}=== Output Directory Structure ===${NC}"
tree "$OUTPUT_DIR" 2>/dev/null || find "$OUTPUT_DIR" -type f | sort

# Calculate total sizes
echo -e "${BLUE}=== Library Sizes by ABI ===${NC}"
for abi in "${successful_abis[@]}"; do
    lib_dir="$OUTPUT_DIR/lib/$abi"
    if [ -d "$lib_dir" ]; then
        echo -e "${YELLOW}$abi:${NC}"
        ls -lh "$lib_dir"/*.a 2>/dev/null || echo "  No libraries found"
        total_size=$(du -ch "$lib_dir"/*.a 2>/dev/null | tail -1 | cut -f1 2>/dev/null || echo "0")
        echo "  Total: $total_size"
        echo
    fi
done

# Create integration helpers
echo -e "${BLUE}Creating integration helper files...${NC}"

# CMake integration helper
cat > "$OUTPUT_DIR/BoringSSLConfig.cmake" << EOF
# BoringSSL Multi-ABI CMake Configuration
# Usage: find_package(BoringSSL REQUIRED)

set(BORINGSSL_ROOT_DIR \${CMAKE_CURRENT_LIST_DIR})
set(BORINGSSL_INCLUDE_DIR \${BORINGSSL_ROOT_DIR}/include)

# Set ABI-specific library paths
if(ANDROID_ABI STREQUAL "x86")
    set(BORINGSSL_ABI_DIR \${BORINGSSL_ROOT_DIR}/lib/x86)
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(BORINGSSL_ABI_DIR \${BORINGSSL_ROOT_DIR}/lib/x86_64)
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(BORINGSSL_ABI_DIR \${BORINGSSL_ROOT_DIR}/lib/armeabi-v7a)
elseif(ANDROID_ABI STREQUAL "arm64-v8a")
    set(BORINGSSL_ABI_DIR \${BORINGSSL_ROOT_DIR}/lib/arm64-v8a)
else()
    message(FATAL_ERROR "Unsupported Android ABI: \${ANDROID_ABI}")
endif()

set(BORINGSSL_CRYPTO_LIBRARY \${BORINGSSL_ABI_DIR}/libcrypto.a)
set(BORINGSSL_SSL_LIBRARY \${BORINGSSL_ABI_DIR}/libssl.a)

# Create imported targets
add_library(BoringSSL::Crypto STATIC IMPORTED)
set_target_properties(BoringSSL::Crypto PROPERTIES
    IMPORTED_LOCATION \${BORINGSSL_CRYPTO_LIBRARY}
    INTERFACE_INCLUDE_DIRECTORIES \${BORINGSSL_INCLUDE_DIR}
)

add_library(BoringSSL::SSL STATIC IMPORTED)
set_target_properties(BoringSSL::SSL PROPERTIES
    IMPORTED_LOCATION \${BORINGSSL_SSL_LIBRARY}
    INTERFACE_INCLUDE_DIRECTORIES \${BORINGSSL_INCLUDE_DIR}
    INTERFACE_LINK_LIBRARIES BoringSSL::Crypto
)

# Legacy variables for compatibility
set(BORINGSSL_FOUND TRUE)
set(BORINGSSL_LIBRARIES \${BORINGSSL_SSL_LIBRARY} \${BORINGSSL_CRYPTO_LIBRARY})
set(BORINGSSL_INCLUDE_DIRS \${BORINGSSL_INCLUDE_DIR})
EOF

# Android.mk integration
cat > "$OUTPUT_DIR/Android.mk" << EOF
# BoringSSL Multi-ABI Android.mk Integration
LOCAL_PATH := \$(call my-dir)

# Crypto library
include \$(CLEAR_VARS)
LOCAL_MODULE := boringssl_crypto
LOCAL_SRC_FILES := lib/\$(TARGET_ARCH_ABI)/libcrypto.a
LOCAL_EXPORT_C_INCLUDES := \$(LOCAL_PATH)/include
include \$(PREBUILT_STATIC_LIBRARY)

# SSL library
include \$(CLEAR_VARS)
LOCAL_MODULE := boringssl_ssl
LOCAL_SRC_FILES := lib/\$(TARGET_ARCH_ABI)/libssl.a
LOCAL_EXPORT_C_INCLUDES := \$(LOCAL_PATH)/include
LOCAL_STATIC_LIBRARIES := boringssl_crypto
include \$(PREBUILT_STATIC_LIBRARY)
EOF

# Shell configuration helper
cat > "$OUTPUT_DIR/setup_env.sh" << EOF
#!/bin/bash
# BoringSSL Environment Setup for curl build

BORINGSSL_ROOT=\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)

echo "=== BoringSSL Multi-ABI Configuration ==="
echo "Root: \$BORINGSSL_ROOT"
echo "Include: \$BORINGSSL_ROOT/include"
echo "Available ABIs: x86 x86_64 armeabi-v7a arm64-v8a"
echo ""
echo "For curl build, set these variables:"
echo "export BORINGSSL_ROOT=\$BORINGSSL_ROOT"
echo "export BORINGSSL_INCLUDE=\$BORINGSSL_ROOT/include"
echo "export CPPFLAGS=\"-I\$BORINGSSL_INCLUDE\""
echo ""
echo "For specific ABI (example arm64-v8a):"
echo "export BORINGSSL_CRYPTO_LIB=\$BORINGSSL_ROOT/lib/arm64-v8a/libcrypto.a"
echo "export BORINGSSL_SSL_LIB=\$BORINGSSL_ROOT/lib/arm64-v8a/libssl.a"
echo "export LDFLAGS=\"-L\$BORINGSSL_ROOT/lib/arm64-v8a\""
echo "export LIBS=\"-lssl -lcrypto\""
EOF
chmod +x "$OUTPUT_DIR/setup_env.sh"

# Create README
cat > "$OUTPUT_DIR/README.md" << EOF
# BoringSSL Multi-ABI Android Build

This directory contains BoringSSL static libraries built for multiple Android ABIs.

## Structure
\`\`\`
android-build/
├── include/           # Shared header files
├── lib/
│   ├── x86/          # x86 libraries
│   ├── x86_64/       # x86_64 libraries
│   ├── armeabi-v7a/  # ARM 32-bit libraries
│   └── arm64-v8a/    # ARM 64-bit libraries
├── BoringSSLConfig.cmake  # CMake integration
├── Android.mk        # Android.mk integration
└── setup_env.sh      # Environment setup
\`\`\`

## Usage

### CMake (Recommended)
\`\`\`cmake
find_package(BoringSSL REQUIRED)
target_link_libraries(your_target BoringSSL::SSL BoringSSL::Crypto)
\`\`\`

### Android.mk
\`\`\`make
include path/to/boringssl/Android.mk
LOCAL_STATIC_LIBRARIES := boringssl_ssl boringssl_crypto
\`\`\`

### Manual Integration
\`\`\`bash
source setup_env.sh
# Follow the displayed instructions
\`\`\`

## Requirements
- Android API 23+ (Android 6.0+)
- Supported ABIs: x86, x86_64, armeabi-v7a, arm64-v8a
- NDK r21+ recommended

## Build Info
- Built with: Android NDK r28b
- Optimization: -O2 with size optimization
- Features: TLS 1.1, 1.2, 1.3 support
- Hardware acceleration: Enabled where available
EOF

echo -e "${GREEN}=== Integration Files Created ===${NC}"
echo "✓ BoringSSLConfig.cmake - CMake integration"
echo "✓ Android.mk - Android.mk integration"
echo "✓ setup_env.sh - Environment setup script"
echo "✓ README.md - Usage documentation"

# Final summary
echo -e "${GREEN}=== Multi-ABI Build Complete ===${NC}"
echo -e "${BLUE}Output directory:${NC} $OUTPUT_DIR"
echo -e "${BLUE}Successful ABIs:${NC} ${successful_abis[*]}"
echo -e "${BLUE}Android API level:${NC} $ANDROID_MIN_API (Android 6.0+)"
echo -e "${BLUE}Total library sets:${NC} ${#successful_abis[@]}"
echo ""
echo -e "${YELLOW}To use with curl:${NC}"
echo "1. cd $OUTPUT_DIR"
echo "2. source setup_env.sh"
echo "3. Follow the displayed instructions"
echo ""
echo -e "${GREEN}Ready for Android development!${NC}"

if [ ${#failed_abis[@]} -eq 0 ]; then
    exit 0
else
    exit 1
fi