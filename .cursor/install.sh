#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for Penny.
#
# Penny itself is a native iOS/SwiftUI app that can only be built and launched
# with Xcode on macOS. On the Linux Cloud Agent VM the runnable slice of the
# project is Tools/PennyCoreLogic: a Foundation-only mirror of the calculation
# layer (FinanceCalculator, InsightEngine, MoneyFormatters, DateHelpers) with
# Swift Testing suites. This script installs a Swift toolchain when one is not
# already present, then warms that package so `swift test` is ready to run.
set -euo pipefail

SWIFT_VERSION="6.0.3"
SWIFT_PREFIX="/opt/swift"
UBUNTU_RELEASE="ubuntu24.04"
SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-${UBUNTU_RELEASE}.tar.gz"

log() { printf '\n=== %s ===\n' "$1"; }

install_swift() {
  log "Installing Swift toolchain runtime dependencies"
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    binutils \
    libc6-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libgcc-13-dev \
    libncurses-dev \
    libpython3-dev \
    libstdc++-13-dev \
    libxml2-dev \
    libz3-dev \
    pkg-config \
    python3 \
    tzdata \
    zlib1g-dev

  log "Downloading Swift ${SWIFT_VERSION} (${UBUNTU_RELEASE})"
  local tarball
  tarball="$(mktemp /tmp/swift-XXXXXX.tar.gz)"
  curl -fsSL -o "${tarball}" "${SWIFT_URL}"

  log "Extracting Swift toolchain to ${SWIFT_PREFIX}"
  sudo rm -rf "${SWIFT_PREFIX}"
  sudo mkdir -p "${SWIFT_PREFIX}"
  sudo tar -xzf "${tarball}" -C "${SWIFT_PREFIX}" --strip-components=1
  rm -f "${tarball}"

  sudo ln -sf "${SWIFT_PREFIX}/usr/bin/swift" /usr/local/bin/swift
  sudo ln -sf "${SWIFT_PREFIX}/usr/bin/swiftc" /usr/local/bin/swiftc
}

if command -v swift >/dev/null 2>&1; then
  log "Swift already installed: $(swift --version 2>/dev/null | head -1)"
else
  install_swift
fi

log "Swift toolchain"
swift --version

log "Warming Tools/PennyCoreLogic package"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}/Tools/PennyCoreLogic"
swift build

log "Penny Cloud Agent environment ready"
