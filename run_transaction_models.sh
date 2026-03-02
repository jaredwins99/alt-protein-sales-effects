#!/bin/bash
# Batch script to run transaction-level conditional Poisson models (A5) in tmux sessions

cd /home/researcher/Documents/Jared/Other/testing

# A5 Transaction: customer conditional Poisson (6 models)
tmux new-session -d -s A5T_t "Rscript model_starters/customer/A5_transaction_total.R 2>&1 | tee logs/A5T_t.log"
# tmux new-session -d -s A5T_v "Rscript model_starters/customer/A5_transaction_vegan.R 2>&1 | tee logs/A5T_v.log"
# tmux new-session -d -s A5T_vn "Rscript model_starters/customer/A5_transaction_vegetarian.R 2>&1 | tee logs/A5T_vn.log"
# tmux new-session -d -s A5T_n "Rscript model_starters/customer/A5_transaction_nonvegan.R 2>&1 | tee logs/A5T_n.log"
# tmux new-session -d -s A5T_m "Rscript model_starters/customer/A5_transaction_meat.R 2>&1 | tee logs/A5T_m.log"
# tmux new-session -d -s A5T_c_f "Rscript model_starters/customer/A5_transaction_chicken_fish.R 2>&1 | tee logs/A5T_c_f.log"

echo "To list sessions: tmux ls"
echo "To attach to a session: tmux attach -t <session_name>"
echo "To kill all sessions: tmux kill-server"
