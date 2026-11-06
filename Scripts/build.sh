#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${1:-$PROJECT_ROOT/build}"
APP="$BUILD_ROOT/随手新建.app"
EXTENSION="$APP/Contents/PlugIns/NewFileFinder.appex"
SIGN_IDENTITY="${NEWFILE_SIGN_IDENTITY:--}"

if [ -e "$APP" ]; then
  echo "构建目标已存在，请指定一个空的输出目录：$APP" >&2
  exit 1
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Templates" "$EXTENSION/Contents/MacOS"
cp "$PROJECT_ROOT/Configuration/App.plist" "$APP/Contents/Info.plist"
cp "$PROJECT_ROOT/Configuration/Extension.plist" "$EXTENSION/Contents/Info.plist"
cp "$PROJECT_ROOT/Resources/Templates/"* "$APP/Contents/Resources/Templates/"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
COMMON=(-sdk "$SDK_PATH" -target "$ARCH-apple-macosx13.0" -O -swift-version 5)
xcrun swiftc "${COMMON[@]}" -module-name NewFile \
  "$PROJECT_ROOT/Sources/Shared/FileKind.swift" \
  "$PROJECT_ROOT/Sources/Core/FileCreator.swift" \
  "$PROJECT_ROOT/Sources/Application/FinderSelection.swift" \
  "$PROJECT_ROOT/Sources/Application/FinderRename.swift" \
  "$PROJECT_ROOT/Sources/Application/main.swift" \
  -framework AppKit -framework FinderSync -o "$APP/Contents/MacOS/NewFile"

xcrun swiftc "${COMMON[@]}" -module-name NewFileFinder \
  "$PROJECT_ROOT/Sources/Shared/FileKind.swift" \
  "$PROJECT_ROOT/Sources/Shared/MenuBuilder.swift" \
  "$PROJECT_ROOT/Sources/FinderExtension/FinderSync.swift" \
  "$PROJECT_ROOT/Sources/FinderExtension/main.swift" \
  -framework AppKit -framework FinderSync -o "$EXTENSION/Contents/MacOS/NewFileFinder"

codesign --force --sign "$SIGN_IDENTITY" --entitlements "$PROJECT_ROOT/Configuration/Extension.entitlements" "$EXTENSION"
codesign --force --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "构建完成：$APP"
