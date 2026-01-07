#!/bin/bash
set -euo pipefail

# Container Image Collector for Disconnected Environments
# Pulls and exports container images

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON="${1:-config.json}"
OUTPUT_DIR="${2:-output/containers}"

echo "=== Container Image Collector ==="
echo "Config: $CONFIG_JSON"
echo "Output: $OUTPUT_DIR"

# Check if containers collection is enabled
CONTAINERS_ENABLED=$(jq -r '.containers.enabled // false' "$CONFIG_JSON")
if [ "$CONTAINERS_ENABLED" != "true" ]; then
    echo "Container collection is disabled in config"
    exit 0
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

# Parse configuration
EXPORT_FORMAT=$(jq -r '.containers.export_format // "docker-archive"' "$CONFIG_JSON")
IMAGES=$(jq -c '.containers.images[]' "$CONFIG_JSON")

echo "Export format: $EXPORT_FORMAT"
echo ""

# Check if docker or podman is available
if command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
elif command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
else
    echo "Error: Neither docker nor podman found. Container collection requires a container runtime."
    exit 1
fi

echo "Using container runtime: $CONTAINER_CMD"
echo ""

# Create images directory
mkdir -p images

# Initialize image list
> images.txt

# Pull and export images
for img in $IMAGES; do
    IMAGE=$(echo "$img" | jq -r '.image')
    TAG=$(echo "$img" | jq -r '.tag // "latest"')
    FULL_IMAGE="$IMAGE:$TAG"

    echo "Processing: $FULL_IMAGE"

    # Pull image
    echo "  Pulling image..."
    $CONTAINER_CMD pull "$FULL_IMAGE" || {
        echo "  Warning: Failed to pull $FULL_IMAGE"
        continue
    }

    # Create safe filename
    SAFE_NAME=$(echo "$FULL_IMAGE" | sed 's/[\/:]/_/g')
    OUTPUT_FILE="images/${SAFE_NAME}.tar"

    # Export image
    echo "  Exporting image..."
    if [ "$EXPORT_FORMAT" = "docker-archive" ]; then
        $CONTAINER_CMD save -o "$OUTPUT_FILE" "$FULL_IMAGE" || {
            echo "  Warning: Failed to export $FULL_IMAGE"
            continue
        }
    elif [ "$EXPORT_FORMAT" = "oci-archive" ]; then
        if [ "$CONTAINER_CMD" = "podman" ]; then
            $CONTAINER_CMD save --format oci-archive -o "$OUTPUT_FILE" "$FULL_IMAGE" || {
                echo "  Warning: Failed to export $FULL_IMAGE"
                continue
            }
        else
            echo "  Warning: OCI archive format requires podman, falling back to docker-archive"
            $CONTAINER_CMD save -o "$OUTPUT_FILE" "$FULL_IMAGE" || {
                echo "  Warning: Failed to export $FULL_IMAGE"
                continue
            }
        fi
    else
        echo "  Warning: Unknown export format: $EXPORT_FORMAT, using docker-archive"
        $CONTAINER_CMD save -o "$OUTPUT_FILE" "$FULL_IMAGE" || {
            echo "  Warning: Failed to export $FULL_IMAGE"
            continue
        }
    fi

    # Compress the tar file
    echo "  Compressing..."
    gzip "$OUTPUT_FILE" || echo "  Warning: Compression failed"

    # Record image
    echo "$FULL_IMAGE" >> images.txt
    echo "  Done: ${OUTPUT_FILE}.gz"
    echo ""
done

