# Toolchain behind the 131 published fits

## What is and isn't pinned today

| component | pinned? | where |
|---|---|---|
| R 4.4.2 | yes | `renv.lock` |
| R packages, incl. `cmdstanr` 0.9.0 | yes | `renv.lock` |
| **CmdStan (the C++ toolchain)** | **no** | see below |

`renv` pins the `cmdstanr` *R package*, not CmdStan itself. CmdStan is a separate
C++ install and nothing in the repo fixes its version:

- `Dockerfile:30` runs `cmdstanr::install_cmdstan(...)` with **no `version=`**, so
  every image build takes whatever CmdStan is latest that day.
- `.Rprofile:5` hardcodes `~/.cmdstan/cmdstan-2.38.0`.
- CmdStan **2.36.0** is required by 65 of the 131 fits and appears nowhere in the
  repo.

Fix for the image (one line):

    RUN Rscript -e 'cmdstanr::install_cmdstan(version = "2.38.0", dir = "/usr/local/share", cores = parallel::detectCores())'

To reproduce the 2.36.0 fits, that version has to be installed alongside:

    Rscript -e 'cmdstanr::install_cmdstan(version = "2.36.0", dir = "/usr/local/share")'

## Per-era toolchain

All 131 share: `adapt_delta 0.85`, `seed 123`, NUTS/HMC, `diag_e` metric,
`stepsize_jitter 0`, and CmdStan's default adaptation schedule
(gamma 0.05, kappa 0.75, t0 10, init_buffer 75, term_buffer 50, window 25).

| era | fits | CmdStan | parameterization | iterations | thin | treedepth |
|---|---|---|---|---|---|---|
| `finalized_redone_trunc` | 52 | 2.36.0 | non-centered | 1500/2000 (4 fits 750/1000) | 1 | 10 |
| `finalized_redone_trunc_cp` | 49 | 2.36.0 + 2.38.0 | centered (36) / non-centered gaussian (8) | 1500/2000 | 1 or 2 | 10 or 12 |
| `finalized_uncontaminated` | 3 | 2.38.0 | centered | 1500/2000 | 1 | 12 |
| `finalized_uncontaminated2` | 27 | 2.38.0 (22) + 2.36.0 (5) | centered (22) / non-centered gaussian (5) | 1500/2000 | 1 or 2 | 10 or 12 |

Chains are nominally 3 everywhere (`CORES_PER_MODEL <- 3`). Fits recording 1 or 2
chains are ones where chains **died**, not a different configuration —
`nrow(metadata$time)` matches the surviving count.

The Stan-version split is **machine-dependent, not code-dependent**: 2.36.0 fits
ran on a second box (`~/.cmdstan/cmdstan-2.36.0`). That is why five
`finalized_uncontaminated2` A6 fits dated 2026-08-07 report 2.36.0 and treedepth
10 while their siblings from 08-04 report 2.38.0 and treedepth 12.

## Source files by parameterization

`_cp` in the era name means **centered parameterization**. The 2026-03-04 refactor
switched the truncated model from `z_beta_intercept` to `beta_intercept_r`; the
customer Gaussian model switched on 2026-03-16. Fits before those dates will not
reproduce against the current files.

| model | parameterization | `.stan` | init function |
|---|---|---|---|
| truncated | non-centered | `e28ffe8c` | `3e52f8ad` |
| truncated | centered (`_cp`) | HEAD (= `33e67db7`) | `33e67db7` |
| truncated | centered (Aug eras) | HEAD | HEAD (= `a9f8c504`, R==1 array fix) |
| gaussian_iid | non-centered | `c0c8d560` | `c0c8d560` |
| gaussian_iid | centered | HEAD (= `bdca7845`) | HEAD |

The current `.stan` files are byte-identical to `33e67db7` / `bdca7845`, so HEAD is
safe for centered fits (verified 2026-09-01).

**Inits are not optional.** `init_ingarch()` / `init_gaussian_iid()` draw from
`rnorm()` with no internal seed — they are reproducible only because the caller
does `set.seed(seed)` first — and they changed with the same refactors. Sampling
these models from random inits kills 100% of chains on
`neg_binomial_2_lpmf: Location parameter is inf`.

## Refitting exactly

`publication/scripts/refit_exact.R` reconstructs a fit from the recorded
hyperparameters in `publication/model_hyperparameters.csv`.

    Rscript publication/scripts/refit_exact.R --list       # 131 fits and their settings
    Rscript publication/scripts/refit_exact.R --dry-run    # what would run, no work
    Rscript publication/scripts/refit_exact.R --only <fit> # stage one refit

It writes to `model_fits_refit/` by default, **not** over `model_fits/`. That is
deliberate: the point of an exact refit is to check whether the pinned toolchain
reproduces a published fit, and that comparison needs the original still sitting
next to the new one. 180 of the 194 `fit.rds` have no `samples.rds` alongside
them, so they are the only surviving artefact of runs that took days, some under
a CmdStan version the repo cannot install by itself.

To refit over the originals anyway, say so explicitly:

    Rscript publication/scripts/refit_exact.R --into-model-fits

Any `--out` that lands in `model_fits/` without that flag is refused before any
work starts.
