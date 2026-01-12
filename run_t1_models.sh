#!/bin/bash
# Batch script to run T1 models A1-A6 in tmux sessions
# Total: 63 models × 3 chains = 189 cores

cd /home/researcher/Documents/Jared/Other/testing

# # A1: proportion (36 models)
## tmux new-session -d -s A1_c_f_o_m_c "Rscript model_starters/proportion/A1_chicken_fish_on_mpbamod_count.R 2>&1 | tee logs/A1_c_f_o_m_c.log"
## tmux new-session -d -s A1_c_f_o_m_p "Rscript model_starters/proportion/A1_chicken_fish_on_mpbamod_prop.R 2>&1 | tee logs/A1_c_f_o_m_p.log"
## tmux new-session -d -s A1_c_f_o_v_c "Rscript model_starters/proportion/A1_chicken_fish_on_vegan_count.R 2>&1 | tee logs/A1_c_f_o_v_c.log"
## tmux new-session -d -s A1_c_f_o_v_p "Rscript model_starters/proportion/A1_chicken_fish_on_vegan_prop.R 2>&1 | tee logs/A1_c_f_o_v_p.log"
## tmux new-session -d -s A1_c_f_o_vn_c "Rscript model_starters/proportion/A1_chicken_fish_on_vegetarian_count.R 2>&1 | tee logs/A1_c_f_o_v_c.log"
## tmux new-session -d -s A1_c_f_o_vn_p "Rscript model_starters/proportion/A1_chicken_fish_on_vegetarian_prop.R 2>&1 | tee logs/A1_c_f_o_v_p.log"
## tmux new-session -d -s A1_m_o_m_c "Rscript model_starters/proportion/A1_meat_on_mpbamod_count.R 2>&1 | tee logs/A1_m_o_m_c.log"
## tmux new-session -d -s A1_m_o_m_p "Rscript model_starters/proportion/A1_meat_on_mpbamod_prop.R 2>&1 | tee logs/A1_m_o_m_p.log"
## tmux new-session -d -s A1_m_o_v_c "Rscript model_starters/proportion/A1_meat_on_vegan_count.R 2>&1 | tee logs/A1_m_o_v_c.log"
## tmux new-session -d -s A1_m_o_v_p "Rscript model_starters/proportion/A1_meat_on_vegan_prop.R 2>&1 | tee logs/A1_m_o_v_p.log"
## tmux new-session -d -s A1_m_o_vn_c "Rscript model_starters/proportion/A1_meat_on_vegetarian_count.R 2>&1 | tee logs/A1_m_o_v_c.log"
## tmux new-session -d -s A1_m_o_vn_p "Rscript model_starters/proportion/A1_meat_on_vegetarian_prop.R 2>&1 | tee logs/A1_m_o_v_p.log"
## tmux new-session -d -s A1_n_o_m_c "Rscript model_starters/proportion/A1_nonvegan_on_mpbamod_count.R 2>&1 | tee logs/A1_n_o_m_c.log"
## tmux new-session -d -s A1_n_o_m_p "Rscript model_starters/proportion/A1_nonvegan_on_mpbamod_prop.R 2>&1 | tee logs/A1_n_o_m_p.log"
## tmux new-session -d -s A1_n_o_v_c "Rscript model_starters/proportion/A1_nonvegan_on_vegan_count.R 2>&1 | tee logs/A1_n_o_v_c.log"
## tmux new-session -d -s A1_n_o_v_p "Rscript model_starters/proportion/A1_nonvegan_on_vegan_prop.R 2>&1 | tee logs/A1_n_o_v_p.log"
## tmux new-session -d -s A1_n_o_vn_c "Rscript model_starters/proportion/A1_nonvegan_on_vegetarian_count.R 2>&1 | tee logs/A1_n_o_v_c.log"
## tmux new-session -d -s A1_n_o_vn_p "Rscript model_starters/proportion/A1_nonvegan_on_vegetarian_prop.R 2>&1 | tee logs/A1_n_o_v_p.log"
## tmux new-session -d -s A1_t_o_m_c "Rscript model_starters/proportion/A1_total_on_mpbamod_count.R 2>&1 | tee logs/A1_t_o_m_c.log"
## tmux new-session -d -s A1_t_o_m_p "Rscript model_starters/proportion/A1_total_on_mpbamod_prop.R 2>&1 | tee logs/A1_t_o_m_p.log"
## tmux new-session -d -s A1_t_o_v_c "Rscript model_starters/proportion/A1_total_on_vegan_count.R 2>&1 | tee logs/A1_t_o_v_c.log"
## tmux new-session -d -s A1_t_o_v_p "Rscript model_starters/proportion/A1_total_on_vegan_prop.R 2>&1 | tee logs/A1_t_o_v_p.log"
## tmux new-session -d -s A1_t_o_vn_c "Rscript model_starters/proportion/A1_total_on_vegetarian_count.R 2>&1 | tee logs/A1_t_o_v_c.log"
## tmux new-session -d -s A1_t_o_vn_p "Rscript model_starters/proportion/A1_total_on_vegetarian_prop.R 2>&1 | tee logs/A1_t_o_v_p.log"
## tmux new-session -d -s A1_v_o_m_c "Rscript model_starters/proportion/A1_vegan_on_mpbamod_count.R 2>&1 | tee logs/A1_v_o_m_c.log"
## tmux new-session -d -s A1_v_o_m_p "Rscript model_starters/proportion/A1_vegan_on_mpbamod_prop.R 2>&1 | tee logs/A1_v_o_m_p.log"
## tmux new-session -d -s A1_v_o_v_c "Rscript model_starters/proportion/A1_vegan_on_vegan_count.R 2>&1 | tee logs/A1_v_o_v_c.log"
## tmux new-session -d -s A1_v_o_v_p "Rscript model_starters/proportion/A1_vegan_on_vegan_prop.R 2>&1 | tee logs/A1_v_o_v_p.log"
## tmux new-session -d -s A1_v_o_vn_c "Rscript model_starters/proportion/A1_vegan_on_vegetarian_count.R 2>&1 | tee logs/A1_v_o_v_c.log"
## tmux new-session -d -s A1_v_o_vn_p "Rscript model_starters/proportion/A1_vegan_on_vegetarian_prop.R 2>&1 | tee logs/A1_v_o_v_p.log"
## tmux new-session -d -s A1_vn_o_m_c "Rscript model_starters/proportion/A1_vegetarian_on_mpbamod_count.R 2>&1 | tee logs/A1_v_o_m_c.log"
## tmux new-session -d -s A1_vn_o_m_p "Rscript model_starters/proportion/A1_vegetarian_on_mpbamod_prop.R 2>&1 | tee logs/A1_v_o_m_p.log"
## tmux new-session -d -s A1_vn_o_v_c "Rscript model_starters/proportion/A1_vegetarian_on_vegan_count.R 2>&1 | tee logs/A1_v_o_v_c.log"
## tmux new-session -d -s A1_vn_o_v_p "Rscript model_starters/proportion/A1_vegetarian_on_vegan_prop.R 2>&1 | tee logs/A1_v_o_v_p.log"
## tmux new-session -d -s A1_vn_o_vn_c "Rscript model_starters/proportion/A1_vegetarian_on_vegetarian_count.R 2>&1 | tee logs/A1_v_o_v_c.log"
## tmux new-session -d -s A1_vn_o_vn_p "Rscript model_starters/proportion/A1_vegetarian_on_vegetarian_prop.R 2>&1 | tee logs/A1_v_o_v_p.log"

