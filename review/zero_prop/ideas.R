################################################################################
# RESEARCH MEMO: IDENTIFYING STRUCTURAL ZEROS IN MENU ITEM DATA
# Author: Statistical Consultant
# Date: 2026-01-31
#
# Context: Zero-inflated models for plant-based menu items across restaurants
# Goal: Distinguish structural zeros (restaurant doesn't offer category) from
#       sampling zeros (restaurant offers category but happened to have 0 at time t)
################################################################################

# ==============================================================================
# SECTION 1: ALTERNATIVES TO THE 3-SD RULE
# ==============================================================================

# Current approach: Flag as structural zero if obs is 3+ SD below global mean
#
# CONCERNS WITH 3-SD APPROACH:
# - Assumes normal distribution (inappropriate for count data)
# - Global mean/SD ignores restaurant-specific patterns
# - Single time point can't distinguish "never offers" vs "temporarily zero"
# - Arbitrary threshold (why 3 SD and not 2 or 4?)
# - Doesn't account for overdispersion common in restaurant data

# ALTERNATIVE 1: RESTAURANT-LEVEL HISTORY ANALYSIS
# ------------------------------------------------
# Idea: A structural zero means the restaurant NEVER offers that category
#
# Implementation:
# - For each restaurant-outcome pair, calculate:
#   * Proportion of time periods with zero count
#   * Maximum observed value across all time periods
#   * Variance across time periods
#
# Classification rules:
# - Structural zero if: restaurant has 100% zeros across ALL time periods
# - Probable structural zero if: >90% zeros AND max value <= 1
# - Sampling zero if: <50% zeros OR max value >= 3
# - Ambiguous otherwise
#
# Advantage: Uses panel structure, distinguishes "never" from "rarely"
# Limitation: Requires sufficient time periods per restaurant

# ALTERNATIVE 2: MIXTURE MODEL-BASED CLASSIFICATION
# -------------------------------------------------
# Idea: Let the zero-inflated model itself estimate structural zero probability
#
# From your fitted models, extract:
# - pi_i = P(structural zero | restaurant i, covariates)
# - This comes from the logistic/binomial component of ZI model
#
# Classification:
# - If pi_i > 0.8, classify as structural zero
# - If pi_i < 0.2, classify as sampling zero regime
# - Otherwise, uncertain
#
# Advantage: Theoretically grounded, uses model's own inference
# Limitation: pi estimates may be uncertain with sparse data

# ALTERNATIVE 3: RESTAURANT CHARACTERISTICS-BASED
# -----------------------------------------------
# Idea: Structural zeros correlate with restaurant type/cuisine
#
# Exploratory analysis:
# - Group restaurants by cuisine type, price point, location
# - Calculate zero rates within each group
# - Identify "zero-prone" restaurant types (e.g., steakhouses for vegan)
#
# Classification:
# - If restaurant belongs to category where 80%+ have zero rates >90%,
#   flag those zeros as structural
# - Example: Fast food chains → likely structural zeros for specialty items
#
# Advantage: Interpretable, aligns with domain knowledge
# Limitation: Requires good restaurant metadata

# ALTERNATIVE 4: LATENT CLASS ANALYSIS
# ------------------------------------
# Idea: Identify unobserved classes of restaurants
#
# Model approach:
# - Fit latent class model with K classes (e.g., K=3)
#   * Class 1: "Never offers" (structural zeros)
#   * Class 2: "Rarely offers" (mostly sampling zeros)
#   * Class 3: "Regular offerings" (few zeros)
#
# - Assign restaurants to classes based on posterior probabilities
# - Within Class 1, all zeros are structural; in Class 3, all are sampling
#
# Advantage: Probabilistic, accounts for uncertainty
# Limitation: Computationally intensive, requires class number choice

# ALTERNATIVE 5: CHANGEPOINT DETECTION
# ------------------------------------
# Idea: Structural zeros persist, but restaurants can change (menu updates)
#
# For each restaurant:
# - Test for changepoints in time series (e.g., PELT algorithm)
# - Before changepoint: classify zeros differently than after
# - Example: Restaurant adds vegan menu in 2023 → zeros before are structural,
#   zeros after are sampling
#
# Advantage: Captures menu evolution, realistic
# Limitation: Needs long time series, assumes discrete changes

