#!/bin/sh
# e2memory CLI installer — https://charts.cloudscript.com.br/cli/e2memory/install.sh
# Usage: curl -fsSL https://charts.cloudscript.com.br/cli/e2memory/install.sh | sh
#        E2MEMORY_VERSION=v0.1.0 ... | sh          (default: latest)
#        E2MEMORY_INSTALL_DIR=/usr/local/bin ... | sh (default: ~/.local/bin)
set -eu

BASE="${E2MEMORY_BASE_URL:-https://charts.cloudscript.com.br/cli/e2memory}"
DIR="${E2MEMORY_INSTALL_DIR:-$HOME/.local/bin}"

os=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$os" in linux|darwin) ;; *) echo "unsupported OS: $os" >&2; exit 1;; esac
arch=$(uname -m)
case "$arch" in x86_64|amd64) arch=amd64;; arm64|aarch64) arch=arm64;; *) echo "unsupported arch: $arch" >&2; exit 1;; esac

ver="${E2MEMORY_VERSION:-}"
if [ -z "$ver" ]; then ver=$(curl -fsSL "$BASE/latest" | tr -d '[:space:]'); fi
[ -n "$ver" ] || { echo "could not resolve latest version" >&2; exit 1; }
plain=${ver#v}
file="e2memory_${plain}_${os}_${arch}.tar.gz"
url="$BASE/$ver/$file"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
echo "==> downloading e2memory $ver ($os/$arch)"
curl -fsSL -o "$tmp/$file" "$url"
curl -fsSL -o "$tmp/checksums.txt" "$BASE/$ver/checksums.txt"

echo "==> verifying checksum"
expected=$(grep " $file\$" "$tmp/checksums.txt" | awk '{print $1}')
[ -n "$expected" ] || { echo "checksum entry not found for $file" >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then actual=$(sha256sum "$tmp/$file" | awk '{print $1}'); else actual=$(shasum -a 256 "$tmp/$file" | awk '{print $1}'); fi
[ "$expected" = "$actual" ] || { echo "checksum mismatch" >&2; exit 1; }

# Optional: verify the checksums file signature (cosign keyless, GitHub OIDC) when cosign is installed.
if command -v cosign >/dev/null 2>&1; then
  if curl -fsSL -o "$tmp/checksums.txt.sig" "$BASE/$ver/checksums.txt.sig" && curl -fsSL -o "$tmp/checksums.txt.pem" "$BASE/$ver/checksums.txt.pem"; then
    echo "==> verifying signature (cosign)"
    cosign verify-blob --signature "$tmp/checksums.txt.sig" --certificate "$tmp/checksums.txt.pem" \
      --certificate-identity-regexp '^https://github.com/cloudscript-technology/e2memory/' \
      --certificate-oidc-issuer https://token.actions.githubusercontent.com "$tmp/checksums.txt" >/dev/null
  fi
fi

echo "==> installing to $DIR"
mkdir -p "$DIR"
tar -xzf "$tmp/$file" -C "$tmp" e2memory
rm -f "$DIR/e2memory"            # macOS kills binaries overwritten in place (stale signature cache)
mv "$tmp/e2memory" "$DIR/e2memory"
chmod 0755 "$DIR/e2memory"

case ":$PATH:" in *":$DIR:"*) ;; *) echo "note: add $DIR to your PATH";; esac
echo "==> installed: $("$DIR/e2memory" --version)"
cat <<MSG

Next steps:
  # root identity (yours) — the admin registers the printed bundle:
  e2memory setup --url https://e2memory.foundation.management.kubescript.io
  # or a subdomain identity received from your team lead:
  e2memory setup --url https://e2memory.foundation.management.kubescript.io --handoff 'E2M-HANDOFF-...'
MSG
