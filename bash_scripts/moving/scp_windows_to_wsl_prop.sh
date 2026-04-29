#!/bin/bash
# Push the 2 prop reruns (total_on_vegan_prop, total_on_vegetarian_count)
# from this laptop (Windows) to the other Windows machine at $REMOTE_HOST,
# into D:/HSFL/Restaurant Sales/testing/model_fits/finalized_redone_trunc_cp/t2_a1_proportion/total/
# Run from Git Bash on the laptop.

REMOTE_HOST="192.168.0.124"
REMOTE_USER="godli"

LOCAL_BASE="/c/Users/godli/Desktop/HSFL/Restaurant Sales/model_fits"
REMOTE_DEST="$REMOTE_USER@$REMOTE_HOST:D:/HSFL/Restaurant Sales/testing/model_fits/finalized_redone_trunc_cp/t2_a1_proportion/total/"

scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_a1_proportion/total/vegan_dishes_prop" \
       "$REMOTE_DEST"
scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_a1_proportion/total/vegetarian_dishes_count" \
       "$REMOTE_DEST"

echo "Done."
