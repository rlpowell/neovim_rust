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

SRC_DIR="$(pwd)"
SRC_NAME="$(basename "$(pwd)")"

# Assume this script is at the other end of a symlink; go to the
# directory the script is in
cd "$(dirname "$(readlink -f "$0")")"

podman build -t neovim_rust --build-arg USERNAME="$(id -un)" --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" .

LOCAL_DIR="$HOME/.local/rust_docker_cargo-$SRC_NAME"

if [[ ! -d $LOCAL_DIR ]]
then
  mkdir -p "$LOCAL_DIR"
  chcon -R -t container_file_t "$LOCAL_DIR"
fi

podman kill neovim_rust 2>/dev/null || true
podman rm neovim_rust 2>/dev/null || true

# See https://github.com/xd009642/tarpaulin/issues/1087 for the seccomp thing
podman run --name neovim_rust --userns=keep-id --security-opt seccomp=seccomp.json -w "/home/$(id -un)" \
  -e SRC_DIR="$SRC_DIR" \
  -v ~/src:"/home/$(id -un)/src" -v "$LOCAL_DIR:/home/$(id -un)/.cargo" \
  -v ~/config/dotfiles/nvim:"/home/$(id -un)/.config/nvim" -v ~/config/dotfiles/bashrc:"/home/$(id -un)/.bashrc" \
  -v ~/config/dotfiles/bothrc:"/home/$(id -un)/.bothrc" \
  -it neovim_rust bash
