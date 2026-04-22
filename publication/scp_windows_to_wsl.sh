#!/bin/bash
# Push from this laptop (Windows) to another Windows machine at $REMOTE_HOST,
# into D:/HSFL/Restaurant Sales/testing/model_fits on the target.
# Target must be running OpenSSH server.
# Run from Git Bash on the laptop.

REMOTE_HOST="192.168.0.124"
REMOTE_USER="godli"

LOCAL_BASE="/c/Users/godli/Desktop/HSFL/Restaurant Sales/model_fits"
REMOTE_DEST="$REMOTE_USER@$REMOTE_HOST:D:/HSFL/Restaurant Sales/testing/model_fits/finalized_redone_trunc_cp/"

# T2 customer day fits (SFTP handles the space in the path literally;
# bash double-quotes keep it as a single arg).
scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_a5_customer_day" \
       "$REMOTE_DEST"
scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_a6_customer_t_day" \
       "$REMOTE_DEST"

echo "Done."
