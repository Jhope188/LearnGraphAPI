#!/bin/bash
# Mac - Network - D - GSA Client Install
#
# Installs the Global Secure Access client on macOS. Run as root (Intune shell script, "run as signed-in user" = No).
#
# IMPORTANT: this script does NOT approve the system extension or the transparent app proxy.
# Those approvals come from two MDM profiles that must reach the Mac first:
#   - Settings catalog: Allowed System Extensions (team UBF8T346G9, bundle IDs ...globalsecureaccess.tunnel / ...globalsecureaccess)
#   - Custom profile: Global Secure Access transparent proxy payload
# Without them the user sees "System Extension Blocked" / "would like to add proxy configurations" prompts.
# Source: https://learn.microsoft.com/en-us/entra/global-secure-access/how-to-install-macos-client
#
# Silent install command per Learn: installer -pkg <file> -target /

# ---- settings -------------------------------------------------------------
# This aka.ms short link is NOT on the Learn macOS install page (Learn says download from
# Entra admin center > Global Secure Access > Connect > Client download). Verify it before pilot use:
#   curl -sIL "https://aka.ms/GlobalSecureAccess-macOS" | head -20
PKG_URL="https://aka.ms/GlobalSecureAccess-macOS"
APP_DIR="/Applications/GlobalSecureAccessClient"   # path from Learn's uninstall command
MIN_MACOS_MAJOR=14                                 # Learn prerequisite: macOS 14 or later
MS_TEAM_ID="UBF8T346G9"                            # Microsoft team ID from Learn's extension table
CHECK_SIGNATURE=1                                  # 1 = refuse the package unless pkgutil shows the Microsoft team ID
REQUIRE_PROFILES=0                                 # 1 = exit 1 (retry later) if the GSA profiles are not on the Mac yet
LOG="/var/log/gsa-client-install.log"
# ---------------------------------------------------------------------------

exec >> "$LOG" 2>&1
echo "=== $(date '+%Y-%m-%d %H:%M:%S') GSA client install start ==="

if [ "$(id -u)" -ne 0 ]; then echo "Must run as root."; exit 1; fi

MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$MAJOR" -lt "$MIN_MACOS_MAJOR" ]; then
  echo "macOS $MAJOR is below the required $MIN_MACOS_MAJOR. Skipping."
  exit 0
fi

if [ -d "$APP_DIR" ]; then
  echo "Client already installed at $APP_DIR. Nothing to do."
  exit 0
fi

# Soft check: are the approval profiles present? (output format not verified; treat a miss as a warning by default)
if ! /usr/bin/profiles show -all 2>/dev/null | grep -qi "com.microsoft.globalsecureaccess"; then
  echo "WARNING: no profile mentioning com.microsoft.globalsecureaccess found. Users may see approval prompts."
  if [ "$REQUIRE_PROFILES" -eq 1 ]; then echo "REQUIRE_PROFILES=1, exiting so Intune retries."; exit 1; fi
fi

PKG="$(mktemp /tmp/GlobalSecureAccessClient.XXXXXX).pkg"
trap 'rm -f "$PKG"' EXIT

echo "Downloading $PKG_URL"
if ! /usr/bin/curl --fail --location --silent --show-error --max-time 900 -o "$PKG" "$PKG_URL"; then
  echo "Download failed."; exit 1
fi
if [ ! -s "$PKG" ]; then echo "Downloaded file is empty."; exit 1; fi

if [ "$CHECK_SIGNATURE" -eq 1 ]; then
  if ! /usr/sbin/pkgutil --check-signature "$PKG" | grep -q "$MS_TEAM_ID"; then
    echo "Package signature does not show team ID $MS_TEAM_ID. Refusing to install."
    /usr/sbin/pkgutil --check-signature "$PKG"
    exit 1
  fi
  echo "Package signature check passed (team ID $MS_TEAM_ID)."
fi

echo "Installing..."
if /usr/sbin/installer -pkg "$PKG" -target /; then
  echo "Install completed."
  exit 0
else
  RC=$?
  echo "installer exited with $RC"
  exit "$RC"
fi
