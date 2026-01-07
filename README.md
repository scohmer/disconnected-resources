# Disconnected Resources Pipeline

A GitHub Actions-based CI/CD pipeline for automatically collecting and bundling software packages, container images, and development tools for air-gapped and disconnected environments.

## Overview

This solution automates the monthly collection of resources from various package ecosystems, creating a single tarball that can be easily transferred to disconnected networks. Perfect for:

- Air-gapped environments
- Offline development labs
- Secure networks without internet access
- Disaster recovery scenarios
- Bandwidth-constrained locations

## Features

- **Automated Collection**: Runs monthly or on-demand via GitHub Actions
- **Multiple Package Sources**:
  - npm (Node.js packages)
  - PyPI (Python packages)
  - Debian/Ubuntu packages (.deb)
  - RPM packages (RHEL/CentOS/Fedora)
  - Container images (Docker/OCI)
  - VSCode extensions
- **Configurable**: Simple YAML configuration file
- **Dependency Resolution**: Automatically includes package dependencies
- **Secure**: Generates checksums for integrity verification
- **Compressed**: Creates optimized tarballs with optional splitting
- **Well-Documented**: Each component includes detailed installation guides

## Quick Start

### 1. Fork or Use This Repository

Click "Use this template" or fork this repository to your GitHub account.

### 2. Customize Your Configuration

Edit `resources-config.yaml` to specify your packages:

```yaml
metadata:
  environment_name: "my-airgap-env"
  description: "Monthly resource bundle"

npm:
  enabled: true
  packages:
    - name: "express"
      version: "latest"
    - name: "react"
      version: "18.2.0"

pypi:
  enabled: true
  packages:
    - name: "requests"
      version: "latest"
    - name: "flask"
      version: "2.3.0"

# See resources-config.yaml for full configuration options
```

### 3. Enable GitHub Actions

1. Go to your repository on GitHub
2. Navigate to **Actions** tab
3. Enable workflows if prompted
4. The workflow will run:
   - Monthly on the 1st at 2 AM UTC
   - When `resources-config.yaml` is modified
   - Manually via "Run workflow" button

### 4. Download Your Bundle

After the workflow completes:

1. Go to the **Actions** tab
2. Click on the latest workflow run
3. Scroll to **Artifacts** section
4. Download the `resources-bundle-*` artifact
5. Extract and verify checksums:
   ```bash
   tar -xzf resources-bundle-*.tar.gz
   cd bundle-staging/
   cat BUNDLE_INFO.txt
   ```

## Repository Structure

```
disconnected-resources/
├── .github/
│   └── workflows/
│       └── generate-resources.yml    # Main GitHub Actions workflow
├── scripts/
│   ├── parse_config.py              # Configuration parser
│   ├── collect_npm.sh               # NPM collector
│   ├── collect_pypi.sh              # PyPI collector
│   ├── collect_debian.sh            # Debian collector
│   ├── collect_rpm.sh               # RPM collector
│   ├── collect_containers.sh        # Container collector
│   ├── collect_vscode.sh            # VSCode collector
│   └── create_bundle.sh             # Bundle creator
├── resources-config.yaml            # Configuration file (customize this!)
├── README.md                        # This file
└── SETUP.md                         # Detailed setup guide
```

## Configuration Guide

### Basic Configuration

The `resources-config.yaml` file controls what gets collected. Key sections:

#### Metadata
```yaml
metadata:
  environment_name: "production-airgap"
  description: "Monthly resource bundle"
  contact: "your-team@example.com"
```

#### NPM Packages
```yaml
npm:
  enabled: true
  include_dependencies: true
  packages:
    - name: "express"
      version: "4.18.0"  # or "latest"
```

#### Python Packages
```yaml
pypi:
  enabled: true
  include_dependencies: true
  python_versions:
    - "3.9"
    - "3.10"
    - "3.11"
  platforms:
    - "manylinux2014_x86_64"
  packages:
    - name: "requests"
      version: "latest"
```

#### Container Images
```yaml
containers:
  enabled: true
  export_format: "docker-archive"
  images:
    - image: "docker.io/library/nginx"
      tag: "1.25-alpine"
```

See `SETUP.md` for complete configuration documentation.

## Usage

### Manual Workflow Trigger

1. Go to **Actions** tab
2. Select "Generate Disconnected Resources Bundle"
3. Click **Run workflow**
4. Optional: specify a custom config file name
5. Click **Run workflow** button

### Scheduled Execution

By default, the workflow runs monthly on the 1st at 2 AM UTC. To change the schedule:

Edit `.github/workflows/generate-resources.yml`:
```yaml
schedule:
  - cron: '0 2 1 * *'  # Monthly on 1st
  # Change to:
  # - cron: '0 2 * * 1'    # Weekly on Mondays
  # - cron: '0 2 1,15 * *' # Twice monthly
```

### Automatic Trigger on Config Changes

The workflow automatically runs when you push changes to `resources-config.yaml`:

```bash
# Edit configuration
vim resources-config.yaml

# Commit and push
git add resources-config.yaml
git commit -m "Update package list"
git push
```

## Deployment to Disconnected Environment

### 1. Transfer the Bundle

Use your organization's approved transfer method:

