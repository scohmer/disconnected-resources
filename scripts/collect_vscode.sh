#!/bin/bash
set -euo pipefail

# VSCode Extensions Collector for Disconnected Environments
# Downloads VSCode extensions as VSIX files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON="${1:-config.json}"
OUTPUT_DIR="${2:-output/vscode}"

echo "=== VSCode Extensions Collector ==="
echo "Config: $CONFIG_JSON"
echo "Output: $OUTPUT_DIR"

# Check if vscode collection is enabled
VSCODE_ENABLED=$(jq -r '.vscode.enabled // false' "$CONFIG_JSON")
if [ "$VSCODE_ENABLED" != "true" ]; then
    echo "VSCode collection is disabled in config"
    exit 0
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Parse configuration
EXTENSIONS=$(jq -r '.vscode.extensions[]' "$CONFIG_JSON")

echo "Downloading VSCode extensions..."
echo ""

# Create extensions directory
mkdir -p extensions

# Initialize extension list
> extensions.txt

# VSCode Marketplace API base URL
MARKETPLACE_URL="https://marketplace.visualstudio.com/_apis/public/gallery/publishers"

# Function to download extension
download_extension() {
    local ext_id="$1"
    local publisher="${ext_id%%.*}"
    local extension="${ext_id#*.}"

    echo "Processing: $ext_id"

    # Download using VSCode marketplace URL pattern
    # Format: https://marketplace.visualstudio.com/_apis/public/gallery/publishers/{publisher}/vsextensions/{extension}/latest/vspackage

    local download_url="${MARKETPLACE_URL}/${publisher}/vsextensions/${extension}/latest/vspackage"
    local output_file="extensions/${publisher}.${extension}.vsix"

    echo "  Downloading from marketplace..."
    if curl -L -f -o "$output_file" "$download_url" 2>/dev/null; then
        echo "  Success: $output_file"
        echo "$ext_id" >> extensions.txt

        # Get version info from VSIX
        if command -v unzip &> /dev/null; then
            VERSION=$(unzip -p "$output_file" extension.vsixmanifest 2>/dev/null | grep -oP '(?<=Version=")[^"]*' | head -1 || echo "unknown")
            echo "  Version: $VERSION"
        fi
    else
        echo "  Warning: Failed to download $ext_id"
        rm -f "$output_file"
    fi

    echo ""
}

# Download each extension
for ext in $EXTENSIONS; do
    download_extension "$ext"
done

