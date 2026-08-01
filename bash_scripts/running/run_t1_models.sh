#!/bin/bash
# Batch script to run T1 models A1-A6 in tmux sessions

cd /home/godli/testing

# A1: proportion (36 models)
## tmux new-session -d -s A1_c_f_o_m_c "Rscript model_starters/a1_proportion/A1_chicken_fish_on_mpbamod_count.R 2>&1 | tee archive/logs/A1_c_f_o_m_c.log"
## tmux new-session -d -s A1_c_f_o_m_p "Rscript model_starters/a1_proportion/A1_chicken_fish_on_mpbamod_prop.R 2>&1 | tee archive/logs/A1_c_f_o_m_p.log"
## tmux new-session -d -s A1_c_f_o_v_c "Rscript model_starters/a1_proportion/A1_chicken_fish_on_vegan_count.R 2>&1 | tee archive/logs/A1_c_f_o_v_c.log"
## tmux new-session -d -s A1_c_f_o_v_p "Rscript model_starters/a1_proportion/A1_chicken_fish_on_vegan_prop.R 2>&1 | tee archive/logs/A1_c_f_o_v_p.log"
## tmux new-session -d -s A1_c_f_o_vn_c "Rscript model_starters/a1_proportion/A1_chicken_fish_on_vegetarian_count.R 2>&1 | tee archive/logs/A1_c_f_o_vn_c.log"
## tmux new-session -d -s A1_c_f_o_vn_p "Rscript model_starters/a1_proportion/A1_chicken_fish_on_vegetarian_prop.R 2>&1 | tee archive/logs/A1_c_f_o_vn_p.log"
## tmux new-session -d -s A1_m_o_m_c "Rscript model_starters/a1_proportion/A1_meat_on_mpbamod_count.R 2>&1 | tee archive/logs/A1_m_o_m_c.log"
## tmux new-session -d -s A1_m_o_m_p "Rscript model_starters/a1_proportion/A1_meat_on_mpbamod_prop.R 2>&1 | tee archive/logs/A1_m_o_m_p.log"
## tmux new-session -d -s A1_m_o_v_c "Rscript model_starters/a1_proportion/A1_meat_on_vegan_count.R 2>&1 | tee archive/logs/A1_m_o_v_c.log"
## tmux new-session -d -s A1_m_o_v_p "Rscript model_starters/a1_proportion/A1_meat_on_vegan_prop.R 2>&1 | tee archive/logs/A1_m_o_v_p.log"
## tmux new-session -d -s A1_m_o_vn_c "Rscript model_starters/a1_proportion/A1_meat_on_vegetarian_count.R 2>&1 | tee archive/logs/A1_m_o_vn_c.log"
## tmux new-session -d -s A1_m_o_vn_p "Rscript model_starters/a1_proportion/A1_meat_on_vegetarian_prop.R 2>&1 | tee archive/logs/A1_m_o_vn_p.log"
## tmux new-session -d -s A1_n_o_m_c "Rscript model_starters/a1_proportion/A1_nonvegan_on_mpbamod_count.R 2>&1 | tee archive/logs/A1_n_o_m_c.log"
## tmux new-session -d -s A1_n_o_m_p "Rscript model_starters/a1_proportion/A1_nonvegan_on_mpbamod_prop.R 2>&1 | tee archive/logs/A1_n_o_m_p.log"
## tmux new-session -d -s A1_n_o_v_c "Rscript model_starters/a1_proportion/A1_nonvegan_on_vegan_count.R 2>&1 | tee archive/logs/A1_n_o_v_c.log"
## tmux new-session -d -s A1_n_o_v_p "Rscript model_starters/a1_proportion/A1_nonvegan_on_vegan_prop.R 2>&1 | tee archive/logs/A1_n_o_v_p.log"
## tmux new-session -d -s A1_n_o_vn_c "Rscript model_starters/a1_proportion/A1_nonvegan_on_vegetarian_count.R 2>&1 | tee archive/logs/A1_n_o_vn_c.log"
## tmux new-session -d -s A1_n_o_vn_p "Rscript model_starters/a1_proportion/A1_nonvegan_on_vegetarian_prop.R 2>&1 | tee archive/logs/A1_n_o_vn_p.log"
## tmux new-session -d -s A1_t_o_m_c "Rscript model_starters/a1_proportion/A1_total_on_mpbamod_count.R 2>&1 | tee archive/logs/A1_t_o_m_c.log"
## tmux new-session -d -s A1_t_o_m_p "Rscript model_starters/a1_proportion/A1_total_on_mpbamod_prop.R 2>&1 | tee archive/logs/A1_t_o_m_p.log"
## tmux new-session -d -s A1_t_o_v_c "Rscript model_starters/a1_proportion/A1_total_on_vegan_count.R 2>&1 | tee archive/logs/A1_t_o_v_c.log"
## tmux new-session -d -s A1_t_o_v_p "Rscript model_starters/a1_proportion/A1_total_on_vegan_prop.R 2>&1 | tee archive/logs/A1_t_o_v_p.log"
## tmux new-session -d -s A1_t_o_vn_c "Rscript model_starters/a1_proportion/A1_total_on_vegetarian_count.R 2>&1 | tee archive/logs/A1_t_o_vn_c.log"
## tmux new-session -d -s A1_t_o_vn_p "Rscript model_starters/a1_proportion/A1_total_on_vegetarian_prop.R 2>&1 | tee archive/logs/A1_t_o_vn_p.log"
## tmux new-session -d -s A1_v_o_m_c "Rscript model_starters/a1_proportion/A1_vegan_on_mpbamod_count.R 2>&1 | tee archive/logs/A1_v_o_m_c.log"
## tmux new-session -d -s A1_v_o_m_p "Rscript model_starters/a1_proportion/A1_vegan_on_mpbamod_prop.R 2>&1 | tee archive/logs/A1_v_o_m_p.log"
## tmux new-session -d -s A1_v_o_v_c "Rscript model_starters/a1_proportion/A1_vegan_on_vegan_count.R 2>&1 | tee archive/logs/A1_v_o_v_c.log"
## tmux new-session -d -s A1_v_o_v_p "Rscript model_starters/a1_proportion/A1_vegan_on_vegan_prop.R 2>&1 | tee archive/logs/A1_v_o_v_p.log"
## tmux new-session -d -s A1_v_o_vn_c "Rscript model_starters/a1_proportion/A1_vegan_on_vegetarian_count.R 2>&1 | tee archive/logs/A1_v_o_vn_c.log"
## tmux new-session -d -s A1_v_o_vn_p "Rscript model_starters/a1_proportion/A1_vegan_on_vegetarian_prop.R 2>&1 | tee archive/logs/A1_v_o_vn_p.log"
## tmux new-session -d -s A1_vn_o_m_c "Rscript model_starters/a1_proportion/A1_vegetarian_on_mpbamod_count.R 2>&1 | tee archive/logs/A1_vn_o_m_c.log"
## tmux new-session -d -s A1_vn_o_m_p "Rscript model_starters/a1_proportion/A1_vegetarian_on_mpbamod_prop.R 2>&1 | tee archive/logs/A1_vn_o_m_p.log"
## tmux new-session -d -s A1_vn_o_v_c "Rscript model_starters/a1_proportion/A1_vegetarian_on_vegan_count.R 2>&1 | tee archive/logs/A1_vn_o_v_c.log"
## tmux new-session -d -s A1_vn_o_v_p "Rscript model_starters/a1_proportion/A1_vegetarian_on_vegan_prop.R 2>&1 | tee archive/logs/A1_vn_o_v_p.log"
## tmux new-session -d -s A1_vn_o_vn_c "Rscript model_starters/a1_proportion/A1_vegetarian_on_vegetarian_count.R 2>&1 | tee archive/logs/A1_vn_o_vn_c.log"
## tmux new-session -d -s A1_vn_o_vn_p "Rscript model_starters/a1_proportion/A1_vegetarian_on_vegetarian_prop.R 2>&1 | tee archive/logs/A1_vn_o_vn_p.log"

