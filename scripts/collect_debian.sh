#!/bin/bash
set -euo pipefail

# Debian/Ubuntu Package Collector for Disconnected Environments
# Downloads deb packages and their dependencies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON="${1:-config.json}"
OUTPUT_DIR="${2:-output/debian}"

echo "=== Debian/Ubuntu Package Collector ==="
echo "Config: $CONFIG_JSON"
echo "Output: $OUTPUT_DIR"

# Check if debian is enabled
DEBIAN_ENABLED=$(jq -r '.debian.enabled // false' "$CONFIG_JSON")
if [ "$DEBIAN_ENABLED" != "true" ]; then
    echo "Debian collection is disabled in config"
    exit 0
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Parse configuration
DISTRIBUTION=$(jq -r '.debian.distribution // "ubuntu"' "$CONFIG_JSON")
RELEASE=$(jq -r '.debian.release // "22.04"' "$CONFIG_JSON")
INCLUDE_DEPS=$(jq -r '.debian.include_dependencies // true' "$CONFIG_JSON")
ARCHITECTURES=$(jq -r '.debian.architectures[]? // "amd64"' "$CONFIG_JSON" | tr '\n' ' ')
PACKAGES=$(jq -r '.debian.packages[]' "$CONFIG_JSON")

echo "Distribution: $DISTRIBUTION"
echo "Release: $RELEASE"
echo "Architectures: $ARCHITECTURES"
echo "Include dependencies: $INCLUDE_DEPS"
echo ""

# Create packages directory
mkdir -p packages

# Initialize package list
> packages.txt

# Download packages using apt-get (in download-only mode)
echo "Updating package index..."
echo "Note: This requires running on a Debian/Ubuntu system or in a container"
echo ""

# For each architecture
for arch in $ARCHITECTURES; do
    echo "Processing architecture: $arch"
    ARCH_DIR="packages/$arch"
    mkdir -p "$ARCH_DIR"

    for pkg in $PACKAGES; do
        echo "  Downloading: $pkg"

        if [ "$INCLUDE_DEPS" = "true" ]; then
            # Download package with dependencies
            apt-get download "$pkg" 2>/dev/null && mv *.deb "$ARCH_DIR/" 2>/dev/null || {
                echo "  Warning: Failed to download $pkg for $arch"
                continue
            }

            # Get dependencies
            DEPS=$(apt-cache depends "$pkg" | grep "Depends:" | awk '{print $2}' | grep -v "<" || true)
            for dep in $DEPS; do
                echo "    Dependency: $dep"
                apt-get download "$dep" 2>/dev/null && mv *.deb "$ARCH_DIR/" 2>/dev/null || echo "    Warning: Failed to download dependency $dep"
            done
        else
            # Download package only
            apt-get download "$pkg" 2>/dev/null && mv *.deb "$ARCH_DIR/" 2>/dev/null || {
                echo "  Warning: Failed to download $pkg for $arch"
                continue
            }
        fi

        # Record package
        echo "$pkg" >> packages.txt
    done
    echo ""
done

# Remove duplicate entries in packages.txt
sort -u packages.txt -o packages.txt

# Count downloaded packages
PACKAGE_COUNT=$(find packages -name "*.deb" 2>/dev/null | wc -l)
echo "Downloaded $PACKAGE_COUNT .deb packages"

# Create package index for each architecture
for arch in $ARCHITECTURES; do
    ARCH_DIR="packages/$arch"
    if [ -d "$ARCH_DIR" ]; then
        cd "$ARCH_DIR"
        dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz 2>/dev/null || \
            echo "Note: dpkg-scanpackages not available, skipping index generation"
        cd "$OUTPUT_DIR"
    fi
done

# Generate README for deployment
cat > README.md << 'EOF'
# Debian/Ubuntu Packages for Disconnected Environment

This directory contains Debian/Ubuntu packages (.deb files) and their dependencies for offline installation.

## Contents

- `packages/<arch>/` - DEB packages organized by architecture
- `packages.txt` - List of requested packages
- `README.md` - This file

## Installation Methods

### Method 1: Direct installation with dpkg

Install individual packages:

```bash
sudo dpkg -i packages/amd64/package-name*.deb
```

Install all packages:
```bash
sudo dpkg -i packages/amd64/*.deb
```

Fix broken dependencies (if any):
```bash
sudo apt-get install -f
```

### Method 2: Using apt with local repository

1. Copy packages to a local directory:
```bash
sudo mkdir -p /var/local-repo
sudo cp -r packages/amd64/*.deb /var/local-repo/
```

2. Create package index:
```bash
cd /var/local-repo
dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
```

