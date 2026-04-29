# Simulation Results: z_scale=1.0, R=12

## Setup

- **Model**: Zero-Inflated Negative Binomial INGARCH (model_multilevel_transfer_zi.stan)
- **Restaurants**: R=12, each with N_train=400, N_test=20
- **z_scale**: 1.0 for all NCP parameters (fix for sigma collapse)
- **INGARCH alpha lags**: p_effective=12, sparse: c(1,2,3,4,5,6,7,14,21,28,35,42)
- **INGARCH delta lags**: q_effective=12 (same sparse set) for delta runs; q_effective=0 for no-delta runs
- **Chains**: 2 per run
- **Warmup/Sampling**: 700/800 iterations
- **Seeds**: 101, 202, 303 (R seed for DGP; Stan seed=same)

## Per-Run Results

### mu_gamma and Sigma Parameters

| Parameter (true) | ND-101 | ND-202 | ND-303 | D-101 | D-202 | D-303 |
|---|---|---|---|---|---|---|
| **mu_gamma** (0.150) | 0.126 [0.068, 0.184] | 0.119 [0.065, 0.176] | 0.176 [0.132, 0.218] | 0.156 [0.092, 0.218] | 0.116 [0.050, 0.184] | 0.189 [0.117, 0.265] |
| sigma_gamma_between (0.080) | 0.108 [0.066, 0.166] | 0.095 [0.051, 0.152] | 0.067 [0.016, 0.117] | 0.124 [0.075, 0.199] | 0.131 [0.082, 0.204] ** | 0.131 [0.078, 0.210] |
| sigma_gamma_within (0.040) | 0.074 [0.007, 0.183] | 0.100 [0.019, 0.219] | 0.069 [0.005, 0.174] | 0.060 [0.004, 0.168] | 0.073 [0.007, 0.188] | 0.109 [0.024, 0.226] |
| sigma_beta_intercept (0.300) | 0.200 [0.112, 0.324] | 0.361 [0.239, 0.532] | 0.248 [0.143, 0.390] | 0.182 [0.026, 0.373] | 0.248 [0.050, 0.469] | 0.204 [0.031, 0.395] |

### Nuisance Globals

| Parameter (true) | ND-101 | ND-202 | ND-303 | D-101 | D-202 | D-303 |
|---|---|---|---|---|---|---|
| mu_beta_intercept (3.500) | 3.526 | 3.222 ** | 3.469 | 3.635 | 3.483 | 3.580 |
| mu_phi_log (1.609) | 1.539 | 1.640 | 1.534 | 1.550 | 1.636 | 1.572 |
| sigma_phi_log (0.200) | 0.249 | 0.158 | 0.226 | 0.231 | 0.170 | 0.234 |
| mu_pi_logit (-2.944) | -3.007 | -3.104 | -2.968 | -2.993 | -3.090 | -2.949 |
| sigma_pi_logit (0.200) | 0.414 ** | 0.240 | 0.179 | 0.382 ** | 0.205 | 0.235 |

### INGARCH Alpha Parameters

| Parameter (true) | ND-101 | ND-202 | ND-303 | D-101 | D-202 | D-303 |
|---|---|---|---|---|---|---|
| mu_alpha_random_raw[1] (0.200) | 0.176 | 0.199 | 0.207 | 0.176 | 0.193 | 0.216 |
| mu_alpha_random_raw[2] (0.100) | 0.073 | 0.092 | 0.087 | 0.074 | 0.069 | 0.102 |
| sigma_alpha_random[1] (0.080) | 0.072 | 0.107 | 0.101 | 0.084 | 0.106 | 0.096 |
| sigma_alpha_random[2] (0.050) | 0.074 | 0.075 | 0.071 | 0.072 | 0.075 | 0.033 |

### INGARCH Delta Parameters (delta runs only)

| Parameter (true) | D-101 | D-202 | D-303 |
|---|---|---|---|
| mu_delta_random_raw[1] (0.150) | 0.101 [-0.045, 0.252] | 0.182 [0.030, 0.326] | 0.161 [0.020, 0.311] |
| mu_delta_random_raw[2] (0.080) | 0.076 [-0.049, 0.193] | 0.071 [-0.029, 0.170] | 0.199 [0.104, 0.291] ** |
| sigma_delta_random[1] (0.060) | 0.082 [0.011, 0.171] | 0.101 [0.018, 0.193] | 0.103 [0.020, 0.188] |
| sigma_delta_random[2] (0.040) | 0.095 [0.039, 0.168] | 0.035 [0.003, 0.088] | 0.063 [0.009, 0.124] |

### Predictor Parameters

| Parameter (true) | ND-101 | ND-202 | ND-303 | D-101 | D-202 | D-303 |
|---|---|---|---|---|---|---|
| mu_beta_random[1] price (0.050) | 0.058 | 0.049 | 0.050 | 0.035 | 0.040 | 0.045 |
| mu_beta_random[2] weekend (0.100) | 0.087 | 0.137 ** | 0.148 ** | 0.097 | 0.145 ** | 0.121 |
| mu_beta_random[3] season (0.020) | 0.001 ** | 0.022 | 0.016 | 0.024 | 0.027 | 0.013 |
| mu_beta_fixed[1] temp (-0.020) | -0.034 ** | -0.034 ** | -0.017 | -0.009 ** | -0.026 | -0.016 |
| mu_beta_fixed[2] precip (-0.010) | -0.011 | -0.014 | -0.000 | -0.009 | 0.000 | -0.012 |

