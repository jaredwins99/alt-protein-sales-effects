#!/bin/bash
# Push from this laptop (Windows) to another Windows machine at $REMOTE_HOST,
# into D:/HSFL/Restaurant Sales/testing/model_fits on the target.
# Target must be running OpenSSH server.
# Run from Git Bash on the laptop.

REMOTE_HOST="192.168.0.124"
REMOTE_USER="godli"

# Use Git-Bash-style forward-slash paths for the local source (still works for Windows).
LOCAL_BASE="/c/Users/godli/Desktop/HSFL/Restaurant Sales/model_fits"

# scp escapes spaces in remote paths via backslash-escape INSIDE the quoted string.
# The remote shell on the target (cmd or PowerShell over OpenSSH) unquotes once.
REMOTE_BASE="D:/HSFL/Restaurant\\ Sales/testing/model_fits"
DEST="$REMOTE_USER@$REMOTE_HOST:$REMOTE_BASE"

# Prop reruns already transferred previously — commented out.
# scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_proportion/total/vegan_dishes_prop" \
#        "$DEST/finalized_redone_trunc_cp/t2_proportion/total/"
# scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_proportion/total/vegetarian_dishes_count" \
#        "$DEST/finalized_redone_trunc_cp/t2_proportion/total/"

# T2 customer day fits (include the subdirs brought over from Sherlock)
scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_customer_gaussian_iid_day" \
       "$DEST/finalized_redone_trunc_cp/"
scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_customer_targeted_gaussian_iid_day" \
       "$DEST/finalized_redone_trunc_cp/"

echo "Done."