# ALTERNATIVE 6: HIERARCHICAL CLUSTERING ON ZERO PATTERNS
# -------------------------------------------------------
# Idea: Restaurants with similar zero patterns likely share structural status
#
# Approach:
# - Create feature vector for each restaurant:
#   [mean_vegan, var_vegan, zero_rate_vegan, max_vegan, ...]
# - Cluster restaurants (k-means, hierarchical clustering)
# - Examine clusters: some will be "structural zero" clusters for certain outcomes
#
# Advantage: Data-driven, multivariate
# Limitation: Requires interpretation of clusters

# ALTERNATIVE 7: QUANTILE REGRESSION APPROACH
# -------------------------------------------
# Idea: Structural zeros are systematically different from the bulk
#
# Implementation:
# - Fit quantile regression at very low quantiles (e.g., 0.05, 0.10)
# - Observations below 5th percentile consistently across outcomes → structural
# - Compare restaurant-level residuals across quantiles
#
# Advantage: Robust to outliers, distribution-free
# Limitation: Still somewhat arbitrary threshold

# ALTERNATIVE 8: DOMAIN EXPERT VALIDATION SAMPLE
# ----------------------------------------------
# Idea: Hand-label a subset, train classifier
#
# Process:
# 1. Sample 50-100 restaurants
# 2. Manual review of menus → confirm structural zeros
# 3. Train supervised classifier (logistic, random forest) on features:
#    - Zero rate, variance, restaurant type, location, etc.
# 4. Apply classifier to full dataset
#
# Advantage: Ground truth, can validate other methods
# Limitation: Labor-intensive, may not generalize


# ==============================================================================
# SECTION 2: VISUALIZATION STRATEGIES
# ==============================================================================

# VIZ 1: ZERO RATE HEATMAP BY RESTAURANT AND OUTCOME
# --------------------------------------------------
# Rows: Restaurants (sorted by overall zero rate)
# Columns: Outcomes (total, vegan_count, vegan_prop, etc.)
# Color: Zero rate (0% = white, 100% = dark red)
#
# Expected pattern:
# - Horizontal bands → some restaurants are zero-prone across outcomes
# - Vertical bands → some outcomes have more structural zeros
# - Hypothesis: subset outcomes (vegan, textured) darker than total
#
# R pseudocode:
# zero_rates <- data %>%
#   group_by(restaurant_id, outcome_type) %>%
#   summarize(zero_rate = mean(value == 0))
# ggplot(zero_rates, aes(outcome_type, restaurant_id, fill = zero_rate)) +
#   geom_tile() + scale_fill_gradient(low = "white", high = "darkred")

# VIZ 2: ZERO DURATION HISTOGRAM
# ------------------------------
# For each restaurant-outcome, calculate longest consecutive zero streak
# Plot histogram of max streak length
#
# Interpretation:
# - Structural zeros → very long streaks (entire observation period)
# - Sampling zeros → short streaks (1-3 periods)
# - Bimodal distribution suggests mixture
#
# Facet by outcome to compare total vs subsets

# VIZ 3: TIME SERIES SMALL MULTIPLES
# ----------------------------------
# Grid of time series plots, one per restaurant
# Overlay vegan count, vegetarian count, total count
#
# Visual patterns to identify:
# - Flat line at zero for vegan but not total → structural zero for vegan
# - All series near zero → overall low-volume restaurant
# - Vegan spikes from zero → menu addition event
#
# Sample random subset of restaurants to avoid overplotting

# VIZ 4: SCATTERPLOT MATRIX: MEAN VS VARIANCE VS ZERO RATE
# --------------------------------------------------------
# Three variables per restaurant-outcome:
# - X axis: Mean value across time
# - Y axis: Variance across time
# - Color/size: Zero rate
#
# Expected clusters:
# - Structural zero cluster: mean ≈ 0, variance ≈ 0, zero_rate ≈ 1
# - Regular offering cluster: mean > 0, variance > 0, zero_rate < 0.3
# - Intermediate cluster: ambiguous cases
#
# Use faceting or color to distinguish outcome types

# VIZ 5: EMPIRICAL CDF COMPARISON
# -------------------------------
# For each outcome, plot ECDF of restaurant-level means
# Overlay CDFs for different outcomes on same plot
#
# Interpretation:
# - Steep jump at zero → many structural zeros
# - Gradual rise from zero → mostly sampling zeros
# - Compare: if vegan ECDF jumps higher at zero than total ECDF,
#   confirms hypothesis of more structural zeros in subsets

