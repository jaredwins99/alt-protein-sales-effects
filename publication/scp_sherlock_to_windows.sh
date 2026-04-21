#!/bin/bash
# Selective pull from Sherlock $SCRATCH/model_fits onto Windows.
# Only transfers the 2 outstanding prop reruns + all T2 customer day fits.
# Run from Windows (e.g. Git Bash).

SHERLOCK=jaredwin@login.sherlock.stanford.edu
REMOTE_BASE=/scratch/users/jaredwin/model_fits
LOCAL_BASE="C:\Users\godli\Desktop\HSFL\Restaurant Sales\model_fits"

# Make sure parent dirs exist locally
mkdir -p "$LOCAL_BASE/finalized_redone_trunc_cp/t2_proportion/total"
mkdir -p "$LOCAL_BASE/finalized_redone_trunc_cp"

# 2 prop reruns — already transferred, commented out
# scp -r "$SHERLOCK:$REMOTE_BASE/finalized_redone_trunc_cp/t2_proportion/total/vegan_dishes_prop" \
#        "$LOCAL_BASE/finalized_redone_trunc_cp/t2_proportion/total/"
# scp -r "$SHERLOCK:$REMOTE_BASE/finalized_redone_trunc_cp/t2_proportion/total/vegetarian_dishes_count" \
#        "$LOCAL_BASE/finalized_redone_trunc_cp/t2_proportion/total/"

# T2 A5 customer day (all outcomes that finished)
scp -r "$SHERLOCK:$REMOTE_BASE/finalized_redone_trunc_cp/t2_customer_gaussian_iid_day" \
       "$LOCAL_BASE/finalized_redone_trunc_cp/"

# T2 A6 customer targeted day (all categories that finished)
scp -r "$SHERLOCK:$REMOTE_BASE/finalized_redone_trunc_cp/t2_customer_targeted_gaussian_iid_day" \
       "$LOCAL_BASE/finalized_redone_trunc_cp/"

echo "Done."
