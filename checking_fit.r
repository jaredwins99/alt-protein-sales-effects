fit <- readRDS(paste0("model_fits/empirical/vegan/fit_L69HYJ4Y3TR91.rds"))
stan_fit_object <- fit

# --- Extract Draws and Sampler Parameters (using posterior consistently) ---
# It's best to work with a consistent draws format, like draws_df
if (inherits(stan_fit_object, "CmdStanMCMC")) {
    # CmdStanR >= 0.4.0 returns draws_df by default with draws()
    # Ensure it's a draws_df object
    original_draws_object <- stan_fit_object$draws(format = "draws_df")
    sampler_params_bayesplot <- nuts_params(stan_fit_object)
    all_params <- stan_fit_object$metadata()$variables
} else if (inherits(stan_fit_object, "stanfit")) {
    original_draws_object <- as_draws_df(stan_fit_object) # Convert to draws_df
    sampler_params_bayesplot <- nuts_params(stan_fit_object)
    all_params <- names(stan_fit_object)
} else {
    stop("Object is not a recognized stanfit or CmdStanMCMC object.")
}

# --- Identify Parameters to Analyze (same logic as before) ---
params_to_analyze <- character()
# 1. Core parameters
for (prefix in core_param_prefixes) {
  pattern <- paste0("^", prefix, "(\\[|$)")
  core_matches <- all_params[grepl(pattern, all_params)]
  params_to_analyze <- c(params_to_analyze, core_matches)
}
# 2. Sample of high-dimensional parameters
for (prefix in high_dim_prefixes) {
  pattern <- paste0("^", prefix, "\\[")
  all_matches <- all_params[grepl(pattern, all_params)]
  # Simplified selection: just take the first n alphabetically if indices are complex
  selected_high_dim <- head(sort(all_matches), n_high_dim_examples)
  params_to_analyze <- c(params_to_analyze, selected_high_dim)
}
params_to_analyze <- unique(params_to_analyze)
params_to_analyze <- setdiff(params_to_analyze, "lp__")

cat("Parameters selected for detailed diagnostics:\n")
print(params_to_analyze)

if (length(params_to_analyze) == 0) {
  stop("No parameters matched the specified prefixes. Check 'core_param_prefixes' and 'high_dim_prefixes'.")
}

# --- 1. Numerical Summary for Selected Parameters (using posterior) ---
cat("\n--- Numerical Summary (Rhat, ESS) for Selected Parameters ---\n")
# Calculate summary using posterior::summarise_draws, which works on draws objects
# We can filter *after* calculating on the whole object or calculate only on a subset
# Option A: Summarize all, then filter (easier if summary is fast)
# full_summary <- summarise_draws(original_draws_object)
# filtered_summary <- full_summary %>% filter(variable %in% params_to_analyze)

# Option B: Subset draws first, then summarize (better for huge models)
draws_subset_for_summary <- subset_draws(original_draws_object, variable = params_to_analyze)
filtered_summary <- summarise_draws(draws_subset_for_summary)

print(filtered_summary, n = Inf)

# Check specifically for high R-hat or low ESS
high_rhat <- filtered_summary %>% filter(rhat > 1.05)
low_ess <- filtered_summary %>% filter(ess_bulk < 400 | ess_tail < 400) # Rule of thumb

if (nrow(high_rhat) > 0) {
  cat("\nWarning: Parameters with Rhat > 1.05:\n")
  print(high_rhat)
}
if (nrow(low_ess) > 0) {
  cat("\nWarning: Parameters with low ESS (< 400):\n")
  print(low_ess)
}


# --- 2. Sampler Behavior Summary (Divergences, Treedepth - No change needed here) ---
cat("\n--- Sampler Diagnostics Summary ---\n")
# ... (This part uses sampler_params_bayesplot directly, which was likely okay) ...
# Print summary, count divergences, count max treedepth, check E-BFMI
print(nuts_params(stan_fit_object)) # Provides summary stats per chain

# Check total divergences
num_divergences <- sum(sampler_params_bayesplot$Value[sampler_params_bayesplot$Parameter == "divergent__"])
total_samples <- ndraws(original_draws_object) # Use ndraws() for total post-warmup samples
cat(sprintf("Total Post-Warmup Divergences: %d (%.2f%% of draws)\n",
            num_divergences, 100 * num_divergences / total_samples))