# A2: proportion_targeted (10 models)
## tmux new-session -d -s A2_b_c "Rscript model_starters/proportion_targeted/A2_breakfast_count.R 2>&1 | tee logs/A2_b_c.log"
## tmux new-session -d -s A2_b_p "Rscript model_starters/proportion_targeted/A2_breakfast_presence.R 2>&1 | tee logs/A2_b_p.log"
## tmux new-session -d -s A2_u_c "Rscript model_starters/proportion_targeted/A2_untextured_count.R 2>&1 | tee logs/A2_u_c.log"
## tmux new-session -d -s A2_u_p "Rscript model_starters/proportion_targeted/A2_untextured_presence.R 2>&1 | tee logs/A2_u_p.log"
## tmux new-session -d -s A2_c_c "Rscript model_starters/proportion_targeted/A2_chicken_count.R 2>&1 | tee logs/A2_c_c.log"
## tmux new-session -d -s A2_c_p "Rscript model_starters/proportion_targeted/A2_chicken_presence.R 2>&1 | tee logs/A2_c_p.log"
## tmux new-session -d -s A2_d_c "Rscript model_starters/proportion_targeted/A2_dairy_count.R 2>&1 | tee logs/A2_d_c.log"
## tmux new-session -d -s A2_d_p "Rscript model_starters/proportion_targeted/A2_dairy_presence.R 2>&1 | tee logs/A2_d_p.log"
## tmux new-session -d -s A2_e_c "Rscript model_starters/proportion_targeted/A2_egg_count.R 2>&1 | tee logs/A2_e_c.log"
## tmux new-session -d -s A2_e_p "Rscript model_starters/proportion_targeted/A2_egg_presence.R 2>&1 | tee logs/A2_e_p.log"

