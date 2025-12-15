#!/bin/bash
# Batch script to run T2 models A1-A6 in tmux sessions
# Total: 70 models × 3 chains = 210 cores

cd /home/researcher/Documents/Jared/Other/testing

# # A1_T2: t2_proportion (36 models)
### ===
### vvv
# tmux new-session -d -s A1T2_c_f_o_m_c "Rscript model_starters/t2_proportion/A1_T2_chicken_fish_on_mpbamod_count.R 2>&1 | tee logs/A1T2_c_f_o_m_c.log"
# tmux new-session -d -s A1T2_c_f_o_m_p "Rscript model_starters/t2_proportion/A1_T2_chicken_fish_on_mpbamod_prop.R 2>&1 | tee logs/A1T2_c_f_o_m_p.log"
# tmux new-session -d -s A1T2_c_f_o_v_c "Rscript model_starters/t2_proportion/A1_T2_chicken_fish_on_vegan_count.R 2>&1 | tee logs/A1T2_c_f_o_v_c.log"
# tmux new-session -d -s A1T2_c_f_o_v_p "Rscript model_starters/t2_proportion/A1_T2_chicken_fish_on_vegan_prop.R 2>&1 | tee logs/A1T2_c_f_o_v_p.log"
# tmux new-session -d -s A1T2_c_f_o_vn_c "Rscript model_starters/t2_proportion/A1_T2_chicken_fish_on_vegetarian_count.R 2>&1 | tee logs/A1T2_c_f_o_v_c.log"
# tmux new-session -d -s A1T2_c_f_o_vn_p "Rscript model_starters/t2_proportion/A1_T2_chicken_fish_on_vegetarian_prop.R 2>&1 | tee logs/A1T2_c_f_o_v_p.log"
# tmux new-session -d -s A1T2_m_o_m_c "Rscript model_starters/t2_proportion/A1_T2_meat_on_mpbamod_count.R 2>&1 | tee logs/A1T2_m_o_m_c.log"
# tmux new-session -d -s A1T2_m_o_m_p "Rscript model_starters/t2_proportion/A1_T2_meat_on_mpbamod_prop.R 2>&1 | tee logs/A1T2_m_o_m_p.log"
# tmux new-session -d -s A1T2_m_o_v_c "Rscript model_starters/t2_proportion/A1_T2_meat_on_vegan_count.R 2>&1 | tee logs/A1T2_m_o_v_c.log"
# tmux new-session -d -s A1T2_m_o_v_p "Rscript model_starters/t2_proportion/A1_T2_meat_on_vegan_prop.R 2>&1 | tee logs/A1T2_m_o_v_p.log"
# tmux new-session -d -s A1T2_m_o_vn_c "Rscript model_starters/t2_proportion/A1_T2_meat_on_vegetarian_count.R 2>&1 | tee logs/A1T2_m_o_v_c.log"
# tmux new-session -d -s A1T2_m_o_vn_p "Rscript model_starters/t2_proportion/A1_T2_meat_on_vegetarian_prop.R 2>&1 | tee logs/A1T2_m_o_v_p.log"
# tmux new-session -d -s A1T2_n_o_m_c "Rscript model_starters/t2_proportion/A1_T2_nonvegan_on_mpbamod_count.R 2>&1 | tee logs/A1T2_n_o_m_c.log"
# tmux new-session -d -s A1T2_n_o_m_p "Rscript model_starters/t2_proportion/A1_T2_nonvegan_on_mpbamod_prop.R 2>&1 | tee logs/A1T2_n_o_m_p.log"
# tmux new-session -d -s A1T2_n_o_v_c "Rscript model_starters/t2_proportion/A1_T2_nonvegan_on_vegan_count.R 2>&1 | tee logs/A1T2_n_o_v_c.log"
# tmux new-session -d -s A1T2_n_o_v_p "Rscript model_starters/t2_proportion/A1_T2_nonvegan_on_vegan_prop.R 2>&1 | tee logs/A1T2_n_o_v_p.log"
# tmux new-session -d -s A1T2_n_o_vn_c "Rscript model_starters/t2_proportion/A1_T2_nonvegan_on_vegetarian_count.R 2>&1 | tee logs/A1T2_n_o_v_c.log"
# tmux new-session -d -s A1T2_n_o_vn_p "Rscript model_starters/t2_proportion/A1_T2_nonvegan_on_vegetarian_prop.R 2>&1 | tee logs/A1T2_n_o_v_p.log"
# tmux new-session -d -s A1T2_t_o_m_c "Rscript model_starters/t2_proportion/A1_T2_total_on_mpbamod_count.R 2>&1 | tee logs/A1T2_t_o_m_c.log"
# tmux new-session -d -s A1T2_t_o_m_p "Rscript model_starters/t2_proportion/A1_T2_total_on_mpbamod_prop.R 2>&1 | tee logs/A1T2_t_o_m_p.log"
# tmux new-session -d -s A1T2_t_o_v_c "Rscript model_starters/t2_proportion/A1_T2_total_on_vegan_count.R 2>&1 | tee logs/A1T2_t_o_v_c.log"
# tmux new-session -d -s A1T2_t_o_v_p "Rscript model_starters/t2_proportion/A1_T2_total_on_vegan_prop.R 2>&1 | tee logs/A1T2_t_o_v_p.log"
# tmux new-session -d -s A1T2_t_o_vn_c "Rscript model_starters/t2_proportion/A1_T2_total_on_vegetarian_count.R 2>&1 | tee logs/A1T2_t_o_v_c.log"
# tmux new-session -d -s A1T2_t_o_vn_p "Rscript model_starters/t2_proportion/A1_T2_total_on_vegetarian_prop.R 2>&1 | tee logs/A1T2_t_o_v_p.log"
# tmux new-session -d -s A1T2_v_o_m_c "Rscript model_starters/t2_proportion/A1_T2_vegan_on_mpbamod_count.R 2>&1 | tee logs/A1T2_v_o_m_c.log"
### ^^^
### ===
# tmux new-session -d -s A1T2_v_o_m_p "Rscript model_starters/t2_proportion/A1_T2_vegan_on_mpbamod_prop.R 2>&1 | tee logs/A1T2_v_o_m_p.log"
# tmux new-session -d -s A1T2_v_o_v_c "Rscript model_starters/t2_proportion/A1_T2_vegan_on_vegan_count.R 2>&1 | tee logs/A1T2_v_o_v_c.log"
# tmux new-session -d -s A1T2_v_o_v_p "Rscript model_starters/t2_proportion/A1_T2_vegan_on_vegan_prop.R 2>&1 | tee logs/A1T2_v_o_v_p.log"
# tmux new-session -d -s A1T2_v_o_vn_c "Rscript model_starters/t2_proportion/A1_T2_vegan_on_vegetarian_count.R 2>&1 | tee logs/A1T2_v_o_v_c.log"
# tmux new-session -d -s A1T2_v_o_vn_p "Rscript model_starters/t2_proportion/A1_T2_vegan_on_vegetarian_prop.R 2>&1 | tee logs/A1T2_v_o_v_p.log"
# tmux new-session -d -s A1T2_vn_o_m_c "Rscript model_starters/t2_proportion/A1_T2_vegetarian_on_mpbamod_count.R 2>&1 | tee logs/A1T2_v_o_m_c.log"
# tmux new-session -d -s A1T2_vn_o_m_p "Rscript model_starters/t2_proportion/A1_T2_vegetarian_on_mpbamod_prop.R 2>&1 | tee logs/A1T2_v_o_m_p.log"
# tmux new-session -d -s A1T2_vn_o_v_c "Rscript model_starters/t2_proportion/A1_T2_vegetarian_on_vegan_count.R 2>&1 | tee logs/A1T2_v_o_v_c.log"
# tmux new-session -d -s A1T2_vn_o_v_p "Rscript model_starters/t2_proportion/A1_T2_vegetarian_on_vegan_prop.R 2>&1 | tee logs/A1T2_v_o_v_p.log"
# tmux new-session -d -s A1T2_vn_o_vn_c "Rscript model_starters/t2_proportion/A1_T2_vegetarian_on_vegetarian_count.R 2>&1 | tee logs/A1T2_v_o_v_c.log"
# tmux new-session -d -s A1T2_vn_o_vn_p "Rscript model_starters/t2_proportion/A1_T2_vegetarian_on_vegetarian_prop.R 2>&1 | tee logs/A1T2_v_o_v_p.log"

