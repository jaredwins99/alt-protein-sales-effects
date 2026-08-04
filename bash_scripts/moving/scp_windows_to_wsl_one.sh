#!/bin/bash
# Selective push of a SINGLE fit dir from the Windows laptop to the desktop
# WSL machine. Run from Git Bash on the laptop.
#
# Usage:
#   bash publication/scp_windows_to_wsl_one.sh <relative_fit_path>
#
# Example:
#   bash publication/scp_windows_to_wsl_one.sh \
#        finalized_uncontaminated/a2_proportion_t/breakfast_p

set -e
REL="${1:?usage: $0 <relative_fit_path>  e.g. finalized_uncontaminated/a2_proportion_t/breakfast_p}"

REMOTE_HOST="192.168.0.124"
REMOTE_USER="godli"

LOCAL_BASE="/c/Users/godli/Desktop/HSFL/Restaurant Sales/model_fits"
REMOTE_DEST="$REMOTE_USER@$REMOTE_HOST:D:/HSFL/Restaurant Sales/testing/model_fits"

# Make sure the parent dir exists on the remote, then copy.
ssh "$REMOTE_USER@$REMOTE_HOST" \
    "mkdir -p \"D:/HSFL/Restaurant Sales/testing/model_fits/$(dirname "$REL")\""

scp -r "$LOCAL_BASE/$REL" \
       "$REMOTE_DEST/$(dirname "$REL")/"

echo "Pushed $REL"
