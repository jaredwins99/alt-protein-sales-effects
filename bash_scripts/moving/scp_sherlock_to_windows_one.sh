#!/bin/bash
# Selective pull of a SINGLE fit dir from Sherlock $SCRATCH/model_fits to
# the Windows laptop. Run from Git Bash on the laptop.
#
# Usage:
#   bash publication/scp_sherlock_to_windows_one.sh <relative_fit_path>
#
# Example (the most recently finished total model):
#   bash publication/scp_sherlock_to_windows_one.sh \
#        finalized_redone_trunc_cp/a3_its/total

set -e
REL="${1:?usage: $0 <relative_fit_path>  e.g. finalized_redone_trunc_cp/a3_its/total}"

SHERLOCK=jaredwin@login.sherlock.stanford.edu
REMOTE_BASE=/scratch/users/jaredwin/model_fits
LOCAL_BASE="/c/Users/godli/Desktop/HSFL/Restaurant Sales/model_fits"

mkdir -p "$(dirname "$LOCAL_BASE/$REL")"

scp -r "$SHERLOCK:$REMOTE_BASE/$REL" \
       "$(dirname "$LOCAL_BASE/$REL")/"

echo "Pulled $REL"
