#!/bin/bash

set -euo pipefail

PLUGIN_ID="jesse.glass-clock"
PLUGIN_URL="https://github.com/indibyte/jesse-glass-clock"
PLUGINS_DIR="${HOME}/.config/omarchy/plugins"

install_with_omarchy() {
  omarchy plugin add "$PLUGIN_URL" --enable --yes
  echo "Glass Clock installed and enabled."
}

install_manually() {
  target="$PLUGINS_DIR/$PLUGIN_ID"
  if [[ -e $target || -L $target ]]; then
    echo "Glass Clock already installed at: $target"
    exit 0
  fi
  mkdir -p "$PLUGINS_DIR"
  stage="${PLUGINS_DIR}/.glass-clock.tmp.$$"
  rm -rf "$stage"
  git clone -- "$PLUGIN_URL" "$stage"
  mv "$stage" "$target"
  echo "Glass Clock installed to: $target"
  echo "Enable it with: omarchy plugin enable $PLUGIN_ID"
}

if command -v omarchy >/dev/null 2>&1; then
  install_with_omarchy
elif command -v git >/dev/null 2>&1; then
  install_manually
else
  echo "error: neither 'omarchy' nor 'git' found on PATH" >&2
  exit 1
fi