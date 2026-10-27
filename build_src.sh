#!/bin/bash
set -euo pipefail

tree_sitter_cli_VERSION=$1
BUILD_VERSION=$2

if [ -z "$tree_sitter_cli_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <tree_sitter_cli_version> <build_version>"
    echo "Example: $0 0.27.0 1"
    exit 1
fi

PACKAGE_NAME="tree-sitter-cli"
ORIG_TARBALL="${PACKAGE_NAME}_${tree_sitter_cli_VERSION}.orig.tar.gz"
BUILD_DIR="${PACKAGE_NAME}-${tree_sitter_cli_VERSION}"

echo "Creating the source package for tree-sitter-cli ${tree_sitter_cli_VERSION}-${BUILD_VERSION}..."

# A rebuild of an upstream version already released here (a +N build bump)
# must ship the very same orig tarball: the pool holds one per upstream
# version and reprepro refuses a different one, and nothing guarantees the
# archive download is byte-identical next time. Reuse the earlier release's copy.
if [ ! -f "$ORIG_TARBALL" ]; then
    for ((b = BUILD_VERSION - 1; b >= 1; b--)); do
        if wget -q "https://github.com/gaofengnan/tree-sitter-cli-debian/releases/download/${tree_sitter_cli_VERSION}%2B${b}/${ORIG_TARBALL}" -O "$ORIG_TARBALL"; then
            echo "  Reusing $ORIG_TARBALL from release ${tree_sitter_cli_VERSION}+${b}"
            break
        fi
        rm -f "$ORIG_TARBALL"
    done
fi

# Download upstream source tarball (shared .orig.tar.gz across all distributions).
# Upstream tags carry a "v" prefix, which GitHub strips from the archive's top
# level directory. The archive is used byte-for-byte with no repacking; it
# extracts as tree-sitter-<version>/ (the upstream project name), which is
# renamed to the package's BUILD_DIR below.
UPSTREAM_DIR="tree-sitter-${tree_sitter_cli_VERSION}"
if [ ! -f "$ORIG_TARBALL" ]; then
    echo "Downloading upstream source from GitHub..."
    wget -q "https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v${tree_sitter_cli_VERSION}.tar.gz" -O "$ORIG_TARBALL"
    echo "  Downloaded $ORIG_TARBALL"
else
    echo "  Using existing $ORIG_TARBALL"
fi

build_source_package() {
    local FULL_VERSION="${tree_sitter_cli_VERSION}-${BUILD_VERSION}~gaofn"

    echo "  Building source package ${FULL_VERSION}..."

    # Clean and recreate build directory from orig tarball
    rm -rf "$BUILD_DIR" "$UPSTREAM_DIR"
    tar -xf "$ORIG_TARBALL"
    mv "$UPSTREAM_DIR" "$BUILD_DIR"

    # Copy Debian packaging directory
    cp -r debian "$BUILD_DIR/"

    # Generate the changelog (overwrites placeholder)
    cat > "$BUILD_DIR/debian/changelog" << EOC
tree-sitter-cli (${FULL_VERSION}) stable; urgency=medium

  * New upstream release ${tree_sitter_cli_VERSION}.

 -- Fengnan Gao <gao.fengnan@gmail.com>  $(date -R)
EOC

    # Build source package (.dsc + .debian.tar.xz); reuses existing .orig.tar.gz
    dpkg-source -b "$BUILD_DIR"

    rm -rf "$BUILD_DIR"
    echo "    ${FULL_VERSION}"
}

echo ""
# One source package for every suite, as with the binaries (see build_debian.sh).
build_source_package

echo ""
echo "Source packages created successfully!"
echo ""
echo "Generated files:"
ls -la "${PACKAGE_NAME}_"*.dsc "${PACKAGE_NAME}_"*.orig.tar.gz "${PACKAGE_NAME}_"*.debian.tar.xz 2>/dev/null || true
