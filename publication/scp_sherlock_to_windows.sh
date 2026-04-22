#!/bin/bash
# Selective pull from Sherlock $SCRATCH/model_fits onto Windows.
# Only transfers the 2 outstanding prop reruns + all T2 customer day fits.
# Run from Windows (e.g. Git Bash).

SHERLOCK=jaredwin@login.sherlock.stanford.edu
REMOTE_BASE=/scratch/users/jaredwin/model_fits
# Git Bash style local path (forward slashes; scp handles these cleanly)
LOCAL_BASE="/c/Users/godli/Desktop/HSFL/Restaurant Sales/model_fits"

mkdir -p "$LOCAL_BASE/finalized_redone_trunc_cp2/t2_proportion/total"
mkdir -p "$LOCAL_BASE/finalized_redone_trunc_cp2"

# 2 prop reruns on Sherlock (completed 2026-04-18 and 2026-04-20)
scp -r "$SHERLOCK:$REMOTE_BASE/finalized_redone_trunc_cp2/t2_proportion/total/vegan_dishes_prop" \
       "$LOCAL_BASE/finalized_redone_trunc_cp2/t2_proportion/total/"
scp -r "$SHERLOCK:$REMOTE_BASE/finalized_redone_trunc_cp2/t2_proportion/total/vegetarian_dishes_count" \
       "$LOCAL_BASE/finalized_redone_trunc_cp2/t2_proportion/total/"

# T2 A5 customer day (all outcomes that finished on Sherlock)
scp -r "$SHERLOCK:$REMOTE_BASE/finalized_redone_trunc_cp2/t2_customer_gaussian_iid_day" \
       "$LOCAL_BASE/finalized_redone_trunc_cp2/"

# T2 A6 customer targeted day (all categories that finished on Sherlock)
scp -r "$SHERLOCK:$REMOTE_BASE/finalized_redone_trunc_cp2/t2_customer_targeted_gaussian_iid_day" \
       "$LOCAL_BASE/finalized_redone_trunc_cp2/"

echo "Done."
