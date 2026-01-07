#!/bin/bash
set -euo pipefail

# RPM Package Collector for Disconnected Environments
# Downloads RPM packages and their dependencies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON="${1:-config.json}"
OUTPUT_DIR="${2:-output/rpm}"

echo "=== RPM Package Collector ==="
echo "Config: $CONFIG_JSON"
echo "Output: $OUTPUT_DIR"

# Check if rpm collection is enabled
RPM_ENABLED=$(jq -r '.rpm.enabled // false' "$CONFIG_JSON")
if [ "$RPM_ENABLED" != "true" ]; then
    echo "RPM collection is disabled in config"
    exit 0
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Parse configuration
DISTRIBUTION=$(jq -r '.rpm.distribution // "rhel"' "$CONFIG_JSON")
RELEASE=$(jq -r '.rpm.release // "9"' "$CONFIG_JSON")
INCLUDE_DEPS=$(jq -r '.rpm.include_dependencies // true' "$CONFIG_JSON")
ARCHITECTURES=$(jq -r '.rpm.architectures[]? // "x86_64"' "$CONFIG_JSON" | tr '\n' ' ')
PACKAGES=$(jq -r '.rpm.packages[]' "$CONFIG_JSON")

echo "Distribution: $DISTRIBUTION"
echo "Release: $RELEASE"
echo "Architectures: $ARCHITECTURES"
echo "Include dependencies: $INCLUDE_DEPS"
echo ""

# Create packages directory
mkdir -p packages

# Initialize package list
> packages.txt

# Detect available package manager
if command -v dnf &> /dev/null; then
    PKG_MGR="dnf"
elif command -v yum &> /dev/null; then
    PKG_MGR="yum"
else
    echo "Error: Neither dnf nor yum found. RPM collection requires RHEL-based system."
    echo "Consider using a container: docker run --rm -v \$(pwd):/output rockylinux:9 bash /output/scripts/collect_rpm.sh"
    exit 1
fi

echo "Using package manager: $PKG_MGR"
echo ""

# Download packages
for pkg in $PACKAGES; do
    echo "Downloading: $pkg"

    if [ "$INCLUDE_DEPS" = "true" ]; then
        # Download with dependencies using downloadonly plugin
        $PKG_MGR install --downloadonly --downloaddir=packages "$pkg" -y 2>/dev/null || {
            echo "  Warning: Failed to download $pkg"
            continue
        }
    else
        # Download package only
        $PKG_MGR download --downloaddir=packages "$pkg" 2>/dev/null || {
            echo "  Warning: Failed to download $pkg"
            continue
        }
    fi

    # Record package
    echo "$pkg" >> packages.txt
    echo "  Done"
done

echo ""

# Remove duplicate entries in packages.txt
sort -u packages.txt -o packages.txt

# Count downloaded packages
PACKAGE_COUNT=$(find packages -name "*.rpm" 2>/dev/null | wc -l)
echo "Downloaded $PACKAGE_COUNT RPM packages"

# Create repository metadata
echo "Creating repository metadata..."
if command -v createrepo &> /dev/null || command -v createrepo_c &> /dev/null; then
    if command -v createrepo_c &> /dev/null; then
        createrepo_c packages/ 2>/dev/null || echo "Warning: Failed to create repo metadata"
    else
        createrepo packages/ 2>/dev/null || echo "Warning: Failed to create repo metadata"
    fi
    echo "Repository metadata created"
else
    echo "Note: createrepo not available, skipping metadata generation"
    echo "Install with: yum install createrepo_c"
fi

# Generate README for deployment
cat > README.md << 'EOF'
# RPM Packages for Disconnected Environment

This directory contains RPM packages and their dependencies for offline installation on RHEL-based systems.

## Contents

- `packages/` - All RPM packages
- `packages/repodata/` - Repository metadata (if generated)
- `packages.txt` - List of requested packages
- `README.md` - This file

## Installation Methods

### Method 1: Direct installation with rpm

Install individual packages:

```bash
sudo rpm -ivh packages/package-name*.rpm
```

Install all packages:
```bash
sudo rpm -ivh packages/*.rpm
```

Update existing packages:
```bash
sudo rpm -Uvh packages/*.rpm
```

### Method 2: Using yum/dnf with local repository

1. Copy packages to a local directory:
```bash
sudo mkdir -p /var/local-repo
sudo cp -r packages/*.rpm /var/local-repo/
```

2. Create repository metadata:
```bash
sudo createrepo /var/local-repo
```

3. Create repo file:
```bash
cat << 'REPO' | sudo tee /etc/yum.repos.d/local.repo
[local]
name=Local Repository
baseurl=file:///var/local-repo
enabled=1
gpgcheck=0
REPO
```

4. Clear cache and install:
```bash
sudo yum clean all
sudo yum install package-name
```

### Method 3: Using dnf with local directory

Install from directory directly:

```bash
sudo dnf install packages/*.rpm
```

### Method 4: Batch installation script

Create an installation script:

