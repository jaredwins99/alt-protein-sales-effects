#!/bin/bash
cd /home/godli/testing
S=archive/logs/a6run
: > "$S/status.txt"
SCRIPTS=(
 model_starters/customer_targeted/A6_breakfast.R
 model_starters/customer_targeted/A6_untextured.R
 model_starters/t2_customer_targeted/A6_T2_breakfast.R
 model_starters/t2_customer_targeted/A6_T2_dairy.R
 model_starters/t2_customer_targeted/A6_T2_textured.R
 model_starters/t2_customer_targeted/A6_T2_untextured.R
 model_starters/customer_targeted_transaction/A6_breakfast.R
 model_starters/customer_targeted_transaction/A6_untextured.R
 model_starters/t2_customer_targeted_transaction/A6_T2_breakfast.R
 model_starters/t2_customer_targeted_transaction/A6_T2_dairy.R
 model_starters/t2_customer_targeted_transaction/A6_T2_textured.R
 model_starters/t2_customer_targeted_transaction/A6_T2_untextured.R
)
for s in "${SCRIPTS[@]}"; do
  tag=$(echo "$s" | cut -d/ -f2-3 | tr '/' '_' | sed 's/\.R$//')
  t0=$(date +%s)
  Rscript "$s" > "$S/$tag.log" 2>&1
  rc=$?
  el=$(( ($(date +%s) - t0) / 60 ))
  if [ $rc -eq 137 ]; then st=OOM; elif [ $rc -ne 0 ]; then st="FAIL(rc=$rc)"; else st=OK; fi
  printf "%-46s %-12s %3dmin\n" "$tag" "$st" "$el" >> "$S/status.txt"
  [ "$st" = "OOM" ] && { echo ABORTED_ON_OOM >> "$S/status.txt"; exit 137; }
done
echo DONE >> "$S/status.txt"
