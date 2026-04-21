#!/bin/bash
# Push from this laptop (Windows) to another Windows machine at $REMOTE_HOST,
# into D:/HSFL/Restaurant Sales/testing/model_fits on the target.
# Target must be running OpenSSH server.
# Run from Git Bash on the laptop.

REMOTE_HOST="192.168.0.124"
REMOTE_USER="godli"

LOCAL_BASE="/c/Users/godli/Desktop/HSFL/Restaurant Sales/model_fits"
# Remote root — bash will expand $variables, but the literal quotes \" go
# through to OpenSSH's remote shell so the space in the path is preserved
# as a single token.
REMOTE_BASE_Q='\"D:/HSFL/Restaurant Sales/testing/model_fits\"'

# Preflight: ensure the destination parent dir exists on the Windows target.
# Using cmd.exe quoting (backslashes + double-quotes).
ssh "$REMOTE_USER@$REMOTE_HOST" \
  'if not exist "D:\HSFL\Restaurant Sales\testing\model_fits\finalized_redone_trunc_cp" mkdir "D:\HSFL\Restaurant Sales\testing\model_fits\finalized_redone_trunc_cp"'

# Prop reruns already transferred — commented out.
# scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_proportion/total/vegan_dishes_prop" \
#        "$REMOTE_USER@$REMOTE_HOST:\"D:/HSFL/Restaurant Sales/testing/model_fits/finalized_redone_trunc_cp/t2_proportion/total/\""
# scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_proportion/total/vegetarian_dishes_count" \
#        "$REMOTE_USER@$REMOTE_HOST:\"D:/HSFL/Restaurant Sales/testing/model_fits/finalized_redone_trunc_cp/t2_proportion/total/\""

# T2 customer day fits
scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_customer_gaussian_iid_day" \
       "$REMOTE_USER@$REMOTE_HOST:\"D:/HSFL/Restaurant Sales/testing/model_fits/finalized_redone_trunc_cp/\""
scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_customer_targeted_gaussian_iid_day" \
       "$REMOTE_USER@$REMOTE_HOST:\"D:/HSFL/Restaurant Sales/testing/model_fits/finalized_redone_trunc_cp/\""

echo "Done."