# A2: a2_proportion_t (10 models)
## tmux new-session -d -s A2_b_c "Rscript model_starters/a2_proportion_t/A2_breakfast_count.R 2>&1 | tee archive/logs/A2_b_c.log"
## tmux new-session -d -s A2_b_p "Rscript model_starters/a2_proportion_t/A2_breakfast_presence.R 2>&1 | tee archive/logs/A2_b_p.log"
## tmux new-session -d -s A2_u_c "Rscript model_starters/a2_proportion_t/A2_untextured_count.R 2>&1 | tee archive/logs/A2_u_c.log"
## tmux new-session -d -s A2_u_p "Rscript model_starters/a2_proportion_t/A2_untextured_presence.R 2>&1 | tee archive/logs/A2_u_p.log"
## tmux new-session -d -s A2_c_c "Rscript model_starters/a2_proportion_t/A2_chicken_count.R 2>&1 | tee archive/logs/A2_c_c.log"
## tmux new-session -d -s A2_c_p "Rscript model_starters/a2_proportion_t/A2_chicken_presence.R 2>&1 | tee archive/logs/A2_c_p.log"
## tmux new-session -d -s A2_d_c "Rscript model_starters/a2_proportion_t/A2_dairy_count.R 2>&1 | tee archive/logs/A2_d_c.log"
## tmux new-session -d -s A2_d_p "Rscript model_starters/a2_proportion_t/A2_dairy_presence.R 2>&1 | tee archive/logs/A2_d_p.log"
## tmux new-session -d -s A2_e_c "Rscript model_starters/a2_proportion_t/A2_egg_count.R 2>&1 | tee archive/logs/A2_e_c.log"
## tmux new-session -d -s A2_e_p "Rscript model_starters/a2_proportion_t/A2_egg_presence.R 2>&1 | tee archive/logs/A2_e_p.log"

