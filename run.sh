#!/bin/bash
# shellcheck disable=SC2312

# Error trapping from https://gist.github.com/oldratlee/902ad9a398affca37bfcfab64612e7d1
__error_trapper() {
  local parent_lineno="$1"
  local code="$2"
  local commands="$3"
  echo "error exit status $code, at file $0 on or near line $parent_lineno: $commands"
}
trap '__error_trapper "${LINENO}/${BASH_LINENO}" "$?" "$BASH_COMMAND"' ERR

set -euE -o pipefail

# Assume this script is at the other end of a symlink.  Get both
# ends, call them SRC_DIR (the directory of the source tree the
# symlink is in) and SCRIPT_DIR (the directory the original script
# itself is in).

SRC_DIR="$(realpath "$(dirname "$0")")"
SRC_NAME="$(basename "$SRC_DIR")"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Get to the original directory to build stuff there as needed (it
# probably isn't)
cd "$SCRIPT_DIR/"

podman build -t neovim_rust --build-arg USERNAME="$(id -un)" --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" .

LOCAL_DIR="$HOME/.local/rust_docker_cargo-$SRC_NAME"

if [[ ! -d $LOCAL_DIR ]]
then
  mkdir -p "$LOCAL_DIR"
  chcon -R -t container_file_t "$LOCAL_DIR"
fi

cd "$SRC_DIR/"

CONTAINER_NAME="neovim_rust_${SRC_NAME}"

# Use the source directory's dockerfile if any
if [[ -f "$SRC_DIR/Dockerfile.dev" ]]
then
  IMAGE_NAME=neovim_rust_${SRC_NAME}
  podman build -t "$IMAGE_NAME" --build-arg USERNAME="$(id -un)" --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" -f "$SRC_DIR/Dockerfile.dev" .
else
  IMAGE_NAME=neovim_rust
fi

podman kill "$CONTAINER_NAME" 2>/dev/null || true
podman rm "$CONTAINER_NAME" 2>/dev/null || true

POD_NAME="${CONTAINER_NAME}_pod"
podman pod stop "$POD_NAME" 2>/dev/null || true
podman pod rm "$POD_NAME" 2>/dev/null || true

podman pod create --userns=keep-id --network=slirp4netns -p 50555:50555 "$POD_NAME" 2>/dev/null || true

# See https://github.com/xd009642/tarpaulin/issues/1087 for the seccomp thing
podman run --name "$CONTAINER_NAME" --pod="$POD_NAME" --security-opt seccomp="$SCRIPT_DIR/seccomp.json" -w "/home/$(id -un)" \
  -e SRC_DIR="$SRC_DIR" \
  -v ~/src:"/home/$(id -un)/src" -v "$LOCAL_DIR:/home/$(id -un)/.cargo" \
  -v ~/config/dotfiles/nvim:"/home/$(id -un)/.config/nvim" -v ~/config/dotfiles/bashrc:"/home/$(id -un)/.bashrc" \
  -v ~/config/dotfiles/bothrc:"/home/$(id -un)/.bothrc" \
  -it "$IMAGE_NAME" bash
