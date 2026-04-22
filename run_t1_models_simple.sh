#!/bin/bash
# Batch script to run T1 simple models (no predictors, no lags) A1-A6 in tmux sessions

cd /home/godli/testing

# A1: proportion (36 models)
tmux new-session -d -s S_A1_c_f_o_m_c "Rscript model_starters_simple/a1_proportion/A1_chicken_fish_on_mpbamod_count.R 2>&1 | tee logs/S_A1_c_f_o_m_c.log"
tmux new-session -d -s S_A1_c_f_o_m_p "Rscript model_starters_simple/a1_proportion/A1_chicken_fish_on_mpbamod_prop.R 2>&1 | tee logs/S_A1_c_f_o_m_p.log"
tmux new-session -d -s S_A1_c_f_o_v_c "Rscript model_starters_simple/a1_proportion/A1_chicken_fish_on_vegan_count.R 2>&1 | tee logs/S_A1_c_f_o_v_c.log"
tmux new-session -d -s S_A1_c_f_o_v_p "Rscript model_starters_simple/a1_proportion/A1_chicken_fish_on_vegan_prop.R 2>&1 | tee logs/S_A1_c_f_o_v_p.log"
tmux new-session -d -s S_A1_c_f_o_vn_c "Rscript model_starters_simple/a1_proportion/A1_chicken_fish_on_vegetarian_count.R 2>&1 | tee logs/S_A1_c_f_o_vn_c.log"
tmux new-session -d -s S_A1_c_f_o_vn_p "Rscript model_starters_simple/a1_proportion/A1_chicken_fish_on_vegetarian_prop.R 2>&1 | tee logs/S_A1_c_f_o_vn_p.log"
tmux new-session -d -s S_A1_m_o_m_c "Rscript model_starters_simple/a1_proportion/A1_meat_on_mpbamod_count.R 2>&1 | tee logs/S_A1_m_o_m_c.log"
tmux new-session -d -s S_A1_m_o_m_p "Rscript model_starters_simple/a1_proportion/A1_meat_on_mpbamod_prop.R 2>&1 | tee logs/S_A1_m_o_m_p.log"
tmux new-session -d -s S_A1_m_o_v_c "Rscript model_starters_simple/a1_proportion/A1_meat_on_vegan_count.R 2>&1 | tee logs/S_A1_m_o_v_c.log"
tmux new-session -d -s S_A1_m_o_v_p "Rscript model_starters_simple/a1_proportion/A1_meat_on_vegan_prop.R 2>&1 | tee logs/S_A1_m_o_v_p.log"
tmux new-session -d -s S_A1_m_o_vn_c "Rscript model_starters_simple/a1_proportion/A1_meat_on_vegetarian_count.R 2>&1 | tee logs/S_A1_m_o_vn_c.log"
tmux new-session -d -s S_A1_m_o_vn_p "Rscript model_starters_simple/a1_proportion/A1_meat_on_vegetarian_prop.R 2>&1 | tee logs/S_A1_m_o_vn_p.log"
tmux new-session -d -s S_A1_n_o_m_c "Rscript model_starters_simple/a1_proportion/A1_nonvegan_on_mpbamod_count.R 2>&1 | tee logs/S_A1_n_o_m_c.log"
tmux new-session -d -s S_A1_n_o_m_p "Rscript model_starters_simple/a1_proportion/A1_nonvegan_on_mpbamod_prop.R 2>&1 | tee logs/S_A1_n_o_m_p.log"
tmux new-session -d -s S_A1_n_o_v_c "Rscript model_starters_simple/a1_proportion/A1_nonvegan_on_vegan_count.R 2>&1 | tee logs/S_A1_n_o_v_c.log"
tmux new-session -d -s S_A1_n_o_v_p "Rscript model_starters_simple/a1_proportion/A1_nonvegan_on_vegan_prop.R 2>&1 | tee logs/S_A1_n_o_v_p.log"
tmux new-session -d -s S_A1_n_o_vn_c "Rscript model_starters_simple/a1_proportion/A1_nonvegan_on_vegetarian_count.R 2>&1 | tee logs/S_A1_n_o_vn_c.log"
tmux new-session -d -s S_A1_n_o_vn_p "Rscript model_starters_simple/a1_proportion/A1_nonvegan_on_vegetarian_prop.R 2>&1 | tee logs/S_A1_n_o_vn_p.log"
tmux new-session -d -s S_A1_t_o_m_c "Rscript model_starters_simple/a1_proportion/A1_total_on_mpbamod_count.R 2>&1 | tee logs/S_A1_t_o_m_c.log"
tmux new-session -d -s S_A1_t_o_m_p "Rscript model_starters_simple/a1_proportion/A1_total_on_mpbamod_prop.R 2>&1 | tee logs/S_A1_t_o_m_p.log"
tmux new-session -d -s S_A1_t_o_v_c "Rscript model_starters_simple/a1_proportion/A1_total_on_vegan_count.R 2>&1 | tee logs/S_A1_t_o_v_c.log"
tmux new-session -d -s S_A1_t_o_v_p "Rscript model_starters_simple/a1_proportion/A1_total_on_vegan_prop.R 2>&1 | tee logs/S_A1_t_o_v_p.log"
tmux new-session -d -s S_A1_t_o_vn_c "Rscript model_starters_simple/a1_proportion/A1_total_on_vegetarian_count.R 2>&1 | tee logs/S_A1_t_o_vn_c.log"
tmux new-session -d -s S_A1_t_o_vn_p "Rscript model_starters_simple/a1_proportion/A1_total_on_vegetarian_prop.R 2>&1 | tee logs/S_A1_t_o_vn_p.log"
tmux new-session -d -s S_A1_v_o_m_c "Rscript model_starters_simple/a1_proportion/A1_vegan_on_mpbamod_count.R 2>&1 | tee logs/S_A1_v_o_m_c.log"
tmux new-session -d -s S_A1_v_o_m_p "Rscript model_starters_simple/a1_proportion/A1_vegan_on_mpbamod_prop.R 2>&1 | tee logs/S_A1_v_o_m_p.log"
tmux new-session -d -s S_A1_v_o_v_c "Rscript model_starters_simple/a1_proportion/A1_vegan_on_vegan_count.R 2>&1 | tee logs/S_A1_v_o_v_c.log"
tmux new-session -d -s S_A1_v_o_v_p "Rscript model_starters_simple/a1_proportion/A1_vegan_on_vegan_prop.R 2>&1 | tee logs/S_A1_v_o_v_p.log"
tmux new-session -d -s S_A1_v_o_vn_c "Rscript model_starters_simple/a1_proportion/A1_vegan_on_vegetarian_count.R 2>&1 | tee logs/S_A1_v_o_vn_c.log"
tmux new-session -d -s S_A1_v_o_vn_p "Rscript model_starters_simple/a1_proportion/A1_vegan_on_vegetarian_prop.R 2>&1 | tee logs/S_A1_v_o_vn_p.log"
tmux new-session -d -s S_A1_vn_o_m_c "Rscript model_starters_simple/a1_proportion/A1_vegetarian_on_mpbamod_count.R 2>&1 | tee logs/S_A1_vn_o_m_c.log"
tmux new-session -d -s S_A1_vn_o_m_p "Rscript model_starters_simple/a1_proportion/A1_vegetarian_on_mpbamod_prop.R 2>&1 | tee logs/S_A1_vn_o_m_p.log"
tmux new-session -d -s S_A1_vn_o_v_c "Rscript model_starters_simple/a1_proportion/A1_vegetarian_on_vegan_count.R 2>&1 | tee logs/S_A1_vn_o_v_c.log"
tmux new-session -d -s S_A1_vn_o_v_p "Rscript model_starters_simple/a1_proportion/A1_vegetarian_on_vegan_prop.R 2>&1 | tee logs/S_A1_vn_o_v_p.log"
tmux new-session -d -s S_A1_vn_o_vn_c "Rscript model_starters_simple/a1_proportion/A1_vegetarian_on_vegetarian_count.R 2>&1 | tee logs/S_A1_vn_o_vn_c.log"
tmux new-session -d -s S_A1_vn_o_vn_p "Rscript model_starters_simple/a1_proportion/A1_vegetarian_on_vegetarian_prop.R 2>&1 | tee logs/S_A1_vn_o_vn_p.log"

