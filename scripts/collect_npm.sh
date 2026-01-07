#!/bin/bash
set -euo pipefail

# NPM Package Collector for Disconnected Environments
# Downloads npm packages and their dependencies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON="${1:-config.json}"
OUTPUT_DIR="${2:-output/npm}"

echo "=== NPM Package Collector ==="
echo "Config: $CONFIG_JSON"
echo "Output: $OUTPUT_DIR"

# Check if npm is enabled
NPM_ENABLED=$(jq -r '.npm.enabled // false' "$CONFIG_JSON")
if [ "$NPM_ENABLED" != "true" ]; then
    echo "NPM collection is disabled in config"
    exit 0
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Parse configuration
INCLUDE_DEPS=$(jq -r '.npm.include_dependencies // true' "$CONFIG_JSON")
PACKAGES=$(jq -c '.npm.packages[]' "$CONFIG_JSON")

echo "Include dependencies: $INCLUDE_DEPS"
echo ""

# Initialize package list
> packages.txt

# Download packages
for pkg in $PACKAGES; do
    PKG_NAME=$(echo "$pkg" | jq -r '.name')
    PKG_VERSION=$(echo "$pkg" | jq -r '.version // "latest"')

    echo "Processing: $PKG_NAME@$PKG_VERSION"

    if [ "$PKG_VERSION" = "latest" ]; then
        PKG_SPEC="$PKG_NAME"
    else
        PKG_SPEC="$PKG_NAME@$PKG_VERSION"
    fi

    # Create package directory
    PKG_DIR="packages/$PKG_NAME"
    mkdir -p "$PKG_DIR"

    if [ "$INCLUDE_DEPS" = "true" ]; then
        echo "  Downloading package with dependencies..."

        # Create temp directory for this package
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"

        # Initialize package.json and install
        npm init -y > /dev/null 2>&1
        npm install --save "$PKG_SPEC" --legacy-peer-deps > /dev/null 2>&1 || {
            echo "  Warning: Failed to download $PKG_SPEC"
            cd "$OUTPUT_DIR"
            rm -rf "$TEMP_DIR"
            continue
        }

        # Pack all node_modules
        cd node_modules
        for module in */; do
            module_name="${module%/}"
            echo "  Packing: $module_name"
            npm pack "$module_name" > /dev/null 2>&1 || echo "  Warning: Failed to pack $module_name"
        done

        # Move tarballs to output
        mv *.tgz "$OUTPUT_DIR/$PKG_DIR/" 2>/dev/null || true

        # Cleanup
        cd "$OUTPUT_DIR"
        rm -rf "$TEMP_DIR"
    else
        echo "  Downloading package only (no dependencies)..."
        cd "$PKG_DIR"
        npm pack "$PKG_SPEC" > /dev/null 2>&1 || {
            echo "  Warning: Failed to download $PKG_SPEC"
            cd "$OUTPUT_DIR"
            continue
        }
        cd "$OUTPUT_DIR"
    fi

    # Record package
    echo "$PKG_NAME@$PKG_VERSION" >> packages.txt
    echo "  Done"
    echo ""
done

# Count downloaded packages
TARBALL_COUNT=$(find packages -name "*.tgz" 2>/dev/null | wc -l)
echo "Downloaded $TARBALL_COUNT package tarballs"

# Generate README for deployment
cat > README.md << 'EOF'
# NPM Packages for Disconnected Environment

This directory contains npm packages and their dependencies for offline installation.

## Contents

- `packages/` - Directory containing all npm package tarballs
- `packages.txt` - List of requested packages
- `README.md` - This file

## Installation Methods

### Method 1: Using npm install with local tarballs

For each package you need, install from the tarball:

```bash
npm install /path/to/packages/package-name/*.tgz
```

### Method 2: Setting up a local npm registry

1. Install Verdaccio (if not already in disconnected environment):
```bash
npm install -g verdaccio
```

2. Start Verdaccio:
```bash
verdaccio
```

3. Configure npm to use local registry:
```bash
npm set registry http://localhost:4873
```

4. Publish all packages to local registry:
```bash
for tarball in packages/*/*.tgz; do
  npm publish "$tarball" --registry http://localhost:4873
done
```

5. Now you can install packages normally:
```bash
npm install express
npm install react
```

### Method 3: Direct file installation

Copy packages to your project and install directly:

```bash
# In your project directory
npm install file:/path/to/packages/express/express-*.tgz
```

### Method 4: Manual node_modules setup

For a specific project:

1. Create a node_modules directory in your project
2. Extract each tarball into node_modules:
```bash
cd your-project
mkdir -p node_modules
cd node_modules
for tarball in /path/to/packages/*/*.tgz; do
  tar -xzf "$tarball"
  # npm tarballs extract to 'package' directory, need to rename
  if [ -d "package" ]; then
    pkg_name=$(node -p "require('./package/package.json').name")
    mv package "$pkg_name"
  fi
done
```

## Verifying Packages

List all downloaded packages:
```bash
ls -R packages/
```

Check package contents:
```bash
tar -tzf packages/package-name/package-name-*.tgz
```

## Troubleshooting

### Issue: Package not found
- Verify the tarball exists in the packages directory
- Check the tarball is not corrupted: `tar -tzf package.tgz`

### Issue: Dependency conflicts
- This bundle includes all dependencies at time of download
- Peer dependencies may need manual resolution
- Use `npm install --legacy-peer-deps` if needed

### Issue: Platform-specific packages
- Some packages have native bindings
- Ensure packages were downloaded for correct platform
- May need to rebuild: `npm rebuild`

## Package List

See `packages.txt` for the list of requested packages.

## Support

For issues with specific packages, refer to their official documentation.
EOF

echo "NPM collection complete!"
echo "Output directory: $OUTPUT_DIR"
