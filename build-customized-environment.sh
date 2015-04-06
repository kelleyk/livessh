#!/usr/bin/env bash
#
#  Creates a Docker container from the post-debootstrap image uses it to install packages and perform other configuration tasks.
#

source ./vars
set -e

# Remove any existing container with this name.  (This will cause 'docker run' to fail.)
docker rm -f "${CONTAINER_NAME}" || true

# This is where the scripts running inside the container will put outputs.
rm -rf "$ARTIFACTS_TMPDIR"
mkdir -p "$ARTIFACTS_TMPDIR"

# And this is where we make files available to those scripts.
rm -rf "$RESOURCES_TMPDIR"
mkdir -p "$RESOURCES_TMPDIR"
cp _go.sh "$RESOURCES_TMPDIR"/_go.sh
chmod +x "$RESOURCES_TMPDIR"/_go.sh

# Could also put other dotfiles here.
# XXX: Hardwired kelleyk (source username).
mkdir -p "${RESOURCES_TMPDIR}"/home/"${USERNAME}"/.ssh
cp -a ~kelleyk/.ssh/authorized_keys "${RESOURCES_TMPDIR}"/home/"${USERNAME}"/.ssh/


# Go!
docker run -it --name "${CONTAINER_NAME}" -v "$ARTIFACTS_TMPDIR":/artifacts:rw -v "$RESOURCES_TMPDIR":/resources:ro "$DEBOOTSTRAP_IMAGE_TAG" /resources/_go.sh

# Exit with the same exit code that the script in our container did.  docker-run exits with a zero
# even if it fails, in which case we would otherwise happily report success.
exit $(docker inspect -f {{.State.ExitCode}} tmp-livessh)