# A3: its (6 models)
# tmux new-session -d -s A3_c_f "Rscript model_starters/a3_its/A3_chicken_fish.R 2>&1 | tee archive/logs/A3_c_f.log"
# tmux new-session -d -s A3_m "Rscript model_starters/a3_its/A3_meat.R 2>&1 | tee archive/logs/A3_m.log"
# tmux new-session -d -s A3_n "Rscript model_starters/a3_its/A3_nonvegan.R 2>&1 | tee archive/logs/A3_n.log"
# tmux new-session -d -s A3_t "Rscript model_starters/a3_its/A3_total.R 2>&1 | tee archive/logs/A3_t.log"
# tmux new-session -d -s A3_v "Rscript model_starters/a3_its/A3_vegan.R 2>&1 | tee archive/logs/A3_v.log"
# tmux new-session -d -s A3_vn "Rscript model_starters/a3_its/A3_vegetarian.R 2>&1 | tee archive/logs/A3_vn.log"

# # A4: a4_its_t (3 models)
# tmux new-session -d -s A4_b "Rscript model_starters/a4_its_t/A4_breakfast.R 2>&1 | tee archive/logs/A4_b.log"
# tmux new-session -d -s A4_t "Rscript model_starters/a4_its_t/A4_textured.R 2>&1 | tee archive/logs/A4_t.log"
# tmux new-session -d -s A4_u "Rscript model_starters/a4_its_t/A4_untextured.R 2>&1 | tee archive/logs/A4_u.log"

# A5 Transaction: customer conditional Poisson (6 models)
# tmux new-session -d -s A5T_t "Rscript model_starters/customer_transaction/A5_total.R 2>&1 | tee archive/logs/A5T_t.log"
# tmux new-session -d -s A5T_v "Rscript model_starters/customer_transaction/A5_vegan.R 2>&1 | tee archive/logs/A5T_v.log"
# tmux new-session -d -s A5T_vn "Rscript model_starters/customer_transaction/A5_vegetarian.R 2>&1 | tee archive/logs/A5T_vn.log"
# tmux new-session -d -s A5T_n "Rscript model_starters/customer_transaction/A5_nonvegan.R 2>&1 | tee archive/logs/A5T_n.log"
# tmux new-session -d -s A5T_m "Rscript model_starters/customer_transaction/A5_meat.R 2>&1 | tee archive/logs/A5T_m.log"
# tmux new-session -d -s A5T_c_f "Rscript model_starters/customer_transaction/A5_chicken_fish.R 2>&1 | tee archive/logs/A5T_c_f.log"

# A5 Gaussian: customer demeaned Gaussian INGARCH (6 models)
# tmux new-session -d -s A5G_t "Rscript model_starters/customer/A5_total.R 2>&1 | tee archive/logs/A5G_t.log"
# tmux new-session -d -s A5G_v "Rscript model_starters/customer/A5_vegan.R 2>&1 | tee archive/logs/A5G_v.log"
# tmux new-session -d -s A5G_vn "Rscript model_starters/customer/A5_vegetarian.R 2>&1 | tee archive/logs/A5G_vn.log"
# tmux new-session -d -s A5G_n "Rscript model_starters/customer/A5_nonvegan.R 2>&1 | tee archive/logs/A5G_n.log"
# tmux new-session -d -s A5G_m "Rscript model_starters/customer/A5_meat.R 2>&1 | tee archive/logs/A5G_m.log"
# tmux new-session -d -s A5G_c_f "Rscript model_starters/customer/A5_chicken_fish.R 2>&1 | tee archive/logs/A5G_c_f.log"

# A5GI: customer Gaussian IID (6 models)
# tmux new-session -d -s A5GI_t "Rscript model_starters/customer/A5_total.R 2>&1 | tee archive/logs/A5GI_t.log"
# tmux new-session -d -s A5GI_v "Rscript model_starters/customer/A5_vegan.R 2>&1 | tee archive/logs/A5GI_v.log"
# tmux new-session -d -s A5GI_vn "Rscript model_starters/customer/A5_vegetarian.R 2>&1 | tee archive/logs/A5GI_vn.log"
# tmux new-session -d -s A5GI_n "Rscript model_starters/customer/A5_nonvegan.R 2>&1 | tee archive/logs/A5GI_n.log"
# tmux new-session -d -s A5GI_m "Rscript model_starters/customer/A5_meat.R 2>&1 | tee archive/logs/A5GI_m.log"
# tmux new-session -d -s A5GI_c_f "Rscript model_starters/customer/A5_chicken_fish.R 2>&1 | tee archive/logs/A5GI_c_f.log"

# A6GI: customer_targeted Gaussian IID (2 models)
tmux new-session -d -s A6GI_b "Rscript model_starters/customer_targeted/A6_breakfast.R 2>&1 | tee archive/logs/A6GI_b.log"
tmux new-session -d -s A6GI_u "Rscript model_starters/customer_targeted/A6_untextured.R 2>&1 | tee archive/logs/A6GI_u.log"

echo "To list sessions: tmux ls"
echo "To attach to a session: tmux attach -t <session_name>"
echo "To kill all sessions: tmux kill-server"