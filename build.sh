#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== AppCloner Build Tool ===${NC}"

# Check for required tools
for tool in clang swiftc lipo codesign hdiutil xcrun; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}Error: Required tool '$tool' is not installed or not in PATH.${NC}"
        exit 1
    fi
done

# Set up paths
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_DIR="${BUILD_DIR}/AppCloner.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MAC_OS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
DMG_PATH="${PROJECT_DIR}/AppCloner.dmg"

echo -e "Project directory: ${GREEN}${PROJECT_DIR}${NC}"
echo -e "Build directory:   ${GREEN}${BUILD_DIR}${NC}"

# Clean existing build files
echo -e "${YELLOW}Cleaning previous build artifacts...${NC}"
rm -rf "${BUILD_DIR}"
rm -f "${DMG_PATH}"

# Recreate folder structure
mkdir -p "${MAC_OS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 1. Compile libredirect.dylib (Universal Binary)
echo -e "${YELLOW}Compiling libredirect.dylib (Universal Binary: arm64 + x86_64)...${NC}"
clang -dynamiclib -arch arm64 -arch x86_64 \
    -o "${RESOURCES_DIR}/libredirect.dylib" \
    "${PROJECT_DIR}/libredirect.m" \
    -framework Foundation

# Verify dylib
if [ ! -f "${RESOURCES_DIR}/libredirect.dylib" ]; then
    echo -e "${RED}Error: Failed to compile libredirect.dylib.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ libredirect.dylib compiled successfully.${NC}"
file "${RESOURCES_DIR}/libredirect.dylib"

# 2. Compile AppCloner Swift application for arm64
echo -e "${YELLOW}Compiling AppCloner Swift Application (arm64)...${NC}"
SDK_PATH=$(xcrun --show-sdk-path)
swiftc -O -sdk "${SDK_PATH}" \
    -target arm64-apple-macos13.0 \
    -parse-as-library \
    "${PROJECT_DIR}/AppCloner.swift" \
    -o "${BUILD_DIR}/AppCloner_arm64"

# 3. Compile AppCloner Swift application for x86_64
echo -e "${YELLOW}Compiling AppCloner Swift Application (x86_64)...${NC}"
swiftc -O -sdk "${SDK_PATH}" \
    -target x86_64-apple-macos13.0 \
    -parse-as-library \
    "${PROJECT_DIR}/AppCloner.swift" \
    -o "${BUILD_DIR}/AppCloner_x86_64"

# 4. Merge Swift binaries into a Universal Binary using lipo
echo -e "${YELLOW}Merging architectures into universal binary...${NC}"
lipo -create "${BUILD_DIR}/AppCloner_arm64" "${BUILD_DIR}/AppCloner_x86_64" \
    -output "${MAC_OS_DIR}/AppCloner"

# Clean temporary binaries
rm "${BUILD_DIR}/AppCloner_arm64" "${BUILD_DIR}/AppCloner_x86_64"

# Verify app binary
if [ ! -f "${MAC_OS_DIR}/AppCloner" ]; then
    echo -e "${RED}Error: Failed to generate AppCloner binary.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AppCloner application binary compiled successfully.${NC}"
file "${MAC_OS_DIR}/AppCloner"

# 5. Copy resources
echo -e "${YELLOW}Adding bundle metadata and resources...${NC}"
if [ -f "${PROJECT_DIR}/Info.plist" ]; then
    cp "${PROJECT_DIR}/Info.plist" "${CONTENTS_DIR}/"
else
    echo -e "${RED}Error: Info.plist template missing in project directory!${NC}"
    exit 1
fi

if [ -f "${PROJECT_DIR}/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/AppIcon.icns" "${RESOURCES_DIR}/"
else
    echo -e "${YELLOW}Warning: AppIcon.icns missing, application will use default system icon.${NC}"
fi

# 6. Ad-hoc codesign the entire bundle recursively
echo -e "${YELLOW}Codesigning AppCloner.app recursively (ad-hoc)...${NC}"
codesign --force --deep --sign - "${APP_DIR}"
echo -e "${GREEN}✓ Codesigning complete.${NC}"

# 7. Package as a DMG Installer
echo -e "${YELLOW}Packaging into DMG installer...${NC}"
hdiutil create -volname "AppCloner" -srcfolder "${APP_DIR}" -ov -format UDZO "${DMG_PATH}"

if [ -f "${DMG_PATH}" ]; then
    echo -e "${GREEN}=== Build Success ===${NC}"
    echo -e "Packaged DMG location: ${GREEN}${DMG_PATH}${NC}"
    echo -e "Executable App bundle: ${GREEN}${APP_DIR}${NC}"
    
    # Proactively copy DMG to parent directory if needed
    cp "${DMG_PATH}" "${PROJECT_DIR}/../AppCloner.dmg"
    echo -e "Copied DMG to:         ${GREEN}${PROJECT_DIR}/../AppCloner.dmg${NC}"
else
    echo -e "${RED}Error: DMG packaging failed.${NC}"
    exit 1
fi