# A2: a2_proportion_t (10 models)
tmux new-session -d -s S_A2_b_c "Rscript model_starters_simple/a2_proportion_t/A2_breakfast_count.R 2>&1 | tee logs/S_A2_b_c.log"
tmux new-session -d -s S_A2_b_p "Rscript model_starters_simple/a2_proportion_t/A2_breakfast_presence.R 2>&1 | tee logs/S_A2_b_p.log"
tmux new-session -d -s S_A2_u_c "Rscript model_starters_simple/a2_proportion_t/A2_untextured_count.R 2>&1 | tee logs/S_A2_u_c.log"
tmux new-session -d -s S_A2_u_p "Rscript model_starters_simple/a2_proportion_t/A2_untextured_presence.R 2>&1 | tee logs/S_A2_u_p.log"
tmux new-session -d -s S_A2_c_c "Rscript model_starters_simple/a2_proportion_t/A2_chicken_count.R 2>&1 | tee logs/S_A2_c_c.log"
tmux new-session -d -s S_A2_c_p "Rscript model_starters_simple/a2_proportion_t/A2_chicken_presence.R 2>&1 | tee logs/S_A2_c_p.log"
tmux new-session -d -s S_A2_d_c "Rscript model_starters_simple/a2_proportion_t/A2_dairy_count.R 2>&1 | tee logs/S_A2_d_c.log"
tmux new-session -d -s S_A2_d_p "Rscript model_starters_simple/a2_proportion_t/A2_dairy_presence.R 2>&1 | tee logs/S_A2_d_p.log"
tmux new-session -d -s S_A2_e_c "Rscript model_starters_simple/a2_proportion_t/A2_egg_count.R 2>&1 | tee logs/S_A2_e_c.log"
tmux new-session -d -s S_A2_e_p "Rscript model_starters_simple/a2_proportion_t/A2_egg_presence.R 2>&1 | tee logs/S_A2_e_p.log"
tmux new-session -d -s S_A2_t_c "Rscript model_starters_simple/a2_proportion_t/A2_textured_count.R 2>&1 | tee logs/S_A2_t_c.log"
tmux new-session -d -s S_A2_t_p "Rscript model_starters_simple/a2_proportion_t/A2_textured_presence.R 2>&1 | tee logs/S_A2_t_p.log"

