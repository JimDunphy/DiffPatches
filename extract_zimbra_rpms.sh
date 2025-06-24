#!/bin/bash
set -euo pipefail

#
# Author: 6/24/2025 - JDunphy
#
# Purpose:
#   This script downloads and extracts the latest versions of selected Zimbra RPMs
#   to enable offline inspection of file contents and installation scripts.
#   This is especially useful when deciding whether to apply patches revealed
#   by 'dnf update' or defer them for scheduled maintenance.
#
# Usage:
#   1. Identify relevant Zimbra RPMs listed in the 'dnf update' output.
#   2. Add those package names to the PACKAGES array below.
#   3. Run this script to download, extract, and log script and build metadata.
#
# Summary:
#   - WORKDIR: The working directory used to download and extract RPMs.
#              Defaults to ~/zimbra_rpms with a subdirectory 'extracted'.
#   - RPMs:    Downloaded with all dependencies via `dnf download --resolve`
#   - Extracted Files:
#       * Extracted contents of each RPM go to WORKDIR/extracted/{rpm-name}
#       * install_scripts.txt contains post/pre install/remove scriptlets
#       * Build timestamp and metadata printed per RPM
#
# Requirements:
#   - rpm2cpio and cpio must be installed
#   - sudo privileges are needed for dnf operations
#
# Example Packages:
#   zimbra-mbox-admin-console-war
#   zimbra-mbox-webclient-war
#   zimbra-patch


PACKAGES=(
  zimbra-mbox-admin-console-war
  zimbra-mbox-webclient-war
  zimbra-patch
)

WORKDIR=~/zimbra_rpms
mkdir -p "$WORKDIR/extracted"
cd "$WORKDIR" || exit 1

echo "🧹 Cleaning up previous RPMs..."
rm -f "$WORKDIR"/*.rpm

echo "🔄 Cleaning and refreshing DNF metadata..."
sudo dnf clean all
sudo dnf makecache --refresh

echo "📥 Downloading latest RPM packages..."
sudo dnf download --resolve --downloaddir="$WORKDIR" "${PACKAGES[@]}"

echo "📦 Extracting RPMs..."
for rpm in "$WORKDIR"/*.rpm; do
  name="${rpm##*/}"
  name="${name%%.rpm}"
  target_dir="$WORKDIR/extracted/$name"
  mkdir -p "$target_dir"

  echo "📂 Extracting $name to $target_dir"
  rpm2cpio "$rpm" | (cd "$target_dir" && cpio -idmv)

  echo "📄 Scripts in $name:"
  rpm -q --scripts -p "$rpm" > "$target_dir/install_scripts.txt"

  echo "🧾 Build info: $(rpm -qp --qf '%{name}-%{version}-%{release}.%{arch} :: %{buildtime:date}\n' "$rpm")"
done

