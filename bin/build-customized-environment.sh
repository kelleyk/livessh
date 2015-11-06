#!/usr/bin/env bash
#
#  Creates a Docker container from the post-debootstrap image uses it to install packages and perform other configuration tasks.
#

. ./vars
set -e

# Remove any existing container with this name.  (This will cause 'docker run' to fail.)
docker rm -f "${CONTAINER_NAME}" || true

# This is where the scripts running inside the container will put outputs.
rm -rf "$ARTIFACTS_TMPDIR"
mkdir -p "$ARTIFACTS_TMPDIR"

# And this is where we make files available to those scripts.
rm -rf "$RESOURCES_TMPDIR"
mkdir -p "$RESOURCES_TMPDIR"

# Insert the values of these four variables.  (XXX: This is very messy and depends on our not having our sed delimiter in the
# values of these variables.)
SET_VARS=""
for VARNAME in "${CUSTOMIZE_VARS[@]}"; do
    SET_VARS+="${VARNAME}=\"$(eval echo \$$VARNAME)\"\n"
done
sed -e "s|@SET_VARS@|$SET_VARS|g" "${DATA_PATH}"/customize.sh.in > "$RESOURCES_TMPDIR"/customize.sh
chmod +x "$RESOURCES_TMPDIR"/customize.sh

# TODO: Nothing from `vars` is available to these scripts.
cp -a "$CUSTOMIZE_BASE_PATH"/customize.d "$RESOURCES_TMPDIR"/customize.d

#####################
## Run user pre-customize scripts (on the host)
#####################

for SCRIPT_NAME in $(run-parts --test "$CUSTOMIZE_BASE_PATH"/pre-customize.d); do
    . "${SCRIPT_NAME}"
done

#####################
## Go!
#####################

docker run -it --name "${CONTAINER_NAME}" -v "$ARTIFACTS_TMPDIR":/artifacts:rw -v "$RESOURCES_TMPDIR":/resources:ro "$DEBOOTSTRAP_IMAGE_TAG" /resources/customize.sh

# Exit with the same exit code that the script in our container did.  docker-run exits with a zero
# even if it fails, in which case we would otherwise happily report success.
exit $(docker inspect -f {{.State.ExitCode}} tmp-livessh)