```bash
#!/bin/bash
# install_all_rpm.sh

set -e

PACKAGE_DIR="packages"

echo "Installing RPM packages from $PACKAGE_DIR"

# Install all packages
sudo rpm -Uvh --replacepkgs $PACKAGE_DIR/*.rpm 2>&1 | tee install.log

# Check for failures
if grep -q "error" install.log; then
  echo "Some packages failed to install. Check install.log"
  exit 1
fi

echo "Installation complete!"
```

Run the script:
```bash
chmod +x install_all_rpm.sh
sudo ./install_all_rpm.sh
```

## Handling Dependencies

### Automatic dependency resolution

Using yum/dnf with local repo (Method 2) will automatically resolve dependencies.

### Manual dependency installation

If using rpm directly and encountering dependency errors:

```bash
# List dependencies
rpm -qpR packages/package-name.rpm

# Install dependencies first, then the package
sudo rpm -ivh packages/dependency1.rpm packages/dependency2.rpm
sudo rpm -ivh packages/package-name.rpm
```

### Force installation (use with caution)

```bash
sudo rpm -ivh --nodeps packages/package-name.rpm
```

## Verifying Packages

List downloaded packages:
```bash
ls -lh packages/
```

Check package info:
```bash
rpm -qip packages/package-name.rpm
```

List package contents:
```bash
rpm -qlp packages/package-name.rpm
```

Verify package signature (if signed):
```bash
rpm -K packages/package-name.rpm
```

Check package dependencies:
```bash
rpm -qpR packages/package-name.rpm
```

## Setting Up Local Repository Server

For network-accessible local repository:

1. Install httpd:
```bash
sudo yum install httpd
```

2. Copy packages:
```bash
sudo mkdir -p /var/www/html/repo
sudo cp -r packages/*.rpm /var/www/html/repo/
sudo createrepo /var/www/html/repo
```

3. Start httpd:
```bash
sudo systemctl start httpd
sudo systemctl enable httpd
```

4. On client machines:
```bash
cat << 'REPO' | sudo tee /etc/yum.repos.d/local-network.repo
[local-network]
name=Local Network Repository
baseurl=http://your-server-ip/repo
enabled=1
gpgcheck=0
REPO
```

## Architecture Compatibility

Ensure packages match your system architecture:

```bash
# Check your architecture
uname -m

# Install architecture-specific packages
sudo rpm -ivh packages/*x86_64.rpm
```

Common architectures:
- `x86_64` - 64-bit Intel/AMD
- `aarch64` - 64-bit ARM
- `noarch` - Architecture-independent

## Troubleshooting

### Issue: Dependency conflicts
**Solution**:
```bash
# Use yum/dnf to resolve
sudo yum localinstall packages/*.rpm

# Or check conflicts
rpm -qp --conflicts packages/package.rpm
```

### Issue: Package already installed
**Solution**:
```bash
# Update instead
sudo rpm -Uvh packages/package.rpm

# Or force reinstall
sudo rpm -ivh --replacepkgs packages/package.rpm
```

### Issue: File conflicts
**Solution**:
```bash
# Check which package owns the file
rpm -qf /path/to/conflicting/file

# Force installation (caution)
sudo rpm -ivh --replacefiles packages/package.rpm
```

### Issue: Missing GPG keys
**Solution**:
```bash
# Import GPG key if available
sudo rpm --import /path/to/RPM-GPG-KEY

# Or skip check (not recommended for production)
sudo rpm -ivh --nosignature packages/package.rpm
```

### Issue: Transaction test errors
**Solution**:
```bash
# Get detailed error info
sudo rpm -ivh -vv packages/package.rpm

# Check disk space
df -h
```

## Best Practices

1. **Verify checksums**: Always verify package integrity after transfer

2. **Test first**: Test installations in non-production environment

3. **Document versions**: Keep record of installed package versions
   ```bash
   rpm -qa > installed-packages.txt
   ```

4. **Backup**: Create system backup before major package installations

5. **Use transactions**: When possible, use yum/dnf for atomic operations

6. **Keep metadata**: Don't delete repodata for easier updates

## Updating Packages

To update packages later:

1. Download new versions using this script
2. Copy new RPMs to your local repo
3. Recreate metadata:
   ```bash
   sudo createrepo --update /var/local-repo
   ```
4. Update packages:
   ```bash
   sudo yum update
   ```

## Package List

See `packages.txt` for the list of packages in this bundle.

## System Requirements

- RHEL-based Linux distribution (RHEL, CentOS, Rocky Linux, AlmaLinux, Fedora)
- Matching distribution version and architecture
- Sufficient disk space for packages

## Support

For package-specific issues, refer to RHEL documentation or package maintainer documentation.
EOF

echo "RPM collection complete!"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Note: This script works best when run on a RHEL-based system."
echo "For other systems, consider using a Docker container:"
echo "  docker run --rm -v \$(pwd):/output rockylinux:9 bash /output/scripts/collect_rpm.sh"