### ===
### vvv
# # A2_T2: t2_proportion_targeted (12 models)
tmux new-session -d -s A2T2_b_c "Rscript model_starters/t2_proportion_targeted/A2_T2_breakfast_count.R 2>&1 | tee logs/A2T2_b_c.log"
tmux new-session -d -s A2T2_b_p "Rscript model_starters/t2_proportion_targeted/A2_T2_breakfast_presence.R 2>&1 | tee logs/A2T2_b_p.log"
# tmux new-session -d -s A2T2_c_c "Rscript model_starters/t2_proportion_targeted/A2_T2_chicken_count.R 2>&1 | tee logs/A2T2_c_c.log"
# tmux new-session -d -s A2T2_c_p "Rscript model_starters/t2_proportion_targeted/A2_T2_chicken_presence.R 2>&1 | tee logs/A2T2_c_p.log"
# tmux new-session -d -s A2T2_d_c "Rscript model_starters/t2_proportion_targeted/A2_T2_dairy_count.R 2>&1 | tee logs/A2T2_d_c.log"
# tmux new-session -d -s A2T2_d_p "Rscript model_starters/t2_proportion_targeted/A2_T2_dairy_presence.R 2>&1 | tee logs/A2T2_d_p.log"
# tmux new-session -d -s A2T2_e_c "Rscript model_starters/t2_proportion_targeted/A2_T2_egg_count.R 2>&1 | tee logs/A2T2_e_c.log"
# tmux new-session -d -s A2T2_e_p "Rscript model_starters/t2_proportion_targeted/A2_T2_egg_presence.R 2>&1 | tee logs/A2T2_e_p.log"
# tmux new-session -d -s A2T2_t_c "Rscript model_starters/t2_proportion_targeted/A2_T2_textured_count.R 2>&1 | tee logs/A2T2_t_c.log"
# tmux new-session -d -s A2T2_t_p "Rscript model_starters/t2_proportion_targeted/A2_T2_textured_presence.R 2>&1 | tee logs/A2T2_t_p.log"
tmux new-session -d -s A2T2_u_c "Rscript model_starters/t2_proportion_targeted/A2_T2_untextured_count.R 2>&1 | tee logs/A2T2_u_c.log"
tmux new-session -d -s A2T2_u_p "Rscript model_starters/t2_proportion_targeted/A2_T2_untextured_presence.R 2>&1 | tee logs/A2T2_u_p.log"
### ^^^
### ===


