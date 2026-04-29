#!/bin/bash
# Run all customer day-level models sequentially.
# Logs go to archive/logs/local_customer_<starter>.log
set -u
mkdir -p logs

STARTERS=(
    # A5 T1 untargeted (6)
    "model_starters/customer/A5_total.R"
    "model_starters/customer/A5_vegan.R"
    "model_starters/customer/A5_vegetarian.R"
    "model_starters/customer/A5_nonvegan.R"
    "model_starters/customer/A5_meat.R"
    "model_starters/customer/A5_chicken_fish.R"
    # A6 T1 targeted (2)
    "model_starters/customer_targeted/A6_breakfast.R"
    "model_starters/customer_targeted/A6_untextured.R"
    # A5 T2 untargeted (6)
    "model_starters/t2_customer/A5_T2_total.R"
    "model_starters/t2_customer/A5_T2_vegan.R"
    "model_starters/t2_customer/A5_T2_vegetarian.R"
    "model_starters/t2_customer/A5_T2_nonvegan.R"
    "model_starters/t2_customer/A5_T2_meat.R"
    "model_starters/t2_customer/A5_T2_chicken_fish.R"
    # A6 T2 targeted (5)
    "model_starters/t2_customer_targeted/A6_T2_breakfast.R"
    "model_starters/t2_customer_targeted/A6_T2_untextured.R"
    "model_starters/t2_customer_targeted/A6_T2_chicken.R"
    "model_starters/t2_customer_targeted/A6_T2_dairy.R"
    "model_starters/t2_customer_targeted/A6_T2_textured.R"
)

TOTAL=${#STARTERS[@]}
i=0
for s in "${STARTERS[@]}"; do
    i=$((i+1))
    name=$(basename "$s" .R)
    log="archive/logs/local_customer_${name}.log"
    echo "==================================================================="
    echo "[$i/$TOTAL] $(date '+%F %T')  RUN  $s"
    echo "         log: $log"
    echo "==================================================================="
    /usr/bin/time -v Rscript "$s" > "$log" 2>&1
    rc=$?
    echo "[$i/$TOTAL] $(date '+%F %T')  EXIT=$rc  $s"
    if [ $rc -ne 0 ]; then
        echo "  !! FAILED — see $log"
    fi
done
echo "==================================================================="
echo "ALL DONE  $(date '+%F %T')"
echo "==================================================================="
