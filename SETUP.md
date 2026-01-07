# Disconnected Resources Pipeline - Setup Guide

This repository provides a GitHub Actions CI/CD pipeline for collecting packages and resources for air-gapped/disconnected environments.

## Features

- **Automated Monthly Collection**: Runs on the 1st of each month
- **Multiple Package Sources**: npm, PyPI, Debian, RPM, Container images, VSCode extensions
- **Customizable Configuration**: Simple YAML file for specifying packages
- **Dependency Resolution**: Automatically includes dependencies
- **Compressed Bundles**: Creates compressed tarballs with checksums
- **Easy Distribution**: Ready-to-deploy bundles with installation guides

## Quick Start

### 1. Fork or Clone This Repository

```bash
git clone https://github.com/your-org/disconnected-resources-pipeline.git
cd disconnected-resources-pipeline
```

### 2. Customize Your Configuration

Edit `resources-config.yaml` to specify your packages:

```yaml
metadata:
  environment_name: "production-airgap"
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
```

### 3. Enable GitHub Actions

1. Go to your repository on GitHub
2. Click on "Actions" tab
3. Enable workflows if prompted
4. The pipeline will run:
   - Monthly on the 1st at 2 AM UTC
   - When you push changes to `resources-config.yaml`
   - Manually via "Run workflow" button

### 4. Download Your Bundle

After the workflow completes:
1. Go to the Actions tab
2. Click on the latest workflow run
3. Download the `resources-bundle-*` artifact
4. Extract and deploy to your disconnected environment

## Configuration Guide

### NPM Packages

```yaml
npm:
  enabled: true
  packages:
    - name: "package-name"
      version: "1.2.3"  # or "latest"
  include_dependencies: true  # Include all dependencies
```

### Python Packages

```yaml
pypi:
  enabled: true
  packages:
    - name: "package-name"
      version: "1.2.3"
  python_versions:
    - "3.9"
    - "3.10"
    - "3.11"
  platforms:
    - "manylinux"
    - "linux_x86_64"
```

### Debian Packages

```yaml
debian:
  enabled: true
  distribution: "ubuntu"  # or "debian"
  release: "22.04"        # Ubuntu version
  packages:
    - "curl"
    - "git"
  include_dependencies: true
```

### RPM Packages

```yaml
rpm:
  enabled: true
  distribution: "rhel"    # rhel, centos, fedora
  release: "9"
  packages:
    - "curl"
    - "git"
  include_dependencies: true
```

### Container Images

```yaml
containers:
  enabled: true
  images:
    - image: "docker.io/library/nginx"
      tag: "1.25-alpine"
    - image: "docker.io/library/python"
      tag: "3.11-slim"
  export_format: "docker-archive"  # or "oci-archive"
```

### VSCode Extensions

```yaml
vscode:
  enabled: true
  extensions:
    - "ms-python.python"
    - "golang.go"
    - "dbaeumer.vscode-eslint"
  version: "latest"
```

### Output Configuration

```yaml
output:
  tarball_name: "resources-bundle"
  compression: "gzip"    # gzip, bzip2, xz, none
  split_size: "4G"       # Split if larger (0 for no split)

security:
  generate_checksums: true
  checksum_algorithm: "sha256"  # sha256, sha512, md5
```

## Repository Structure

```
disconnected-resources-pipeline/
├── .github/
│   └── workflows/
│       └── generate-resources.yml    # Main workflow
├── scripts/
│   ├── parse_config.py              # Config parser
│   ├── collect_npm.sh               # NPM collector
│   ├── collect_pypi.sh              # PyPI collector
│   ├── collect_debian.sh            # Debian collector
│   ├── collect_rpm.sh               # RPM collector
│   ├── collect_containers.sh        # Container collector
│   ├── collect_vscode.sh            # VSCode collector
│   └── create_bundle.sh             # Bundle creator
├── resources-config.yaml            # User configuration
├── README.md                        # This file
└── SETUP.md                         # Setup guide
```

## Advanced Usage

### Multiple Configurations

You can create multiple config files for different environments:

```bash
resources-config-prod.yaml
resources-config-dev.yaml
resources-config-test.yaml
```

