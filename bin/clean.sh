#!/usr/bin/env bash
#
#  Removes everything except the debootstrapped docker container.
#

source ./vars
set -e

# Remove any existing container with this name.  (This will cause 'docker run' to fail.)
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# This is where the scripts running inside the container will put outputs.
rm -rf "${ARTIFACTS_TMPDIR}"
# And this is where we make files available to those scripts.
rm -rf "${RESOURCES_TMPDIR}"
# This is where we build the live environment's filesystem, which is then packed into a squashfs and placed on the bootable disc.
sudo rm -rf "${BASE_PATH}"
# This is where we build the bootable disc's filesystem, which is then packed into an ISO.
rm -rf "${IMAGE_PATH}"
# The final product.
rm -f "${OUTPUT_ISO_PATH}"
