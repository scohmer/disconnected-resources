#!/bin/bash
set -euo pipefail

# PyPI Package Collector for Disconnected Environments
# Downloads Python packages and their dependencies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON="${1:-config.json}"
OUTPUT_DIR="${2:-output/pypi}"

echo "=== PyPI Package Collector ==="
echo "Config: $CONFIG_JSON"
echo "Output: $OUTPUT_DIR"

# Check if pypi is enabled
PYPI_ENABLED=$(jq -r '.pypi.enabled // false' "$CONFIG_JSON")
if [ "$PYPI_ENABLED" != "true" ]; then
    echo "PyPI collection is disabled in config"
    exit 0
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Parse configuration
INCLUDE_DEPS=$(jq -r '.pypi.include_dependencies // true' "$CONFIG_JSON")
PYTHON_VERSIONS=$(jq -r '.pypi.python_versions[]? // "3.11"' "$CONFIG_JSON" | tr '\n' ' ')
PLATFORMS=$(jq -r '.pypi.platforms[]? // "manylinux2014_x86_64"' "$CONFIG_JSON" | tr '\n' ' ')
PACKAGES=$(jq -c '.pypi.packages[]' "$CONFIG_JSON")

echo "Include dependencies: $INCLUDE_DEPS"
echo "Python versions: $PYTHON_VERSIONS"
echo "Platforms: $PLATFORMS"
echo ""

# Create packages directory
mkdir -p packages

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
        PKG_SPEC="$PKG_NAME==$PKG_VERSION"
    fi

    # Download for each Python version
    for py_ver in $PYTHON_VERSIONS; do
        echo "  Downloading for Python $py_ver..."

        # Build platform arguments
        PLATFORM_ARGS=""
        for platform in $PLATFORMS; do
            PLATFORM_ARGS="$PLATFORM_ARGS --platform $platform"
        done

        # Download package
        if [ "$INCLUDE_DEPS" = "true" ]; then
            pip download \
                --dest packages \
                --python-version "$py_ver" \
                $PLATFORM_ARGS \
                --no-deps \
                "$PKG_SPEC" 2>/dev/null || echo "  Warning: Failed to download $PKG_SPEC for Python $py_ver"

            # Download dependencies separately
            pip download \
                --dest packages \
                --python-version "$py_ver" \
                $PLATFORM_ARGS \
                "$PKG_SPEC" 2>/dev/null || echo "  Warning: Some dependencies may be missing"
        else
            pip download \
                --dest packages \
                --python-version "$py_ver" \
                $PLATFORM_ARGS \
                --no-deps \
                "$PKG_SPEC" 2>/dev/null || echo "  Warning: Failed to download $PKG_SPEC for Python $py_ver"
        fi
    done

    # Record package
    echo "$PKG_NAME@$PKG_VERSION" >> packages.txt
    echo "  Done"
    echo ""
done

# Remove duplicates
cd packages
ls -1 | sort -u > ../all_packages.txt
cd ..

# Count downloaded packages
PACKAGE_COUNT=$(ls -1 packages 2>/dev/null | wc -l)
echo "Downloaded $PACKAGE_COUNT package files"

# Generate simple index for pip (optional)
mkdir -p simple
cd packages
for wheel_or_tar in *; do
    # Extract package name (before version)
    pkg_base=$(echo "$wheel_or_tar" | sed -E 's/[-_]([0-9]+\..*)$//')
    pkg_name=$(echo "$pkg_base" | tr '_' '-' | tr '[:upper:]' '[:lower:]')

    mkdir -p "../simple/$pkg_name"
    ln -sf "../../packages/$wheel_or_tar" "../simple/$pkg_name/" 2>/dev/null || \
        cp "../../packages/$wheel_or_tar" "../simple/$pkg_name/" 2>/dev/null || true
done
cd ..

# Generate README for deployment
cat > README.md << 'EOF'
# PyPI Packages for Disconnected Environment

This directory contains Python packages and their dependencies for offline installation.

## Contents

- `packages/` - All downloaded wheel files and source distributions
- `simple/` - Simple package index structure for pip
- `packages.txt` - List of requested packages
- `all_packages.txt` - All downloaded packages (including dependencies)
- `README.md` - This file

## Installation Methods

### Method 1: Direct installation from directory

Install packages directly from the packages directory:

```bash
pip install --no-index --find-links=packages package-name
```

Example:
```bash
pip install --no-index --find-links=packages requests flask pandas
```

### Method 2: Using requirements file

If you have a requirements.txt:

```bash
pip install --no-index --find-links=packages -r requirements.txt
```

### Method 3: Setting up a local PyPI server

Install pypiserver (if available in your disconnected environment):

```bash
pip install pypiserver
```

Start the server:
```bash
pypi-server -p 8080 packages/
```

Configure pip to use local server:
```bash
pip install --index-url http://localhost:8080/simple/ package-name
```

Or add to pip.conf:
```ini
[global]
index-url = http://localhost:8080/simple/
```

### Method 4: Using pip with simple index

Use the simple directory as a local index:

```bash
pip install --index-url=file://$(pwd)/simple --no-deps package-name
```

### Method 5: Manual installation

Install a specific wheel file:

```bash
pip install packages/package_name-1.0.0-py3-none-any.whl
```

## Installing Multiple Packages

Create a script to install all packages:

```bash
#!/bin/bash
for wheel in packages/*.whl; do
  pip install --no-index --no-deps "$wheel" || echo "Failed: $wheel"
done
```

## Creating a Local Mirror

Copy the entire directory structure to your disconnected environment:

```bash
# On disconnected machine
pip install --no-index --find-links=/path/to/packages package-name
```

## Handling Platform-Specific Packages

Some packages are platform-specific:
- `manylinux*` - Linux wheels
- `win32` / `win_amd64` - Windows wheels
- `macosx*` - macOS wheels

Ensure you download packages for your target platform.

## Python Version Compatibility

Wheels are built for specific Python versions:
- `py3-none-any` - Pure Python, any version
- `cp311` - CPython 3.11
- `cp310` - CPython 3.10

Install packages matching your Python version.

## Verifying Packages

List all packages:
```bash
ls -lh packages/
```

Check package metadata:
```bash
unzip -l packages/package-name.whl
```

Verify installation:
```bash
pip list
```

## Troubleshooting

### Issue: Package not found
- Check the package exists in the `packages/` directory
- Verify you're using correct package name (case-insensitive, - or _)

### Issue: Platform incompatible
- Package may be for wrong platform
- Download packages for your specific platform
- Try installing source distribution (.tar.gz) instead

### Issue: Dependency conflicts
- Dependencies included at time of download
- May need to resolve conflicts manually
- Use `pip install --no-deps` to skip dependency checks

### Issue: Missing C dependencies
- Some packages require system libraries
- Install system dependencies separately (see debian/rpm directories)

## Package List

See `packages.txt` for requested packages and `all_packages.txt` for all downloaded packages including dependencies.

## Support

For package-specific issues, refer to the official PyPI documentation for each package.
EOF

echo "PyPI collection complete!"
echo "Output directory: $OUTPUT_DIR"
