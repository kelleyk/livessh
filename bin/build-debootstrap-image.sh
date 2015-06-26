#!/usr/bin/env bash

source ./vars
set -e

sudo ../contrib/mkimage.sh -t "${DEBOOTSTRAP_IMAGE_TAG}" debootstrap --include=ubuntu-minimal --components=main,universe,multiverse "${RELEASE}" "${APT_PROXY}/ubuntu"