3. Add to apt sources:
```bash
echo "deb [trusted=yes] file:/var/local-repo ./" | sudo tee /etc/apt/sources.list.d/local.list
```

4. Update and install:
```bash
sudo apt-get update
sudo apt-get install package-name
```

### Method 3: Using gdebi (handles dependencies)

Install gdebi if available:
```bash
sudo apt-get install gdebi-core
```

Install packages:
```bash
sudo gdebi packages/amd64/package-name*.deb
```

### Method 4: Batch installation script

Create an installation script:

```bash
#!/bin/bash
# install_all.sh

set -e

ARCH="amd64"  # Change to your architecture
PACKAGE_DIR="packages/$ARCH"

echo "Installing packages from $PACKAGE_DIR"

# Install packages in order (may need multiple passes for dependencies)
for pass in {1..3}; do
  echo "Installation pass $pass..."
  for deb in $PACKAGE_DIR/*.deb; do
    sudo dpkg -i "$deb" 2>/dev/null || true
  done
  sudo apt-get install -f -y 2>/dev/null || true
done

echo "Installation complete!"
```

Run the script:
```bash
chmod +x install_all.sh
sudo ./install_all.sh
```

## Architecture-Specific Installation

Ensure you install packages for your system architecture:

```bash
# Check your architecture
dpkg --print-architecture

# Install for specific architecture
sudo dpkg -i packages/amd64/*.deb
```

## Handling Dependencies

Dependencies are included if configured during download. However, you may encounter:

### Missing dependencies
```bash
sudo apt-get install -f
```

### Dependency conflicts
- Install packages in a specific order
- Use `--force-depends` (use with caution)
- Resolve conflicts manually

## Verifying Packages

List downloaded packages:
```bash
ls -lh packages/amd64/
```

Check package info:
```bash
dpkg-deb -I packages/amd64/package-name.deb
```

List package contents:
```bash
dpkg-deb -c packages/amd64/package-name.deb
```

Verify package integrity:
```bash
dpkg-deb --validate packages/amd64/package-name.deb
```

## Setting Up Local Repository

For a proper local repository:

1. Create repository structure:
```bash
sudo mkdir -p /var/local-apt-repo/dists/stable/main/binary-amd64
sudo cp packages/amd64/*.deb /var/local-apt-repo/dists/stable/main/binary-amd64/
```

2. Generate Packages file:
```bash
cd /var/local-apt-repo
dpkg-scanpackages dists/stable/main/binary-amd64 | gzip > dists/stable/main/binary-amd64/Packages.gz
```

3. Create Release file:
```bash
cat > dists/stable/Release << 'RELEASE'
Origin: Local Repository
Label: Local Repository
Suite: stable
Codename: stable
Architectures: amd64
Components: main
Description: Local APT Repository
RELEASE
```

4. Add to sources.list:
```bash
echo "deb [trusted=yes] file:/var/local-apt-repo stable main" | sudo tee /etc/apt/sources.list.d/local.list
sudo apt-get update
```

## Troubleshooting

### Issue: Package conflicts
**Solution**:
- Check for conflicting packages: `dpkg -l | grep package-name`
- Remove conflicts before installing: `sudo apt-get remove conflicting-package`

### Issue: Unmet dependencies
**Solution**:
- Ensure all dependencies are downloaded
- Run: `sudo apt-get install -f`
- Install dependencies manually

### Issue: Architecture mismatch
**Solution**:
- Verify architecture: `dpkg --print-architecture`
- Download packages for correct architecture
- Use multi-arch if needed: `sudo dpkg --add-architecture i386`

### Issue: Package already installed
**Solution**:
- Reinstall: `sudo dpkg -i --force-reinstall package.deb`
- Or remove first: `sudo dpkg -r package-name`

## Best Practices

1. **Test in non-production first**: Always test package installation in a test environment

2. **Verify checksums**: Use SHA256 checksums to verify package integrity

3. **Document versions**: Keep track of installed package versions

4. **Backup**: Create system backup before major package installations

5. **Order matters**: Install base packages first, then applications

## Package List

See `packages.txt` for the list of packages in this bundle.

## System Requirements

- Debian-based Linux distribution (Debian, Ubuntu, etc.)
- Matching distribution version and architecture
- Sufficient disk space for packages

## Support

For package-specific issues, refer to Debian/Ubuntu documentation or package maintainer documentation.
EOF

echo "Debian collection complete!"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Note: This script works best when run on a Debian/Ubuntu system."
echo "For other systems, consider using a Docker container:"
echo "  docker run --rm -v \$(pwd):/output ubuntu:22.04 bash /output/scripts/collect_debian.sh"