### ===
### vvv
# # A3_T2: t2_its (6 models)
# tmux new-session -d -s A3T2_c_f "Rscript model_starters/t2_its/A3_T2_chicken_fish.R 2>&1 | tee logs/A3T2_c_f.log"
# tmux new-session -d -s A3T2_m "Rscript model_starters/t2_its/A3_T2_meat.R 2>&1 | tee logs/A3T2_m.log"
# tmux new-session -d -s A3T2_n "Rscript model_starters/t2_its/A3_T2_nonvegan.R 2>&1 | tee logs/A3T2_n.log"
# tmux new-session -d -s A3T2_t "Rscript model_starters/t2_its/A3_T2_total.R 2>&1 | tee logs/A3T2_t.log"
# tmux new-session -d -s A3T2_v "Rscript model_starters/t2_its/A3_T2_vegan.R 2>&1 | tee logs/A3T2_v.log"
# tmux new-session -d -s A3T2_vn "Rscript model_starters/t2_its/A3_T2_vegetarian.R 2>&1 | tee logs/A3T2_v.log"
### ^^^
### ===


# # A4_T2: t2_its_targeted (5 models)
# tmux new-session -d -s A4T2_b "Rscript model_starters/t2_its_targeted/A4_T2_breakfast.R 2>&1 | tee logs/A4T2_b.log"
# tmux new-session -d -s A4T2_c "Rscript model_starters/t2_its_targeted/A4_T2_chicken.R 2>&1 | tee logs/A4T2_c.log"
# tmux new-session -d -s A4T2_d "Rscript model_starters/t2_its_targeted/A4_T2_dairy.R 2>&1 | tee logs/A4T2_d.log"
# tmux new-session -d -s A4T2_t "Rscript model_starters/t2_its_targeted/A4_T2_textured.R 2>&1 | tee logs/A4T2_t.log"
# tmux new-session -d -s A4T2_u "Rscript model_starters/t2_its_targeted/A4_T2_untextured.R 2>&1 | tee logs/A4T2_u.log"

# # A5_T2: t2_customer (6 models)
# tmux new-session -d -s A5T2_c_f "Rscript model_starters/t2_customer/A5_T2_chicken_fish.R 2>&1 | tee logs/A5T2_c_f.log"
# tmux new-session -d -s A5T2_m "Rscript model_starters/t2_customer/A5_T2_meat.R 2>&1 | tee logs/A5T2_m.log"
# tmux new-session -d -s A5T2_n "Rscript model_starters/t2_customer/A5_T2_nonvegan.R 2>&1 | tee logs/A5T2_n.log"
# tmux new-session -d -s A5T2_t "Rscript model_starters/t2_customer/A5_T2_total.R 2>&1 | tee logs/A5T2_t.log"
# tmux new-session -d -s A5T2_v "Rscript model_starters/t2_customer/A5_T2_vegan.R 2>&1 | tee logs/A5T2_v.log"
# tmux new-session -d -s A5T2_vn "Rscript model_starters/t2_customer/A5_T2_vegetarian.R 2>&1 | tee logs/A5T2_v.log"

# # A6_T2: t2_customer_targeted (5 models)
# tmux new-session -d -s A6T2_b "Rscript model_starters/t2_customer_targeted/A6_T2_breakfast.R 2>&1 | tee logs/A6T2_b.log"
# tmux new-session -d -s A6T2_c "Rscript model_starters/t2_customer_targeted/A6_T2_chicken.R 2>&1 | tee logs/A6T2_c.log"
# tmux new-session -d -s A6T2_d "Rscript model_starters/t2_customer_targeted/A6_T2_dairy.R 2>&1 | tee logs/A6T2_d.log"
# tmux new-session -d -s A6T2_t "Rscript model_starters/t2_customer_targeted/A6_T2_textured.R 2>&1 | tee logs/A6T2_t.log"
# tmux new-session -d -s A6T2_u "Rscript model_starters/t2_customer_targeted/A6_T2_untextured.R 2>&1 | tee logs/A6T2_u.log"

echo "Started 70 tmux sessions (A1-A6 T2 models)"
echo "Using 210 cores (70 models × 3 chains)"
echo ""
echo "To list sessions: tmux ls"
echo "To attach to a session: tmux attach -t <session_name>"
echo "To kill all sessions: tmux kill-server"
