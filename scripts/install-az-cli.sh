#!/usr/bin/env bash
#
# install-az-cli.sh — install the Azure CLI + azure-devops extension
# system-wide, for all users.
#
# Target: Debian/Ubuntu Linux, run as root (or via sudo).
# Installs Python dependencies via apt, azure-cli into a shared
# virtualenv under /usr/local/share, the azure-devops extension into a
# shared extension directory, and a wrapper at /usr/local/bin/az.
# Idempotent: safe to re-run.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "error: this script installs system-wide; run it as root (e.g. sudo $0)." >&2
  exit 1
fi

# --- Configuration -----------------------------------------------------------
VENV_DIR="/usr/local/share/azure-cli"
EXT_DIR="/usr/local/share/azure-cli/extensions"
WRAPPER="/usr/local/bin/az"
# -----------------------------------------------------------------------------

if ! command -v apt-get >/dev/null 2>&1; then
  echo "error: this script requires apt (Debian/Ubuntu)." >&2
  exit 1
fi

echo "==> Updating package lists and installing Python dependencies..."
apt-get update
apt-get install -y python3 python3-venv python3-pip

echo "==> Creating shared virtual environment at $VENV_DIR..."
python3 -m venv "$VENV_DIR"

echo "==> Upgrading pip and installing Azure CLI..."
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install azure-cli

echo "==> Installing Azure DevOps/Boards extension (shared)..."
export AZURE_EXTENSION_DIR="$EXT_DIR"
if "$VENV_DIR/bin/az" extension list --output tsv | awk '{print $1}' | grep -qx azure-devops; then
  echo "    azure-devops extension already installed."
else
  "$VENV_DIR/bin/az" extension add --name azure-devops
fi

echo "==> Creating wrapper at $WRAPPER..."
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
export AZURE_EXTENSION_DIR="\${AZURE_EXTENSION_DIR:-$EXT_DIR}"
exec "$VENV_DIR/bin/az" "\$@"
EOF
chmod 755 "$WRAPPER"

echo "=================================================="
echo " Installation complete!"
echo "=================================================="
echo "Azure CLI and the azure-devops extension are installed for all users."
echo ""
case ":$PATH:" in
  *":/usr/local/bin:"*)
    echo "'az' is ready now: /usr/local/bin is already on the PATH."
    ;;
  *)
    echo "Ensure /usr/local/bin is on the PATH"
    echo "(add to ~/.bashrc: export PATH=\"\$PATH:/usr/local/bin\")."
    ;;
esac
echo ""
echo "Note: each user authenticates once with 'az login' and"
echo "'az devops login' (credentials stay in their own ~/.azure)."
echo ""
echo "Try it: az --version"
