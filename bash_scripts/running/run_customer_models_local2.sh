#!/bin/bash
# Resume customer model runs after tmux died.
# vegetarian: will load existing fit.rds and just regen metadata/plots.
set -u
mkdir -p logs

STARTERS=(
    "model_starters/t2_customer/A5_T2_vegetarian.R"
    "model_starters/t2_customer/A5_T2_nonvegan.R"
    "model_starters/t2_customer/A5_T2_meat.R"
    "model_starters/t2_customer/A5_T2_chicken_fish.R"
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