# Check max treedepth hits (assuming max_treedepth was 10, adjust if needed)
MAX_TREEDEPTH_SETTING <- 10 # <<< CHANGE THIS if you set it differently via control= list(...)
num_max_treedepth <- sum(sampler_params_bayesplot$Value[sampler_params_bayesplot$Parameter == "treedepth__"] >= MAX_TREEDEPTH_SETTING)
cat(sprintf("Iterations hitting Max Treedepth (%d): %d (%.2f%% of draws)\n",
            MAX_TREEDEPTH_SETTING, num_max_treedepth,
            100 * num_max_treedepth / total_samples))

# Check E-BFMI
cat("\nChecking E-BFMI (will warn below if low):\n")
suppressWarnings(mcmc_nuts_energy(sampler_params_bayesplot))


# --- 3. Visual Diagnostics for Selected Parameters (Revised) ---
cat("\n--- Generating Diagnostic Plots for Selected Parameters ---\n")
color_scheme_set("viridis")

# --- FIXES Start Here ---

# Trace plots: Use original draws object and 'pars' argument
print(mcmc_trace(original_draws_object, pars = params_to_analyze, # Use pars
                 np = sampler_params_bayesplot) +
      ggtitle("Trace Plots for Selected Parameters (with Sampler Info)"))

# Rhat values: Calculate rhat on the subset, then plot
rhat_values_subset <- rhat(subset_draws(original_draws_object, variable = params_to_analyze))
print(mcmc_rhat(rhat_values_subset) + # Plot the calculated values
      yaxis_text(hjust = 1) + ggtitle("R-hat for Selected Parameters"))

# ESS ratio plots: Calculate neff_ratio on the subset, then plot
neff_ratio_values_subset <- neff_ratio(subset_draws(original_draws_object, variable = params_to_analyze))
print(mcmc_neff(neff_ratio_values_subset) + # Plot the calculated values
      yaxis_text(hjust = 1) + ggtitle("ESS Ratio for Selected Parameters"))

# Autocorrelation plots: Use original draws object and 'pars' argument
print(mcmc_acf(original_draws_object, pars = params_to_analyze, lags = 20) + # Use pars
       ggtitle("Autocorrelation for Selected Parameters"))

# --- FIXES End Here ---


# --- 4. Pairs Plot for CORE Parameters (Revised) ---
core_params_present <- intersect(params_to_analyze, all_params[grepl(paste0("^(", paste(core_param_prefixes, collapse="|"), ")(\\[|$)"), all_params)])

if (length(core_params_present) > 1 && length(core_params_present) <= 10) {
  cat("\n--- Generating Pairs Plot for CORE Parameters ---\n")
  print(
    mcmc_pairs(original_draws_object, # Use original draws object
               pars = core_params_present, # Specify core params here
               np = sampler_params_bayesplot,
               off_diag_args = list(size = 0.75),
               np_style = pairs_style_np(div_color = "red", td_color = "yellow")) +
      ggtitle("Pairs Plot for Core Parameters (Highlighting Divergences/Treedepth)")
  )
} else if (length(core_params_present) > 10) {
   cat("\n--- Skipping pairs plot for core parameters (too many > 10) ---\n")
} else {
   cat("\n--- Skipping pairs plot (fewer than 2 core parameters found) ---\n")
}

# --- 5. Scatter plot example: Divergences vs two key parameters (Revised) ---
key_param1 <- Filter(function(p) startsWith(p, "beta"), core_params_present)[1]
key_param2 <- Filter(function(p) startsWith(p, "alpha"), core_params_present)[1]

if(num_divergences > 0 && !is.na(key_param1) && !is.na(key_param2)) {
    cat("\n--- Generating Scatter Plot: Divergences vs Key Parameters ---\n")
    print(
        mcmc_scatter(original_draws_object, # Use original draws object
                     pars = c(key_param1, key_param2), # Specify params here
                     np = sampler_params_bayesplot,
                     size = 1.5) +
        ggtitle(paste("Scatter Plot:", key_param1, "vs", key_param2, "(Highlighting Sampler Issues)"))
    )
} else if (num_divergences > 0) {
    cat("\n--- Could not find two distinct core parameters for divergence scatter plot ---\n")
}


cat("\n--- Diagnostics Complete ---\n")


