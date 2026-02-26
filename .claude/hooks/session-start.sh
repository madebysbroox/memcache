#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Install Swift toolchain for syntax checking
if ! command -v swift &> /dev/null; then
  echo "Installing Swift toolchain..."
  apt-get update -qq
  apt-get install -y -qq binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 \
    libgcc-13-dev libpython3-dev libsqlite3-0 libstdc++-13-dev libxml2-dev libncurses5-dev \
    libz3-dev pkg-config tzdata unzip zlib1g-dev curl > /dev/null 2>&1

  SWIFT_URL="https://download.swift.org/swift-6.0.3-release/ubuntu2404/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu24.04.tar.gz"
  curl -fsSL "$SWIFT_URL" -o /tmp/swift.tar.gz
  tar -xzf /tmp/swift.tar.gz -C /usr/local --strip-components=2
  rm /tmp/swift.tar.gz
  echo "Swift installed: $(swift --version 2>&1 | head -1)"
fi

# Install SwiftLint for linting
if ! command -v swiftlint &> /dev/null; then
  echo "Installing SwiftLint..."
  SWIFTLINT_URL="https://github.com/realm/SwiftLint/releases/download/0.57.1/swiftlint_linux.zip"
  curl -fsSL "$SWIFTLINT_URL" -o /tmp/swiftlint.zip
  unzip -o /tmp/swiftlint.zip -d /usr/local/bin/ > /dev/null 2>&1
  chmod +x /usr/local/bin/swiftlint
  rm /tmp/swiftlint.zip
  echo "SwiftLint installed: $(swiftlint version 2>&1)"
fi

echo "Session setup complete."