# A3: its (6 models)
tmux new-session -d -s S_A3_c_f "Rscript model_starters_simple/a3_its/A3_chicken_fish.R 2>&1 | tee logs/S_A3_c_f.log"
tmux new-session -d -s S_A3_m "Rscript model_starters_simple/a3_its/A3_meat.R 2>&1 | tee logs/S_A3_m.log"
tmux new-session -d -s S_A3_n "Rscript model_starters_simple/a3_its/A3_nonvegan.R 2>&1 | tee logs/S_A3_n.log"
tmux new-session -d -s S_A3_t "Rscript model_starters_simple/a3_its/A3_total.R 2>&1 | tee logs/S_A3_t.log"
tmux new-session -d -s S_A3_v "Rscript model_starters_simple/a3_its/A3_vegan.R 2>&1 | tee logs/S_A3_v.log"
tmux new-session -d -s S_A3_vn "Rscript model_starters_simple/a3_its/A3_vegetarian.R 2>&1 | tee logs/S_A3_vn.log"

# A4: a4_its_t (3 models)
tmux new-session -d -s S_A4_b "Rscript model_starters_simple/a4_its_t/A4_breakfast.R 2>&1 | tee logs/S_A4_b.log"
tmux new-session -d -s S_A4_t "Rscript model_starters_simple/a4_its_t/A4_textured.R 2>&1 | tee logs/S_A4_t.log"
tmux new-session -d -s S_A4_u "Rscript model_starters_simple/a4_its_t/A4_untextured.R 2>&1 | tee logs/S_A4_u.log"

# A5: customer (6 models)
tmux new-session -d -s S_A5_c_f "Rscript model_starters_simple/customer/A5_chicken_fish.R 2>&1 | tee logs/S_A5_c_f.log"
tmux new-session -d -s S_A5_m "Rscript model_starters_simple/customer/A5_meat.R 2>&1 | tee logs/S_A5_m.log"
tmux new-session -d -s S_A5_n "Rscript model_starters_simple/customer/A5_nonvegan.R 2>&1 | tee logs/S_A5_n.log"
tmux new-session -d -s S_A5_t "Rscript model_starters_simple/customer/A5_total.R 2>&1 | tee logs/S_A5_t.log"
tmux new-session -d -s S_A5_v "Rscript model_starters_simple/customer/A5_vegan.R 2>&1 | tee logs/S_A5_v.log"
tmux new-session -d -s S_A5_vn "Rscript model_starters_simple/customer/A5_vegetarian.R 2>&1 | tee logs/S_A5_vn.log"

# A6: customer_targeted (2 models)
tmux new-session -d -s S_A6_b "Rscript model_starters_simple/customer_targeted/A6_breakfast.R 2>&1 | tee logs/S_A6_b.log"
tmux new-session -d -s S_A6_u "Rscript model_starters_simple/customer_targeted/A6_untextured.R 2>&1 | tee logs/S_A6_u.log"

echo "To list sessions: tmux ls"
echo "To attach to a session: tmux attach -t <session_name>"
echo "To kill all sessions: tmux kill-server"
