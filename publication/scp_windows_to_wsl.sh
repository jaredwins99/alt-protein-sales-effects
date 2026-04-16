#!/bin/bash
# Selective push from Windows to WSL machine ($WSL_IP).
# Only transfers the 2 outstanding prop reruns + all T2 customer day fits.
# Run from Windows (e.g. Git Bash).

WSL_IP="<ip>"   # replace with WSL machine's IP
LOCAL_BASE="C:\Users\godli\Desktop\HSFL\Restaurant Sales\model_fits"
REMOTE_BASE="godli@$WSL_IP:/D/HSFL/Restaurant Sales/testing/model_fits"
# ↑ adjust remote path for your target shell; PowerShell target may expect
#   'D:/HSFL/Restaurant Sales/testing/model_fits'

# Ensure remote dirs exist (Linux target; skip if running against another Windows host)
ssh "godli@$WSL_IP" "mkdir -p '/mnt/d/HSFL/Restaurant Sales/testing/model_fits/finalized_redone_trunc_cp/t2_proportion/total'"

# 2 prop reruns
scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_proportion/total/vegan_dishes_prop" \
       "$REMOTE_BASE/finalized_redone_trunc_cp/t2_proportion/total/"
scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_proportion/total/vegetarian_dishes_count" \
       "$REMOTE_BASE/finalized_redone_trunc_cp/t2_proportion/total/"

# T2 customer day fits
scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_customer_gaussian_iid_day" \
       "$REMOTE_BASE/finalized_redone_trunc_cp/"
scp -r "$LOCAL_BASE/finalized_redone_trunc_cp/t2_customer_targeted_gaussian_iid_day" \
       "$REMOTE_BASE/finalized_redone_trunc_cp/"

echo "Done."