# Count exported images
IMAGE_COUNT=$(ls -1 images/*.tar.gz 2>/dev/null | wc -l || echo "0")
echo "Exported $IMAGE_COUNT container images"

# Generate image metadata
echo "Generating metadata..."
> image_metadata.txt
for img_file in images/*.tar.gz; do
    if [ -f "$img_file" ]; then
        SIZE=$(du -h "$img_file" | cut -f1)
        BASENAME=$(basename "$img_file")
        echo "$BASENAME: $SIZE" >> image_metadata.txt
    fi
done

# Generate README for deployment
cat > README.md << 'EOF'
# Container Images for Disconnected Environment

This directory contains container images exported as tar archives for offline loading.

## Contents

- `images/` - Exported container images (compressed tar files)
- `images.txt` - List of images in this bundle
- `image_metadata.txt` - Image sizes
- `README.md` - This file

## Loading Images

### Using Docker

Load a single image:
```bash
docker load -i images/docker.io_library_nginx_1.25-alpine.tar.gz
```

Load all images:
```bash
for img in images/*.tar.gz; do
  echo "Loading $img..."
  docker load -i "$img"
done
```

Verify loaded images:
```bash
docker images
```

### Using Podman

Load a single image:
```bash
podman load -i images/docker.io_library_nginx_1.25-alpine.tar.gz
```

Load all images:
```bash
for img in images/*.tar.gz; do
  echo "Loading $img..."
  podman load -i "$img"
done
```

Verify loaded images:
```bash
podman images
```

### Using containerd / nerdctl

```bash
nerdctl load -i images/docker.io_library_nginx_1.25-alpine.tar.gz
```

### Using CRI-O / crictl

```bash
# For Kubernetes environments with CRI-O
crictl pull --input images/docker.io_library_nginx_1.25-alpine.tar
```

## Bulk Loading Script

Create a script to load all images:

```bash
#!/bin/bash
# load_all_images.sh

set -e

IMAGES_DIR="images"
RUNTIME="${1:-docker}"  # docker, podman, or nerdctl

echo "Loading container images using $RUNTIME..."

for img in $IMAGES_DIR/*.tar.gz; do
  echo "Loading $(basename $img)..."

  case $RUNTIME in
    docker)
      docker load -i "$img"
      ;;
    podman)
      podman load -i "$img"
      ;;
    nerdctl)
      nerdctl load -i "$img"
      ;;
    *)
      echo "Unknown runtime: $RUNTIME"
      exit 1
      ;;
  esac
done

echo "All images loaded successfully!"

# List loaded images
$RUNTIME images
```

Run the script:
```bash
chmod +x load_all_images.sh
./load_all_images.sh docker
```

## Verifying Images

List loaded images:
```bash
docker images
# or
podman images
```

Inspect an image:
```bash
docker inspect nginx:1.25-alpine
```

Test running a container:
```bash
docker run --rm nginx:1.25-alpine echo "Test successful"
```

## Tagging Images

If you need to retag images for your local registry:

```bash
# Load image
docker load -i images/docker.io_library_nginx_1.25-alpine.tar.gz

# Retag for local registry
docker tag nginx:1.25-alpine localhost:5000/nginx:1.25-alpine

# Push to local registry
docker push localhost:5000/nginx:1.25-alpine
```

## Setting Up Local Container Registry

For a shared local registry in your disconnected environment:

### Method 1: Docker Registry

1. Load and run registry container (ensure registry image is in this bundle):
```bash
docker load -i images/registry_2.tar.gz
docker run -d -p 5000:5000 --name registry registry:2
```

2. Load and push images:
```bash
for img_file in images/*.tar.gz; do
  docker load -i "$img_file"
done

# Retag and push
docker tag nginx:1.25-alpine localhost:5000/nginx:1.25-alpine
docker push localhost:5000/nginx:1.25-alpine
```

3. Configure clients to use insecure registry (if not using TLS):
```json
# /etc/docker/daemon.json
{
  "insecure-registries": ["your-registry-ip:5000"]
}
```

Restart Docker:
```bash
sudo systemctl restart docker
```

### Method 2: Harbor (Full-featured registry)

If Harbor image is included, follow Harbor deployment documentation.

## Image Sizes

See `image_metadata.txt` for individual image sizes.

Total size:
```bash
du -sh images/
```

## Working with Multi-Architecture Images

Some images support multiple architectures (amd64, arm64, etc.):

Check image architecture:
```bash
docker inspect nginx:1.25-alpine | jq '.[].Architecture'
```

Pull specific architecture (when downloading):
```bash
docker pull --platform linux/amd64 nginx:1.25-alpine
docker pull --platform linux/arm64 nginx:1.25-alpine
```

## Troubleshooting

### Issue: Failed to load image
**Solution**:
```bash
# Verify tar file integrity
tar -tzf images/image.tar.gz | head

# Try decompressing first
gunzip images/image.tar.gz
docker load -i images/image.tar
```

### Issue: No space left on device
**Solution**:
- Check available disk space: `df -h`
- Clean up unused images: `docker system prune -a`
- Load images one at a time

### Issue: Image architecture mismatch
**Solution**:
- Ensure images were downloaded for correct architecture
- Use `--platform` flag when loading if supported

### Issue: Name conflicts
**Solution**:
```bash
# Remove existing image
docker rmi old-image:tag

# Or force load
docker load -i image.tar.gz
```

### Issue: Corrupted tar file
**Solution**:
- Verify file integrity with checksums
- Re-download if possible
- Try alternative extraction: `tar -xzf image.tar.gz`

## Best Practices

1. **Verify Checksums**: Always verify image integrity after transfer

2. **Test Images**: Test at least one container from each image
   ```bash
   docker run --rm image:tag echo "test"
   ```

3. **Document Tags**: Keep record of image tags and versions

4. **Storage Management**: Monitor disk usage, images can be large

5. **Security Scanning**: Consider scanning images before deployment
   ```bash
   docker scan image:tag  # if available
   ```

6. **Backup**: Keep image archives as backup

7. **Update Strategy**: Plan how to update images in disconnected environment

## Image List

See `images.txt` for the complete list of images in this bundle.

## System Requirements

- Container runtime: Docker, Podman, containerd, or CRI-O
- Sufficient disk space (see image_metadata.txt for sizes)
- Matching architecture (amd64, arm64, etc.)

## Support

For container-specific issues, refer to:
- Docker documentation: https://docs.docker.com
- Podman documentation: https://docs.podman.io
- Original image documentation on Docker Hub or registries
EOF

echo "Container collection complete!"
echo "Output directory: $OUTPUT_DIR"