- **USB Drive**: Copy to encrypted USB drive
- **Secure File Transfer**: If a secure connection exists
- **Physical Media**: Burn to DVD/Blu-ray
- **Secure Courier**: Physical delivery

```bash
# Example: Copy to USB
cp resources-bundle-*.tar.gz /media/usb/

# Verify checksum
sha256sum -c resources-bundle-*.tar.gz.sha256
```

### 2. Extract on Disconnected System

```bash
# Extract bundle
tar -xzf resources-bundle-*.tar.gz
cd bundle-staging/

# Review contents
cat BUNDLE_INFO.txt
ls -la
```

### 3. Install Resources

Each directory contains a README with installation instructions:

```bash
# Install system packages
cd debian/  # or rpm/
cat README.md
# Follow instructions

# Load container images
cd ../containers/
cat README.md
# Follow instructions

# Install Python packages
cd ../pypi/
cat README.md
# Follow instructions

# Install npm packages
cd ../npm/
cat README.md
# Follow instructions

# Install VSCode extensions
cd ../vscode/
cat README.md
# Follow instructions
```

## Advanced Features

### Private Packages

#### Private npm packages

Add NPM token to repository secrets:
1. Go to Settings → Secrets → Actions
2. Add secret: `NPM_TOKEN`
3. Modify workflow or scripts to use token

#### Private container registries

Add Docker credentials to repository secrets:
1. Add secrets: `DOCKER_USERNAME` and `DOCKER_PASSWORD`
2. Workflow will automatically authenticate

### Multiple Environments

Create different config files:

```
resources-config-prod.yaml
resources-config-dev.yaml
resources-config-test.yaml
```

Run workflow with specific config:
1. Actions → Run workflow
2. Enter config file name
3. Run workflow

### Custom Bundle Naming

Use the workflow input to add custom suffix:
1. Actions → Run workflow
2. Enter custom name (e.g., "quarterly-update")
3. Result: `resources-bundle-quarterly-update-20240315-120000`

## Troubleshooting

### Workflow Fails

**Check the logs:**
1. Go to Actions tab
2. Click on failed run
3. Expand failed step
4. Review error messages

**Common issues:**
- Package name typo: Verify package names
- Version not found: Check if version exists
- Rate limiting: Add delays or retry logic
- Permission issues: Check secrets configuration

### Large Bundle Size

If bundle exceeds GitHub artifact limits (10 GB):

1. Enable splitting in config:
   ```yaml
   output:
     split_size: "2G"
   ```

2. Or split packages into multiple configs

3. Use higher compression:
   ```yaml
   output:
     compression: "xz"
   ```

### Missing Dependencies

If dependencies are missing:

1. Ensure `include_dependencies: true` in config
2. Some packages have peer dependencies not auto-resolved
3. Check component-specific README for manual dependencies

## Best Practices

1. **Pin Versions**: Use specific versions for production:
   ```yaml
   version: "1.2.3"  # Instead of "latest"
   ```

2. **Test First**: Always test bundles in non-production environment

3. **Regular Updates**: Run monthly to get security updates

4. **Version Control**: Track changes to `resources-config.yaml`

5. **Document Changes**: Maintain changelog of what changed

6. **Backup Bundles**: Keep previous bundles for rollback

7. **Verify Checksums**: Always verify after transfer

8. **Monitor Size**: Watch bundle sizes and optimize

## Security Considerations

1. **Checksum Verification**: Always verify checksums after transfer
   ```bash
   sha256sum -c resources-bundle-*.sha256
   ```

2. **Scan Packages**: Consider vulnerability scanning before deployment

3. **Access Control**: Secure the GitHub repository with appropriate permissions

4. **Audit Trail**: GitHub Actions provides audit logs

5. **Secrets Management**: Use GitHub Secrets for credentials

6. **Review Contents**: Inspect package lists before production use

## Resource Requirements

### GitHub Actions Runner

The workflow requires:
- Ubuntu-latest runner (provided by GitHub)
- ~2-4 GB RAM
- ~10-20 GB disk space (varies with bundle size)
- 2-hour timeout (configurable)

### Disconnected System

Requirements vary by components:
- Sufficient disk space (see bundle BUNDLE_INFO.txt)
- Compatible OS (for .deb/.rpm packages)
- Container runtime (for container images)
- Node.js (for npm packages)
- Python (for PyPI packages)
- VSCode (for extensions)

## Contributing

Improvements are welcome! To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Documentation

- **README.md** (this file): Overview and quick start
- **SETUP.md**: Detailed setup and configuration guide
- **Component READMEs**: Installation guides in each bundle directory

## Support

For issues or questions:

1. Check **SETUP.md** for detailed documentation
2. Review component-specific READMEs in bundle
3. Check GitHub Actions logs for workflow issues
4. Open a GitHub issue with details

## License

[Specify your license here]

## Changelog

### Version 1.0.0 (Initial Release)

- GitHub Actions workflow for automated collection
- NPM package collection with dependencies
- PyPI package collection with multi-version support
- Debian/Ubuntu package collection
- RPM package collection (RHEL/CentOS/Fedora)
- Container image export (Docker/OCI)
- VSCode extension collection
- Configurable YAML-based configuration
- Automated bundle creation with checksums
- Comprehensive documentation

---

**Built for secure, disconnected environments.** Generate once, deploy anywhere offline.