# VIZ 6: ZERO INFLATION PARAMETER ESTIMATES
# -----------------------------------------
# From fitted ZI models, extract restaurant-specific pi estimates
# (probability of structural zero)
#
# Violin plot or density plot of pi by outcome type
# Expected: subset outcomes have higher median pi than total dishes
#
# Bonus: scatterplot of pi_vegan vs pi_total by restaurant
# Points above diagonal → more zero-inflated for vegan

# VIZ 7: RESTAURANT TRAJECTORY PLOTS
# ----------------------------------
# Select restaurants with interesting patterns
# Plot trajectory over time with annotations:
# - Color-code time periods: structural zero (red), sampling zero (yellow),
#   non-zero (green)
# - Show menu change events if available
#
# Case studies: illustrate different zero patterns

# VIZ 8: SPATIAL MAP (if location data available)
# -----------------------------------------------
# Map restaurants geographically
# Color by zero rate for vegan dishes
#
# Patterns to look for:
# - Spatial clustering of structural zeros (e.g., rural areas)
# - Urban areas with lower structural zero rates


# ==============================================================================
# SECTION 3: FORMAL STATISTICAL TESTS
# ==============================================================================

# TEST 1: VUONG TEST FOR ZERO-INFLATION
# -------------------------------------
# Purpose: Test if zero-inflated model fits better than standard Poisson/NB
#
# Null hypothesis: No excess zeros (standard model sufficient)
# Alternative: Zero-inflation present
#
# Application:
# - Run separately for total vs subset outcomes
# - Stronger rejection for subsets → more structural zeros
# - R package: pscl::vuong()
#
# Interpretation: p < 0.05 supports presence of structural zeros

# TEST 2: LIKELIHOOD RATIO TEST: ZI vs NON-ZI MODEL
# -------------------------------------------------
# Nested model comparison:
# - Model 1: Zero-inflated negative binomial
# - Model 2: Standard negative binomial
#
# LRT statistic = 2 * (logLik(ZI) - logLik(non-ZI))
# df = difference in number of parameters
#
# Separate tests for each outcome
# Expected: larger LRT for vegan than total (more zero-inflation needed)

# TEST 3: RESTAURANT-LEVEL BINOMIAL TEST
# --------------------------------------
# For each restaurant, test if zero rate is consistent with sampling variation
#
# Setup:
# - Observed: k zeros out of n time periods
# - Expected under sampling: p_0 = P(Y=0 | Poisson(lambda_hat))
# - Binomial test: Is k/n significantly > p_0?
#
# Classification:
# - If p < 0.01 and k/n > p_0 → structural zero
# - Otherwise → consistent with sampling
#
# Advantage: Restaurant-specific, uses count distribution theory
# Limitation: Low power with few time periods

# TEST 4: MULTIMODALITY TEST ON ZERO RATES
# ----------------------------------------
# Hypothesis: Mixture of structural and sampling zeros creates bimodal distribution
# of restaurant-level zero rates
#
# Methods:
# - Hartigan's dip test for unimodality (diptest package)
# - Silverman's bandwidth test
#
# Apply to distribution of zero rates across restaurants
# Rejection → evidence for distinct structural zero subpopulation

# TEST 5: PANEL DATA UNIT ROOT TEST (adapted)
# -------------------------------------------
# Idea: Structural zeros are "stationary at zero"
#
# For restaurants with high zero rates:
# - Test if time series is stationary around zero
# - Use panel unit root tests (e.g., Im-Pesaran-Shin test)
# - Structural zeros → stationary at zero
# - Sampling zeros → potentially mean-reverting but not at zero
#
# R package: plm::purtest()
# Note: Requires adaptation for count data

# TEST 6: OVERDISPERSION TEST
# ---------------------------
# Logic: Structural zeros increase overdispersion beyond what Poisson allows
#
# Test statistic:
# - Compare variance to mean for each restaurant-outcome
# - If variance >> mean systematically → excess zeros likely structural
#
# Formal test: Dean's test, or dispersion parameter in NB model
# Compare dispersion across outcomes (expect higher for subsets)

# TEST 7: CROSS-OUTCOME CORRELATION TEST
# --------------------------------------
# Hypothesis: Restaurants with structural zeros for vegan also have them
# for textured meat (related categories)
#
# Approach:
# - Create binary indicator: high zero rate (1) or not (0) for each outcome
# - Test correlation: Phi coefficient or chi-square test
# - Structural zeros → high correlation across related outcomes
# - Sampling zeros → low correlation (independent)