Run with specific config:
```bash
# Manually trigger with custom config
# Use workflow_dispatch with config_file input
```

### Scheduled Runs

The default schedule is monthly. To change:

```yaml
# In .github/workflows/generate-resources.yml
schedule:
  - cron: '0 2 1 * *'  # Monthly at 2 AM
  # Change to:
  - cron: '0 2 * * 1'  # Weekly on Mondays
  - cron: '0 2 1,15 * *'  # Twice monthly
```

### Manual Workflow Trigger

1. Go to Actions tab
2. Select "Generate Disconnected Resources Bundle"
3. Click "Run workflow"
4. Optionally specify a custom config file
5. Click "Run workflow" button

### Private Packages

For private npm packages:
```yaml
# Add to workflow secrets: NPM_TOKEN
# In collect_npm.sh, add:
echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > ~/.npmrc
```

For private container images:
```yaml
# Add to workflow secrets: DOCKER_USERNAME, DOCKER_PASSWORD
# The workflow will automatically use them
```

## Deployment to Disconnected Environment

### 1. Transfer Bundle

```bash
# USB Drive
cp output/resources-bundle-*.tar.gz /media/usb/

# SCP (if accessible)
scp output/resources-bundle-*.tar.gz user@airgap-server:/tmp/

# Physical media (CD/DVD)
# Burn the files to disc
```

### 2. Extract Bundle

```bash
tar -xzf resources-bundle-20240315-120000.tar.gz
cd bundle-staging/
```

### 3. Install Resources

Each directory has its own README.md with installation instructions:

```bash
# NPM
cd npm/ && cat README.md

# PyPI
cd pypi/ && cat README.md

# Debian
cd debian/ && cat README.md

# RPM
cd rpm/ && cat README.md

# Containers
cd containers/ && cat README.md

# VSCode
cd vscode/ && cat README.md
```

## Troubleshooting

### Workflow Fails

**Problem**: Workflow fails to download packages

**Solutions**:
- Check if package names are correct
- Verify versions exist
- Check GitHub Actions logs for specific errors
- Some packages may require authentication

### Large Bundle Size

**Problem**: Bundle is too large for single file

**Solutions**:
- Enable split_size in config: `split_size: "4G"`
- Use higher compression: `compression: "xz"`
- Split packages into multiple configs

### Missing Dependencies

**Problem**: Dependencies not included

**Solutions**:
- Ensure `include_dependencies: true`
- Check specific package README for manual deps
- Some packages have peer dependencies

### Rate Limiting

**Problem**: API rate limits hit

**Solutions**:
- Add delays between package downloads
- Use GitHub's cache action
- Reduce package count per run

## Security Considerations

1. **Verify Checksums**: Always verify checksums after transfer
   ```bash
   sha256sum -c checksums.sha256
   ```

2. **Scan Packages**: Consider scanning packages before deployment
   ```bash
   # Example with clamav
   clamscan -r bundle-staging/
   ```

3. **Review Contents**: Inspect package lists before production use

4. **Keep Updated**: Run monthly to get security updates

5. **Access Control**: Secure the GitHub repository with appropriate permissions

## Best Practices

1. **Test in Non-Production**: Always test bundles in a test environment first

2. **Version Pinning**: Pin versions for production environments
   ```yaml
   version: "1.2.3"  # Instead of "latest"
   ```

3. **Document Changes**: Keep a changelog of config changes

4. **Backup Bundles**: Keep previous bundles for rollback capability

5. **Monitor Size**: Watch bundle sizes and optimize as needed

6. **Regular Updates**: Update monthly for security patches

7. **Validate Config**: Test config changes in a feature branch first

## Contributing

To improve this pipeline:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues or questions:
- Open a GitHub issue
- Check GitHub Actions logs
- Review individual README files in each resource directory

## License

[Your License Here]

## Changelog

### Version 1.0.0 (Initial Release)
- NPM package collection
- PyPI package collection
- Debian package collection
- RPM package collection
- Container image collection
- VSCode extension collection
- Automated monthly workflow
- Configurable YAML inputs
- Tarball generation with checksums
