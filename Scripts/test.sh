#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/newfile-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
xcrun swiftc -swift-version 5 \
  "$PROJECT_ROOT/Sources/Shared/FileKind.swift" \
  "$PROJECT_ROOT/Sources/Shared/MenuBuilder.swift" \
  "$PROJECT_ROOT/Sources/Core/FileCreator.swift" \
  "$PROJECT_ROOT/Tests/main.swift" \
  -framework AppKit -o "$TEST_ROOT/verify"
"$TEST_ROOT/verify" "$PROJECT_ROOT/Resources/Templates" "$TEST_ROOT/files"