# TEST 8: TIME HOMOGENEITY TEST
# -----------------------------
# Structural zeros persist over time; sampling zeros fluctuate
#
# For each restaurant:
# - Split time series in half (first half vs second half)
# - Compare zero rates between periods (Fisher's exact test)
# - Structural zero → no significant difference
# - Menu change → significant difference
#
# Flag restaurants with p > 0.1 as candidates for structural zeros


# ==============================================================================
# SECTION 4: LEVERAGING PANEL STRUCTURE
# ==============================================================================

# STRATEGY 1: WITHIN-RESTAURANT VARIANCE DECOMPOSITION
# ---------------------------------------------------
# Exploit repeated measures to separate persistent vs transient zeros
#
# Model:
# Y_it = structural_component_i + transient_component_it
#
# Estimation:
# - Calculate intraclass correlation (ICC) for zeros
# - High ICC → zeros are restaurant-specific (structural)
# - Low ICC → zeros vary over time (sampling)
#
# R approach: mixed model with random intercept for restaurant
# ICC = var(restaurant) / [var(restaurant) + var(residual)]

# STRATEGY 2: FIXED EFFECTS LOGIT FOR ZERO OCCURRENCE
# ---------------------------------------------------
# Model probability of zero as function of time-varying covariates
#
# logit(P(Y_it = 0)) = alpha_i + beta * X_it
#
# Restaurant fixed effects (alpha_i) capture structural propensity
# - Extract alpha_i estimates
# - Very negative alpha_i → low structural zero probability
# - Very positive alpha_i → high structural zero probability
#
# Advantage: Controls for unobserved restaurant heterogeneity

# STRATEGY 3: RANDOM EFFECTS ZERO-INFLATION MODEL
# -----------------------------------------------
# Extend ZI model with random effects on both components
#
# Structure:
# - Count component: lambda_it = exp(X_it * beta + u_i)
# - Zero-inflation: logit(pi_it) = W_it * gamma + v_i
# - u_i, v_i ~ Normal(0, sigma^2)
#
# Interpretation:
# - v_i > 0 → restaurant has persistent excess zeros (structural)
# - Predict restaurant-specific pi_i from posterior
#
# R package: glmmTMB with zi formula

# STRATEGY 4: GROWTH CURVE MODELING
# ---------------------------------
# Model zero rate trajectory over time for each restaurant
#
# Zero_rate_it = beta_0i + beta_1i * time + epsilon_it
#
# Classify based on trajectory:
# - beta_0i ≈ 1, beta_1i ≈ 0 → always zero (structural)
# - beta_0i < 1, beta_1i ≈ 0 → sometimes zero (sampling)
# - beta_1i < 0 → decreasing zeros (menu expansion)
# - beta_1i > 0 → increasing zeros (menu contraction)

# STRATEGY 5: LEAD-LAG ANALYSIS
# -----------------------------
# Test if zeros predict future zeros (persistence)
#
# Model: Y_it = f(Y_i,t-1, Y_i,t-2, ...)
#
# For structural zeros:
# - Strong autocorrelation: zero at t-1 → zero at t
# - Transition probabilities: P(0→0) ≈ 1, P(0→positive) ≈ 0
#
# For sampling zeros:
# - Weak autocorrelation
# - P(0→positive) > 0.2
#
# Estimate transition matrices for each restaurant

# STRATEGY 6: COHORT ANALYSIS
# ---------------------------
# Group restaurants by entry year into dataset
#
# Question: Do newer restaurants have different zero patterns?
# - Older cohorts may have more legacy structural zeros
# - Newer cohorts may reflect recent plant-based trends
#
# Compare zero rates across cohorts using panel methods
# Control for time effects vs cohort effects

# STRATEGY 7: BALANCED PANEL SUBSETTING
# -------------------------------------
# Focus on restaurants observed for full time span
#
# Rationale:
# - Unbalanced panels complicate structural zero identification
# - Restaurants with few observations may appear structural just due to limited data
#
# Analysis:
# - Require minimum 12 time points per restaurant
# - Re-run all analyses on balanced subset
# - Sensitivity check: do conclusions hold?

