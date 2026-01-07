#!/bin/bash
set -euo pipefail

# Bundle Creator for Disconnected Resources
# Creates compressed tarball with all collected resources

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON="${1:-config.json}"
OUTPUT_BASE_DIR="${2:-output}"

echo "=== Bundle Creator ==="
echo "Config: $CONFIG_JSON"
echo "Output directory: $OUTPUT_BASE_DIR"
echo ""

# Parse output configuration
TARBALL_NAME=$(jq -r '.output.tarball_name // "resources-bundle"' "$CONFIG_JSON")
COMPRESSION=$(jq -r '.output.compression // "gzip"' "$CONFIG_JSON")
SPLIT_SIZE=$(jq -r '.output.split_size // "0"' "$CONFIG_JSON")

# Parse security configuration
GENERATE_CHECKSUMS=$(jq -r '.security.generate_checksums // true' "$CONFIG_JSON")
CHECKSUM_ALGORITHM=$(jq -r '.security.checksum_algorithm // "sha256"' "$CONFIG_JSON")

# Parse metadata
ENV_NAME=$(jq -r '.metadata.environment_name // "default"' "$CONFIG_JSON")
ENV_DESC=$(jq -r '.metadata.description // ""' "$CONFIG_JSON")

echo "Bundle name: $TARBALL_NAME"
echo "Compression: $COMPRESSION"
echo "Split size: $SPLIT_SIZE"
echo "Generate checksums: $GENERATE_CHECKSUMS"
echo "Checksum algorithm: $CHECKSUM_ALGORITHM"
echo ""

# Create timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BUNDLE_NAME="${TARBALL_NAME}-${TIMESTAMP}"

# Create staging directory
STAGING_DIR="$OUTPUT_BASE_DIR/bundle-staging"
mkdir -p "$STAGING_DIR"

echo "Creating bundle staging area: $STAGING_DIR"

# Copy collected resources to staging
for source in npm pypi debian rpm containers vscode; do
    SOURCE_DIR="$OUTPUT_BASE_DIR/$source"
    if [ -d "$SOURCE_DIR" ]; then
        echo "  Including: $source"
        cp -r "$SOURCE_DIR" "$STAGING_DIR/"
    fi
done

# Create bundle metadata file
cat > "$STAGING_DIR/BUNDLE_INFO.txt" << EOF
Disconnected Resources Bundle
=============================

Bundle Name: $BUNDLE_NAME
Environment: $ENV_NAME
Description: $ENV_DESC
Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Created By: Disconnected Resources Pipeline

Contents:
EOF

# List contents
for source in npm pypi debian rpm containers vscode; do
    if [ -d "$STAGING_DIR/$source" ]; then
        echo "  - $source: $(du -sh "$STAGING_DIR/$source" | cut -f1)" >> "$STAGING_DIR/BUNDLE_INFO.txt"
    fi
done

echo "" >> "$STAGING_DIR/BUNDLE_INFO.txt"
echo "Installation Instructions:" >> "$STAGING_DIR/BUNDLE_INFO.txt"
echo "See README.md files in each directory for detailed installation instructions." >> "$STAGING_DIR/BUNDLE_INFO.txt"

# Create main README for the bundle
cat > "$STAGING_DIR/README.md" << 'EOF'
# Disconnected Resources Bundle

This bundle contains packages and resources for offline/air-gapped environments.

## Contents

