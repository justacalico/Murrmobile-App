#!/usr/bin/env bash
set -euo pipefail

VERSION="$1"

if [[ -z "$VERSION" ]]; then
  echo "Error: version is required" >&2
  exit 1
fi

# Update pubspec.yaml version and increment the build number
build=1
if grep -q '^version: .*+' pubspec.yaml; then
  build=$(grep '^version: ' pubspec.yaml | sed 's/.*+//')
  build=$((build + 1))
fi
sed -i "s/^version: .*/version: ${VERSION}+${build}/" pubspec.yaml

if ! grep -q "^version: ${VERSION}+" pubspec.yaml; then
  echo "Error: pubspec.yaml version not updated" >&2
  exit 1
fi