# STRATEGY 8: CROSS-SECTIONAL TIME-SERIES (TSCS) REGRESSION
# ---------------------------------------------------------
# Panel regression predicting zero occurrence
#
# Model:
# Zero_indicator_it = alpha_i + lambda_t + beta * X_it + epsilon_it
#
# Where:
# - alpha_i = restaurant fixed effects (structural component)
# - lambda_t = time fixed effects (market trends)
# - X_it = time-varying covariates
#
# Large alpha_i estimates identify structurally zero-prone restaurants
# Compare alpha_i across outcomes


# ==============================================================================
# SECTION 5: PITFALLS OF 3-SD APPROACH AND ALTERNATIVES
# ==============================================================================

# PITFALL 1: DISTRIBUTIONAL ASSUMPTIONS
# -------------------------------------
# Issue: SD assumes symmetric, normal-like distribution
# Reality: Count data is right-skewed, bounded at zero
#
# Consequence:
# - 3 SD below mean often implies negative values (impossible)
# - May flag too few observations as structural zeros
# - Arbitrary and unprincipled for count data
#
# Alternative:
# - Use quantile-based threshold (e.g., below 5th percentile)
# - Or model-based threshold from fitted ZI distribution

# PITFALL 2: GLOBAL VS LOCAL THRESHOLDS
# -------------------------------------
# Issue: Global mean/SD ignores heterogeneity across restaurant types
#
# Example:
# - Fine dining may have mean vegan count = 3
# - Fast food may have mean vegan count = 0.5
# - Global mean = 2.0 with SD = 1.5
# - Fast food zeros not flagged (within 3 SD) but may be structural
#
# Alternative:
# - Stratify by restaurant type, calculate type-specific thresholds
# - Or use restaurant-level history (never vs rarely)

# PITFALL 3: IGNORING TIME DIMENSION
# ----------------------------------
# Issue: Single cross-sectional snapshot can't distinguish persistence
#
# Example:
# - Restaurant has 0 vegan items in January (sampling zero)
# - Same restaurant has 0 in all 24 months (structural zero)
# - 3-SD rule treats both identically
#
# Alternative:
# - Require persistence: zero in 80%+ of observations
# - Or zero in all observations

# PITFALL 4: OUTCOME-SPECIFIC THRESHOLDS
# --------------------------------------
# Issue: Using same threshold across outcomes despite different scales
#
# Example:
# - Total dishes: mean = 50, SD = 20 → threshold = -10 (nonsensical)
# - Vegan count: mean = 2, SD = 3 → threshold = -7 (nonsensical)
# - Both hit floor at zero but have different excess zero rates
#
# Alternative:
# - Outcome-specific thresholds based on empirical zero rates
# - Or model-based (ZI model's pi parameter)

# PITFALL 5: CORRELATION STRUCTURE IGNORED
# ----------------------------------------
# Issue: Zeros across outcomes may be correlated
#
# Example:
# - Restaurant with zero vegan likely has zero textured meat
# - Should jointly model structural zero status
# - 3-SD rule treats outcomes independently
#
# Alternative:
# - Multivariate ZI model or latent class model
# - Identify restaurants structurally zero across multiple outcomes

# PITFALL 6: TEMPORAL CONFOUNDING
# -------------------------------
# Issue: Zero rates may change over time due to trends
#
# Example:
# - Vegan offerings increase industry-wide 2019-2024
# - Early period zeros may be structural (not available yet)
# - Late period zeros more likely sampling (menu rotation)
# - 3-SD rule doesn't account for time trends
#
# Alternative:
# - Include time fixed effects or trends
# - Period-specific structural zero classification

# PITFALL 7: SAMPLE SIZE SENSITIVITY
# ----------------------------------
# Issue: Threshold based on global statistics is sensitive to sample size
#
# With small N:
# - Mean/SD estimates are imprecise
# - 3-SD threshold has wide confidence interval
# - May misclassify structural zeros
#
# Alternative:
# - Bootstrap confidence intervals for threshold
# - Bayesian approach with prior on structural zero probability

# PITFALL 8: LACK OF VALIDATION
# -----------------------------
# Issue: No way to verify if 3-SD rule correctly identifies structural zeros
#
# Without ground truth:
# - Can't calculate sensitivity/specificity
# - Can't assess misclassification rate
# - Results not actionable for policy
#
# Alternative:
# - Manual validation sample (see Alternative 8 above)
# - Cross-validation: predict zeros in holdout time periods
# - Face validity: do flagged restaurants make sense?