# Count downloaded extensions
EXT_COUNT=$(ls -1 extensions/*.vsix 2>/dev/null | wc -l || echo "0")
echo "Downloaded $EXT_COUNT VSCode extensions"

# Generate extension metadata
echo "Generating metadata..."
> extension_metadata.txt
for ext_file in extensions/*.vsix; do
    if [ -f "$ext_file" ]; then
        SIZE=$(du -h "$ext_file" | cut -f1)
        BASENAME=$(basename "$ext_file")
        echo "$BASENAME: $SIZE" >> extension_metadata.txt
    fi
done

# Generate README for deployment
cat > README.md << 'EOF'
# VSCode Extensions for Disconnected Environment

This directory contains VSCode extensions (VSIX files) for offline installation.

## Contents

- `extensions/` - VSIX extension files
- `extensions.txt` - List of extensions in this bundle
- `extension_metadata.txt` - Extension sizes
- `README.md` - This file

## Installation Methods

### Method 1: Install via VSCode UI

1. Open VSCode
2. Click on Extensions icon (or press Ctrl+Shift+X)
3. Click on the "..." menu (top-right of Extensions panel)
4. Select "Install from VSIX..."
5. Navigate to and select the .vsix file
6. Restart VSCode if prompted

### Method 2: Install via Command Line

Install a single extension:
```bash
code --install-extension extensions/publisher.extension.vsix
```

Install all extensions:
```bash
for vsix in extensions/*.vsix; do
  echo "Installing $(basename $vsix)..."
  code --install-extension "$vsix"
done
```

### Method 3: Install via CLI with script

Create an installation script:

```bash
#!/bin/bash
# install_vscode_extensions.sh

set -e

EXTENSIONS_DIR="extensions"

echo "Installing VSCode extensions..."

for vsix in $EXTENSIONS_DIR/*.vsix; do
  if [ -f "$vsix" ]; then
    echo "Installing: $(basename $vsix)"
    code --install-extension "$vsix" --force
  fi
done

echo "Installation complete!"
echo ""
echo "Installed extensions:"
code --list-extensions
```

Run the script:
```bash
chmod +x install_vscode_extensions.sh
./install_vscode_extensions.sh
```

### Method 4: Manual Installation

1. Locate VSCode extensions directory:
   - **Linux/Mac**: `~/.vscode/extensions/`
   - **Windows**: `%USERPROFILE%\.vscode\extensions\`

2. Extract VSIX file (it's a ZIP archive):
   ```bash
   unzip publisher.extension.vsix -d ~/.vscode/extensions/publisher.extension-version/
   ```

3. Restart VSCode

### Method 5: VSCode Server (Code-Server)

For code-server installations:
```bash
code-server --install-extension extensions/publisher.extension.vsix
```

## Verifying Installations

List installed extensions:
```bash
code --list-extensions
```

Check extension details:
```bash
code --list-extensions --show-versions
```

Verify extension is working:
1. Open VSCode
2. Go to Extensions panel
3. Look for the extension in the installed list

## Setting Up Local Extension Gallery (Advanced)

For organizations that need a private extension marketplace:

### Using simple HTTP server

1. Create a simple extension gallery:
```bash
mkdir -p /var/www/vscode-extensions
cp extensions/*.vsix /var/www/vscode-extensions/
cd /var/www/vscode-extensions
python3 -m http.server 8080
```

2. Configure VSCode to use local gallery (product.json):
```json
{
  "extensionsGallery": {
    "serviceUrl": "http://localhost:8080"
  }
}
```

### Using VS Code Marketplace (open-vsx)

For a full marketplace experience, consider setting up OpenVSX Registry in your environment.

## Batch Operations

### Install extensions for multiple users

```bash
#!/bin/bash
# Install for all users

for user_home in /home/*; do
  if [ -d "$user_home" ]; then
    username=$(basename "$user_home")
    echo "Installing for user: $username"

    for vsix in extensions/*.vsix; do
      sudo -u "$username" code --install-extension "$vsix"
    done
  fi
done
```

### Install in Remote SSH environments

```bash
# Install extensions for Remote-SSH
code --install-extension extensions/publisher.extension.vsix --remote ssh-remote-name
```

## Extension Dependencies

Some extensions depend on others. Install in order:
1. Language support extensions first (e.g., ms-python.python)
2. Tool extensions next (e.g., linters, formatters)
3. Theme and UI extensions last

## Troubleshooting

### Issue: Extension fails to install
**Solution**:
```bash
# Check VSCode version compatibility
code --version

# Try force installation
code --install-extension extension.vsix --force

# Check extension logs
# Open VSCode -> Help -> Toggle Developer Tools -> Console
```

### Issue: Extension not working
**Solution**:
- Restart VSCode
- Check extension dependencies are installed
- Verify extension is enabled (Extensions panel)
- Check extension host logs (Help -> Toggle Developer Tools)

### Issue: Incompatible VSCode version
**Solution**:
- Check extension requirements
- Download compatible extension version
- Update VSCode if possible

### Issue: Extension conflicts
**Solution**:
- Disable conflicting extensions
- Check extensions that modify similar settings
- Review extension documentation

### Issue: Cannot find extension after installation
**Solution**:
```bash
# Verify installation
code --list-extensions | grep extension-name

# Reinstall
code --uninstall-extension publisher.extension
code --install-extension extension.vsix
```

### Issue: Permission denied
**Solution**:
```bash
# Fix permissions on extensions directory
chmod -R 755 ~/.vscode/extensions

# Or run with appropriate permissions
sudo code --install-extension extension.vsix --user-data-dir /home/user/.vscode
```

## Best Practices

1. **Test Extensions**: Test each extension in non-production VSCode first

2. **Document Dependencies**: Keep track of extension dependencies
   ```bash
   code --list-extensions > installed-extensions.txt
   ```

3. **Version Control**: Keep VSIX files for version rollback

4. **Regular Updates**: Update extension bundle monthly

5. **Selective Installation**: Don't install all extensions for all users

6. **Backup Settings**: Backup VSCode settings along with extensions
   ```bash
   cp ~/.config/Code/User/settings.json ~/backup/
   ```

7. **Check Compatibility**: Verify extensions work with your VSCode version

## Extension Updates

To update extensions in disconnected environment:

1. Download new versions using this script
2. Uninstall old versions:
   ```bash
   code --uninstall-extension publisher.extension
   ```
3. Install new versions:
   ```bash
   code --install-extension new-version.vsix
   ```

## Portable VSCode Setup

Create a portable VSCode with pre-installed extensions:

1. Download VSCode portable
2. Install extensions in portable directory
3. Package entire directory
4. Deploy to disconnected machines

## Extension List

See `extensions.txt` for the complete list of extensions in this bundle.

See `extension_metadata.txt` for extension sizes.

## System Requirements

- Visual Studio Code installed
- Sufficient disk space for extensions
- Compatible VSCode version for each extension

## Support

For extension-specific issues:
- Check extension documentation on VSCode Marketplace
- Review extension README in the Extensions panel
- Check extension's GitHub repository (if available)

## Useful Commands

```bash
# List all installed extensions
code --list-extensions

# Uninstall extension
code --uninstall-extension publisher.extension

# Disable extension
code --disable-extension publisher.extension

# Enable extension
code --enable-extension publisher.extension

# Show extension info
code --show-versions publisher.extension
```
EOF

echo "VSCode collection complete!"
echo "Output directory: $OUTPUT_DIR"
