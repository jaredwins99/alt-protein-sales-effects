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
# The desktop's sshd runs cmd.exe, NOT bash: "mkdir -p" makes cmd try to create
# a folder literally named "-p" and abort. cmd's mkdir already creates
# intermediate dirs, so all that is needed is Windows separators and a guard
# against the dir already existing.
REL_DIR="$(dirname "$REL")"
WIN_DIR="${REL_DIR//\//\\}"
WIN_BASE='D:\HSFL\Restaurant Sales\testing\model_fits'
ssh "$REMOTE_USER@$REMOTE_HOST" \
    "if not exist \"$WIN_BASE\\$WIN_DIR\" mkdir \"$WIN_BASE\\$WIN_DIR\""

scp -r "$LOCAL_BASE/$REL" \
       "$REMOTE_DEST/$(dirname "$REL")/"

echo "Pushed $REL"