# ==============================================================================
# SECTION 6: RECOMMENDED WORKFLOW
# ==============================================================================

# PHASE 1: EXPLORATORY VISUALIZATION (Week 1)
# -------------------------------------------
# 1. Create zero rate heatmap (Viz 1)
# 2. Plot zero duration histograms (Viz 2)
# 3. ECDF comparison across outcomes (Viz 5)
# 4. Scatterplot matrix of mean/var/zero_rate (Viz 4)
#
# Goal: Understand zero patterns, assess bimodality, compare outcomes

# PHASE 2: PANEL-BASED CLASSIFICATION (Week 2)
# --------------------------------------------
# 1. Calculate restaurant-level statistics:
#    - Zero rate across time
#    - Maximum observed value
#    - Longest zero streak
# 2. Classify using Alternative 1 (history-based rules)
# 3. Validate with Alternative 8 (expert review sample)
#
# Goal: Create empirical structural zero flags for each restaurant-outcome

# PHASE 3: MODEL-BASED REFINEMENT (Week 3)
# ----------------------------------------
# 1. Extract pi estimates from fitted ZI models
# 2. Compare empirical flags vs model-based pi (Alternative 2)
# 3. Fit random effects ZI model (Strategy 3)
# 4. Run Vuong test and LRT (Tests 1-2)
#
# Goal: Reconcile empirical and model-based approaches

# PHASE 4: SENSITIVITY ANALYSIS (Week 4)
# --------------------------------------
# 1. Vary threshold in Alternative 1 (90% → 80% → 95%)
# 2. Compare balanced vs full panel (Strategy 7)
# 3. Stratify by restaurant type (Pitfall 2 alternative)
# 4. Test temporal stability (Test 8)
#
# Goal: Assess robustness of structural zero classifications

# PHASE 5: REPORTING AND INTERPRETATION (Week 5)
# ----------------------------------------------
# 1. Create final classification table:
#    - Restaurant ID, outcome, structural_zero_flag, confidence_level
# 2. Summary statistics:
#    - % structural zeros by outcome (confirm subset > total hypothesis)
# 3. Visualizations for paper (Viz 1, 5, 6)
# 4. Sensitivity table showing classification agreement across methods
#
# Goal: Communicate findings, support substantive conclusions


# ==============================================================================
# SECTION 7: SPECIFIC HYPOTHESIS TEST
# ==============================================================================

# HYPOTHESIS: Subset outcomes have MORE structural zeros than total dishes
#
# Operationalization:
# - H0: P(structural zero | vegan) = P(structural zero | total)
# - HA: P(structural zero | vegan) > P(structural zero | total)
#
# Test statistic:
# - n_structural_vegan / n_restaurants vs n_structural_total / n_restaurants
# - McNemar's test for paired proportions (same restaurants)
# - Or chi-square if independent
#
# Power analysis:
# - Need sufficient restaurants to detect meaningful difference
# - If true rates are 40% vs 20%, need ~100 restaurants for power=0.8
#
# Supporting evidence:
# - Plot: bar chart of structural zero % by outcome type
# - Show confidence intervals
# - Report effect size (Cohen's h or odds ratio)


# ==============================================================================
# FINAL NOTES
# ==============================================================================

# Key takeaways:
#
# 1. The 3-SD rule is problematic for count data with zeros. Consider:
#    - Restaurant-level history (never vs sometimes zero)
#    - Model-based pi estimates from ZI models
#    - Quantile-based thresholds
#
# 2. Panel structure is your friend. Use it to distinguish:
#    - Persistent zeros (structural) from transient zeros (sampling)
#    - Between-restaurant vs within-restaurant variation
#
# 3. Visualization before modeling. Look for:
#    - Bimodal distributions of zero rates
#    - Clear separation between "always zero" and "sometimes zero" groups
#
# 4. Validate, validate, validate:
#    - Manual review sample
#    - Cross-validation
#    - Sensitivity to threshold choice
#
# 5. Context matters:
#    - Restaurant type (steakhouse vs vegan cafe)
#    - Time period (pre- vs post-plant-based trend)
#    - Outcome type (general vs niche categories)
#
# 6. For your hypothesis (subsets > total):
#    - Likely true, but quantify the difference
#    - Use formal test (McNemar's) not just descriptive comparison
#    - Consider confounders (restaurants with low total may have structural
#      zeros for all outcomes)

################################################################################
# END OF MEMO
################################################################################