# # A3: its (6 models)
## tmux new-session -d -s A3_c_f "Rscript model_starters/its/A3_chicken_fish.R 2>&1 | tee logs/A3_c_f.log"
## tmux new-session -d -s A3_m "Rscript model_starters/its/A3_meat.R 2>&1 | tee logs/A3_m.log"
## tmux new-session -d -s A3_n "Rscript model_starters/its/A3_nonvegan.R 2>&1 | tee logs/A3_n.log"
## tmux new-session -d -s A3_t "Rscript model_starters/its/A3_total.R 2>&1 | tee logs/A3_t.log"
## tmux new-session -d -s A3_v "Rscript model_starters/its/A3_vegan.R 2>&1 | tee logs/A3_v.log"
## tmux new-session -d -s A3_vn "Rscript model_starters/its/A3_vegetarian.R 2>&1 | tee logs/A3_v.log"

# # A4: its_targeted (3 models)
## tmux new-session -d -s A4_b "Rscript model_starters/its_targeted/A4_breakfast.R 2>&1 | tee logs/A4_b.log"
## tmux new-session -d -s A4_t "Rscript model_starters/its_targeted/A4_textured.R 2>&1 | tee logs/A4_t.log"
## tmux new-session -d -s A4_u "Rscript model_starters/its_targeted/A4_untextured.R 2>&1 | tee logs/A4_u.log"

# A5: customer (6 models)
# tmux new-session -d -s A5_c_f "Rscript model_starters/customer/A5_chicken_fish.R 2>&1 | tee logs/A5_c_f.log"
# tmux new-session -d -s A5_m "Rscript model_starters/customer/A5_meat.R 2>&1 | tee logs/A5_m.log"
# tmux new-session -d -s A5_n "Rscript model_starters/customer/A5_nonvegan.R 2>&1 | tee logs/A5_n.log"
# tmux new-session -d -s A5_t "Rscript model_starters/customer/A5_total.R 2>&1 | tee logs/A5_t.log"
# tmux new-session -d -s A5_v "Rscript model_starters/customer/A5_vegan.R 2>&1 | tee logs/A5_v.log"
# tmux new-session -d -s A5_v "Rscript model_starters/customer/A5_vegetarian.R 2>&1 | tee logs/A5_v.log"

# A6: customer_targeted (2 models)
# tmux new-session -d -s A6_b "Rscript model_starters/customer_targeted/A6_breakfast.R 2>&1 | tee logs/A6_b.log"
# tmux new-session -d -s A6_u "Rscript model_starters/customer_targeted/A6_untextured.R 2>&1 | tee logs/A6_u.log"

echo "Started 25 tmux sessions (A1-A6 T1 models)"
echo "Using 75 cores (25 models × 3 chains)"
echo ""
echo "To list sessions: tmux ls"
echo "To attach to a session: tmux attach -t <session_name>"
echo "To kill all sessions: tmux kill-server"
