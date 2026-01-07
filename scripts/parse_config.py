#!/usr/bin/env python3
"""
Configuration parser for disconnected resources pipeline.
Reads YAML configuration and exports it in formats usable by shell scripts.
"""

import yaml
import json
import sys
import os
from pathlib import Path


def load_config(config_path):
    """Load and parse YAML configuration file."""
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        return config
    except FileNotFoundError:
        print(f"Error: Configuration file not found: {config_path}", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error: Invalid YAML in configuration file: {e}", file=sys.stderr)
        sys.exit(1)


def validate_config(config):
    """Validate configuration structure and values."""
    errors = []

    # Check required sections
    if 'metadata' not in config:
        errors.append("Missing 'metadata' section")

    # Check at least one package source is enabled
    enabled_sources = []
    for source in ['npm', 'pypi', 'debian', 'rpm', 'containers', 'vscode']:
        if source in config and config[source].get('enabled', False):
            enabled_sources.append(source)

    if not enabled_sources:
        errors.append("No package sources are enabled")

    # Validate npm section
    if config.get('npm', {}).get('enabled'):
        if 'packages' not in config['npm'] or not config['npm']['packages']:
            errors.append("npm is enabled but no packages specified")

    # Validate pypi section
    if config.get('pypi', {}).get('enabled'):
        if 'packages' not in config['pypi'] or not config['pypi']['packages']:
            errors.append("pypi is enabled but no packages specified")

    # Validate debian section
    if config.get('debian', {}).get('enabled'):
        if 'packages' not in config['debian'] or not config['debian']['packages']:
            errors.append("debian is enabled but no packages specified")

    # Validate rpm section
    if config.get('rpm', {}).get('enabled'):
        if 'packages' not in config['rpm'] or not config['rpm']['packages']:
            errors.append("rpm is enabled but no packages specified")

    # Validate containers section
    if config.get('containers', {}).get('enabled'):
        if 'images' not in config['containers'] or not config['containers']['images']:
            errors.append("containers is enabled but no images specified")

    # Validate vscode section
    if config.get('vscode', {}).get('enabled'):
        if 'extensions' not in config['vscode'] or not config['vscode']['extensions']:
            errors.append("vscode is enabled but no extensions specified")

    if errors:
        print("Configuration validation errors:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        sys.exit(1)

    return True


def export_json(config, output_path=None):
    """Export configuration as JSON file."""
    json_str = json.dumps(config, indent=2)

    if output_path:
        with open(output_path, 'w') as f:
            f.write(json_str)
        print(f"Configuration exported to: {output_path}")
    else:
        print(json_str)


def export_env_vars(config):
    """Export configuration as shell environment variables."""
    env_lines = []

    # Export metadata
    if 'metadata' in config:
        env_lines.append(f"export ENV_NAME='{config['metadata'].get('environment_name', 'default')}'")
        env_lines.append(f"export ENV_DESC='{config['metadata'].get('description', '')}'")

    # Export package source enablement
    for source in ['npm', 'pypi', 'debian', 'rpm', 'containers', 'vscode']:
        enabled = config.get(source, {}).get('enabled', False)
        env_lines.append(f"export {source.upper()}_ENABLED={str(enabled).lower()}")

    # Export npm config
    if config.get('npm', {}).get('enabled'):
        npm_config = config['npm']
        env_lines.append(f"export NPM_INCLUDE_DEPS={str(npm_config.get('include_dependencies', True)).lower()}")

    # Export pypi config
    if config.get('pypi', {}).get('enabled'):
        pypi_config = config['pypi']
        env_lines.append(f"export PYPI_INCLUDE_DEPS={str(pypi_config.get('include_dependencies', True)).lower()}")
        if 'python_versions' in pypi_config:
            env_lines.append(f"export PYPI_PYTHON_VERSIONS='{','.join(pypi_config['python_versions'])}'")
        if 'platforms' in pypi_config:
            env_lines.append(f"export PYPI_PLATFORMS='{','.join(pypi_config['platforms'])}'")

    # Export debian config
    if config.get('debian', {}).get('enabled'):
        debian_config = config['debian']
        env_lines.append(f"export DEBIAN_DISTRIBUTION='{debian_config.get('distribution', 'ubuntu')}'")
        env_lines.append(f"export DEBIAN_RELEASE='{debian_config.get('release', '22.04')}'")
        env_lines.append(f"export DEBIAN_INCLUDE_DEPS={str(debian_config.get('include_dependencies', True)).lower()}")
        if 'architectures' in debian_config:
            env_lines.append(f"export DEBIAN_ARCHITECTURES='{','.join(debian_config['architectures'])}'")

    # Export rpm config
    if config.get('rpm', {}).get('enabled'):
        rpm_config = config['rpm']
        env_lines.append(f"export RPM_DISTRIBUTION='{rpm_config.get('distribution', 'rhel')}'")
        env_lines.append(f"export RPM_RELEASE='{rpm_config.get('release', '9')}'")
        env_lines.append(f"export RPM_INCLUDE_DEPS={str(rpm_config.get('include_dependencies', True)).lower()}")
        if 'architectures' in rpm_config:
            env_lines.append(f"export RPM_ARCHITECTURES='{','.join(rpm_config['architectures'])}'")

    # Export containers config
    if config.get('containers', {}).get('enabled'):
        containers_config = config['containers']
        env_lines.append(f"export CONTAINERS_EXPORT_FORMAT='{containers_config.get('export_format', 'docker-archive')}'")

    # Export output config
    if 'output' in config:
        output_config = config['output']
        env_lines.append(f"export OUTPUT_TARBALL_NAME='{output_config.get('tarball_name', 'resources-bundle')}'")
        env_lines.append(f"export OUTPUT_COMPRESSION='{output_config.get('compression', 'gzip')}'")
        env_lines.append(f"export OUTPUT_SPLIT_SIZE='{output_config.get('split_size', '0')}'")

    # Export security config
    if 'security' in config:
        security_config = config['security']
        env_lines.append(f"export SECURITY_GENERATE_CHECKSUMS={str(security_config.get('generate_checksums', True)).lower()}")
        env_lines.append(f"export SECURITY_CHECKSUM_ALGORITHM='{security_config.get('checksum_algorithm', 'sha256')}'")

    return '\n'.join(env_lines)


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description='Parse disconnected resources configuration')
    parser.add_argument('config_file', help='Path to YAML configuration file')
    parser.add_argument('--format', choices=['json', 'env'], default='json',
                        help='Output format (default: json)')
    parser.add_argument('--output', '-o', help='Output file path (default: stdout)')
    parser.add_argument('--validate-only', action='store_true',
                        help='Only validate configuration, do not output')

    args = parser.parse_args()

    # Load configuration
    config = load_config(args.config_file)

    # Validate configuration
    validate_config(config)

    if args.validate_only:
        print("Configuration is valid")
        return

    # Export configuration
    if args.format == 'json':
        export_json(config, args.output)
    elif args.format == 'env':
        env_output = export_env_vars(config)
        if args.output:
            with open(args.output, 'w') as f:
                f.write(env_output)
            print(f"Environment variables exported to: {args.output}")
        else:
            print(env_output)


if __name__ == '__main__':
    main()