### Diagnostics

| Metric | ND-101 | ND-202 | ND-303 | D-101 | D-202 | D-303 |
|---|---|---|---|---|---|---|
| Divergences | 0 | 0 | 0 | 0 | 0 | 0 |
| Max Rhat | 1.009 | 1.010 | 1.012 | 1.014 | 1.014 | 1.010 |
| Overall 90% coverage | 87.1% | 87.1% | - | 93.3% | - | - |

## Condition Averages

| Parameter (true) | No-Delta Avg | Delta Avg |
|---|---|---|
| **mu_gamma** (0.150) | **0.140** | **0.154** |
| sigma_gamma_between (0.080) | 0.090 | 0.129 |
| sigma_gamma_within (0.040) | 0.081 | 0.081 |
| sigma_beta_intercept (0.300) | 0.270 | 0.211 |

## Parameter Recovery Summary

### Recovers well (6/6 or 5/6 coverage, reasonable point estimates)

| Parameter | True | Avg Est | Coverage | Notes |
|---|---|---|---|---|
| **mu_gamma** | 0.150 | 0.147 | **6/6** | The main parameter of interest |
| mu_alpha_random_raw[1] | 0.200 | 0.195 | 6/6 | |
| mu_alpha_random_raw[2] | 0.100 | 0.083 | 6/6 | Slight underest but all CIs cover |
| sigma_alpha_random[1] | 0.080 | 0.094 | 6/6 | |
| sigma_gamma_between | 0.080 | 0.109 | 5/6 | No longer collapsed |
| sigma_beta_intercept | 0.300 | 0.257 | 6/6 | Variable but CIs cover |
| mu_beta_intercept | 3.500 | 3.486 | 5/6 | |
| mu_phi_log | 1.609 | 1.579 | 6/6 | |
| sigma_phi_log | 0.200 | 0.211 | 6/6 | |
| mu_pi_logit | -2.944 | -3.019 | 6/6 | |
| mu_beta_random[1] (price) | 0.050 | 0.046 | 6/6 | |
| mu_beta_random[3] (season) | 0.020 | 0.018 | 5/6 | |
| sigma_beta_random (all 3) | various | close | 18/18 | |
| mu_beta_fixed[2] (precip) | -0.010 | -0.008 | 6/6 | |
| mu_delta_random_raw[1] | 0.150 | 0.148 | 3/3 | Wide CIs but covers |
| Restaurant-level betas | various | good | ~97% | |

### Recovers OK but with caveats

| Parameter | True | Avg Est | Coverage | Issue |
|---|---|---|---|---|
| sigma_gamma_within | 0.040 | 0.081 | 6/6 | CIs cover but systematically 2x overestimated, very wide CIs |
| sigma_alpha_random[2] | 0.050 | 0.067 | 6/6 | Consistently overestimated (5/6 runs ~0.07) |
| sigma_pi_logit | 0.200 | 0.276 | 4/6 | Tends to overestimate, 2 misses (both seed 101) |
| sigma_delta_random | 0.060/0.040 | ~0.095/0.064 | 6/6 | Covered but overestimated |
| phi (per-restaurant) | various | various | ~85% | Slightly worse than expected 90% |
| pi (per-restaurant) | various | various | ~85% | Same |

### Doesn't recover well

| Parameter | True | Avg Est | Coverage | Issue |
|---|---|---|---|---|
| z_gamma (within-rest exposure deviates) | various | ~0 | Technically OK | Point estimates are uninformative. True values like 1.5 or -2.5 estimated near 0. CIs span [-2, 2]. The within-restaurant exposure signal (sigma_gamma_within=0.04) is too small for individual z's to be identified. |
| mu_beta_fixed[1] (temp) | -0.020 | -0.023 | **3/6** | Worst-recovering global param. Inconsistent bias direction across seeds. |
| mu_beta_random[2] (weekend) | 0.100 | 0.123 | **3/6** | Systematically overestimated in seeds 202/303 |
| mu_delta_random_raw[2] | 0.080 | 0.115 | 2/3 | One seed overestimates at 0.199 |

## Key Conclusions

1. **z_scale=1.0 was the critical fix.** The previous z_scale=3.0 created a 3x scaling ambiguity in the NCP sigma*z product, causing all sigma parameters to collapse to ~1/3 of their true values. This in turn biased mu_gamma because the hierarchical shrinkage structure was distorted.

2. **Delta lags do NOT confound mu_gamma** when z_scale is correct. With z_scale=1.0, both delta and no-delta models recover mu_gamma equally well (avg 0.154 vs 0.140, both covering 0.150).

3. **Sigma_gamma_within is the weakest variance component.** At true=0.040, the within-restaurant exposure variation is small relative to other sources of variation, making individual z_gamma deviates essentially unidentifiable. The hierarchical mean (mu_gamma) is still well-recovered because it pools across 12 restaurants.

4. **For real data**: z_scale should be 1.0 for all NCP parameters. To express less informative priors, increase the sigma prior scale, not z_scale.