This bundle may include:
- **npm/** - Node.js packages
- **pypi/** - Python packages
- **debian/** - Debian/Ubuntu packages
- **rpm/** - RHEL/CentOS/Fedora packages
- **containers/** - Container images
- **vscode/** - VSCode extensions

See `BUNDLE_INFO.txt` for details about this specific bundle.

## Quick Start

1. **Extract the bundle**:
   ```bash
   tar -xzf resources-bundle-*.tar.gz
   cd bundle-staging/
   ```

2. **Review contents**:
   ```bash
   cat BUNDLE_INFO.txt
   ls -la
   ```

3. **Install resources**:
   Navigate to each directory and follow the README.md instructions:
   ```bash
   cd npm/
   cat README.md
   ```

## Installation Order Recommendation

For a fresh system, install in this order:

1. **System packages** (debian/ or rpm/)
   - Base utilities and dependencies
   - Required system libraries

2. **Container images** (containers/)
   - If using containerized applications

3. **Python packages** (pypi/)
   - Python dependencies and tools

4. **Node.js packages** (npm/)
   - JavaScript/Node.js dependencies

5. **VSCode extensions** (vscode/)
   - Development tools

## Directory Structure

```
bundle-staging/
├── BUNDLE_INFO.txt       # Bundle metadata
├── README.md             # This file
├── npm/                  # Node.js packages
│   ├── README.md
│   └── packages/
├── pypi/                 # Python packages
│   ├── README.md
│   └── packages/
├── debian/               # Debian packages
│   ├── README.md
│   └── packages/
├── rpm/                  # RPM packages
│   ├── README.md
│   └── packages/
├── containers/           # Container images
│   ├── README.md
│   └── images/
└── vscode/               # VSCode extensions
    ├── README.md
    └── extensions/
```

## Verification

### Check bundle integrity (if checksums provided)

```bash
# SHA256
sha256sum -c checksums.sha256

# SHA512
sha512sum -c checksums.sha512

# MD5
md5sum -c checksums.md5
```

### Check disk space requirements

```bash
du -sh bundle-staging/
```

Individual component sizes:
```bash
du -sh bundle-staging/*/
```

## System Requirements

- Sufficient disk space (see BUNDLE_INFO.txt)
- Appropriate OS for package types (Debian/Ubuntu for .deb, RHEL/CentOS for .rpm)
- Container runtime for container images (Docker, Podman, etc.)
- Node.js for npm packages
- Python for PyPI packages
- VSCode for extensions

## Installation Scripts

Each component directory contains detailed installation instructions in its README.md file.

## Troubleshooting

### Issue: Insufficient disk space
- Check available space: `df -h`
- Install components selectively
- Clean up after each component installation

### Issue: Permission denied
- Use `sudo` for system package installations
- Check file permissions: `ls -la`

### Issue: Checksum mismatch
- File may be corrupted during transfer
- Verify transfer method
- Re-transfer the bundle

### Issue: Missing dependencies
- Ensure dependencies were included during bundle creation
- Check component README files for manual dependency lists
- Some peer dependencies may need separate installation

## Best Practices

1. **Verify checksums** after transferring to disconnected environment
2. **Test in non-production** environment first
3. **Backup system** before major installations
4. **Document** what you install and versions
5. **Keep bundle archive** for future reference or rollback

## Support

- Review individual README.md files in each component directory
- Check BUNDLE_INFO.txt for bundle-specific information
- Refer to official documentation for each package/tool

## Security Notes

1. **Verify bundle integrity** using checksums
2. **Scan for vulnerabilities** if tools are available
3. **Review package contents** before installation
4. **Use secure transfer** methods (encrypted USB, secure copy, etc.)
5. **Audit installations** after deployment

## Updates

To update resources in your disconnected environment:

1. Generate a new bundle with updated packages
2. Transfer new bundle to disconnected environment
3. Extract and compare with previous versions
4. Install updated packages following component READMEs
5. Keep previous bundles for rollback capability

## Reporting Issues

If you encounter issues:
1. Check component-specific README.md files
2. Verify system requirements
3. Check log files if available
4. Document error messages for troubleshooting

---

For more information, see individual component README files.
EOF

echo "Staging complete. Bundle size: $(du -sh "$STAGING_DIR" | cut -f1)"
echo ""

# Create tarball
cd "$OUTPUT_BASE_DIR"
TARBALL_FILE="${BUNDLE_NAME}.tar"

echo "Creating tarball: $TARBALL_FILE"

tar -cf "$TARBALL_FILE" bundle-staging/

# Apply compression
case "$COMPRESSION" in
    gzip)
        echo "Compressing with gzip..."
        gzip -f "$TARBALL_FILE"
        FINAL_FILE="${TARBALL_FILE}.gz"
        ;;
    bzip2)
        echo "Compressing with bzip2..."
        bzip2 -f "$TARBALL_FILE"
        FINAL_FILE="${TARBALL_FILE}.bz2"
        ;;
    xz)
        echo "Compressing with xz..."
        xz -f "$TARBALL_FILE"
        FINAL_FILE="${TARBALL_FILE}.xz"
        ;;
    none)
        echo "No compression applied"
        FINAL_FILE="$TARBALL_FILE"
        ;;
    *)
        echo "Unknown compression: $COMPRESSION, using gzip"
        gzip -f "$TARBALL_FILE"
        FINAL_FILE="${TARBALL_FILE}.gz"
        ;;
esac

echo "Bundle created: $FINAL_FILE"
echo "Size: $(du -sh "$FINAL_FILE" | cut -f1)"

# Generate checksums
if [ "$GENERATE_CHECKSUMS" = "true" ]; then
    echo ""
    echo "Generating checksums..."

    case "$CHECKSUM_ALGORITHM" in
        sha256)
            sha256sum "$FINAL_FILE" > "${FINAL_FILE}.sha256"
            echo "SHA256: $(cat "${FINAL_FILE}.sha256")"
            ;;
        sha512)
            sha512sum "$FINAL_FILE" > "${FINAL_FILE}.sha512"
            echo "SHA512: $(cat "${FINAL_FILE}.sha512")"
            ;;
        md5)
            md5sum "$FINAL_FILE" > "${FINAL_FILE}.md5"
            echo "MD5: $(cat "${FINAL_FILE}.md5")"
            ;;
        *)
            echo "Unknown checksum algorithm: $CHECKSUM_ALGORITHM, using sha256"
            sha256sum "$FINAL_FILE" > "${FINAL_FILE}.sha256"
            echo "SHA256: $(cat "${FINAL_FILE}.sha256")"
            ;;
    esac
fi

# Handle splitting if requested
if [ "$SPLIT_SIZE" != "0" ] && [ "$SPLIT_SIZE" != "" ]; then
    echo ""
    echo "Splitting bundle into $SPLIT_SIZE chunks..."

    split -b "$SPLIT_SIZE" -d "$FINAL_FILE" "${FINAL_FILE}.part-"

    echo "Split files created:"
    ls -lh "${FINAL_FILE}.part-"*

    # Generate checksums for split files
    if [ "$GENERATE_CHECKSUMS" = "true" ]; then
        echo "Generating checksums for split files..."
        for part in "${FINAL_FILE}.part-"*; do
            case "$CHECKSUM_ALGORITHM" in
                sha256) sha256sum "$part" >> "${FINAL_FILE}.parts.sha256" ;;
                sha512) sha512sum "$part" >> "${FINAL_FILE}.parts.sha512" ;;
                md5) md5sum "$part" >> "${FINAL_FILE}.parts.md5" ;;
            esac
        done
    fi

    # Create reassembly instructions
    cat > "${BUNDLE_NAME}-reassemble.sh" << 'REASSEMBLE_EOF'
#!/bin/bash
# Reassemble split bundle parts

set -euo pipefail

echo "Reassembling bundle parts..."

# Find all part files
PARTS=(*.part-*)

if [ ${#PARTS[@]} -eq 0 ]; then
    echo "Error: No part files found"
    exit 1
fi

# Get base name from first part
BASE_NAME="${PARTS[0]%.part-*}"

echo "Base name: $BASE_NAME"
echo "Parts found: ${#PARTS[@]}"

# Reassemble
cat "${BASE_NAME}.part-"* > "$BASE_NAME"

echo "Reassembly complete: $BASE_NAME"
echo "Verifying checksums if available..."

# Verify checksum
if [ -f "${BASE_NAME}.sha256" ]; then
    sha256sum -c "${BASE_NAME}.sha256"
elif [ -f "${BASE_NAME}.sha512" ]; then
    sha512sum -c "${BASE_NAME}.sha512"
elif [ -f "${BASE_NAME}.md5" ]; then
    md5sum -c "${BASE_NAME}.md5"
else
    echo "Warning: No checksum file found for verification"
fi

echo "Done! You can now extract: tar -xzf $BASE_NAME"
REASSEMBLE_EOF

    chmod +x "${BUNDLE_NAME}-reassemble.sh"
    echo "Reassembly script created: ${BUNDLE_NAME}-reassemble.sh"
fi

echo ""
echo "================================================"
echo "Bundle creation complete!"
echo "================================================"
echo "Bundle file: $OUTPUT_BASE_DIR/$FINAL_FILE"
if [ "$GENERATE_CHECKSUMS" = "true" ]; then
    echo "Checksum file: $OUTPUT_BASE_DIR/${FINAL_FILE}.${CHECKSUM_ALGORITHM}"
fi
if [ "$SPLIT_SIZE" != "0" ] && [ "$SPLIT_SIZE" != "" ]; then
    echo "Split files: $OUTPUT_BASE_DIR/${FINAL_FILE}.part-*"
    echo "Reassembly script: $OUTPUT_BASE_DIR/${BUNDLE_NAME}-reassemble.sh"
fi
echo ""
echo "Total size: $(du -sh "$FINAL_FILE" | cut -f1)"
echo ""
echo "To extract on disconnected system:"
echo "  tar -xzf $FINAL_FILE"
echo ""
