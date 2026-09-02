#!/usr/bin/env Rscript
## refit_exact.R -- re-run the 131 published fits with the exact sampler
## settings and Stan source each one originally used.
##
## Nothing here is inferred from the current code. Every setting is read back
## out of the fit itself:
##
##   metadata.rds   chains, iter_warmup, iter_sampling, thin, adapt_delta,
##                  max_treedepth, seed, and the parameter names that reveal
##                  which parameterization the model was compiled with
##   data_list.rds  the exact Stan data that was sampled
##
## Because data_list.rds is the real Stan input, this reproduces the SAMPLING
## step directly and does not depend on the data-prep code still behaving the
## way it did months ago.
##
## Two Stan sources are needed. The 2026-03-04 refactor switched the truncated
## model from a non-centered to a centered parameterization -- that switch is
## what the "_cp" era name refers to -- and the customer Gaussian model made the
## same switch on 2026-03-16. Fits from before those dates will not reproduce
## against the current .stan files, so the pre-switch blobs are pulled out of
## git by commit.
##
## Feeding the rest of the pipeline
## ---------------------------------
## Output layout mirrors model_fits/ exactly: <out>/<era>/<analysis>/<outcome>/
## <exposure>/ containing fit.rds, metadata.rds, data_list.rds, predictor_map.rds
## and restaurants_order.rds -- the five files slim_extract_one.R wants.
##
## run_slim_pass1.sh enumerates from need_dirs.csv and names its output by
## stripping the leading "model_fits/", so the refit tree has to live at
## model_fits/<era>/... for the names to come out right. Either point --out at a
## staging dir and move it into place, or refit straight into model_fits/ (which
## overwrites the originals -- take a copy first).
##
## From there the existing chain runs unchanged:
##   run_slim_pass1.sh   -> publication/published_draws/*.rds   (131 files, 53 MB)
##   adj_join_pass2.R    -> publication/forest_data_adj_95ci_fixed.csv
##   renderers           -> forest plots;  final_tables.R -> tables
## which is exactly what `python run_pipeline.py --from-fits` does.
##
## Usage:
##   Rscript refit_exact.R --list
##   Rscript refit_exact.R --out /path/to/output            # all 131
##   Rscript refit_exact.R --out DIR --era finalized_redone_trunc
##   Rscript refit_exact.R --out DIR --only a1_proportion/meat
##   Rscript refit_exact.R --out DIR --dry-run

suppressPackageStartupMessages({
  library(cmdstanr); library(dplyr)
})

REPO      <- Sys.getenv("REPO_ROOT", getwd())
MANIFEST  <- file.path(REPO, "publication/scripts/adj_fixed_pairs.csv")
STAN_DIR  <- file.path(REPO, "models")
CACHE     <- file.path(tempdir(), "stan_src")

## model_name -> (parameterization -> where the source comes from).
## "HEAD" means the file in models/ is byte-identical to the era's version,
## verified 2026-09-01 against 33e67db7 and bdca7845.
## Initial values matter as much as the sampler settings here. The runner built
## them with init_ingarch() / init_gaussian_iid(), which draw from rnorm() and
## are therefore only reproducible because the caller does set.seed(seed) first.
## Those functions changed with the same centered/non-centered refactor, and
## again on 2026-08-01 ("force vector-typed inits to stay arrays", the R==1 fix),
## so the era decides which version to source.
##
## Skipping inits entirely does NOT work: with random inits these INGARCH models
## start at inf/0 intensities and every chain dies in early warmup.
INIT_SOURCES <- list(
  truncated = list(
    `non-centered` = list(ref = "3e52f8ad", fn = "init_ingarch",
                          file = "model_scripts/ingarch_scripts/3_init_ingarch.R"),
    `centered-pre-aug` = list(ref = "33e67db7", fn = "init_ingarch",
                          file = "model_scripts/ingarch_scripts/3_init_ingarch.R"),
    `centered`     = list(ref = "HEAD", fn = "init_ingarch",
                          file = "model_scripts/ingarch_scripts/3_init_ingarch.R")
  ),
  gaussian_iid = list(
    `non-centered` = list(ref = "c0c8d560", fn = "init_gaussian_iid",
                          file = "model_scripts/ingarch_scripts_customer_gaussian_iid/3_init_gaussian_iid.R"),
    `centered`     = list(ref = "HEAD", fn = "init_gaussian_iid",
                          file = "model_scripts/ingarch_scripts_customer_gaussian_iid/3_init_gaussian_iid.R")
  )
)

## The August eras carry the R==1 init fix; _cp predates it.
init_variant <- function(model, param, era) {
  if (param == "non-centered") return("non-centered")
  if (model == "truncated" && era == "finalized_redone_trunc_cp") return("centered-pre-aug")
  "centered"
}

STAN_SOURCES <- list(
  truncated = list(
    centered       = list(path = "models/model_multilevel_transfer_truncated.stan"),
    `non-centered` = list(path = "models/model_multilevel_transfer_truncated_noncentered.stan",
                          ref  = "e28ffe8c:models/model_multilevel_transfer_truncated.stan")
  ),
  gaussian_iid = list(
    centered       = list(path = "models/model_multilevel_transfer_customer_gaussian_iid.stan"),
    `non-centered` = list(path = "models/model_multilevel_transfer_customer_gaussian_iid_noncentered.stan",
                          ref  = "c0c8d560:models/model_multilevel_transfer_customer_gaussian_iid.stan")
  )
)

INIT_SOURCES <- list(
  truncated = list(
    fn = "init_ingarch",
    `non-centered` = list(path = "model_scripts/ingarch_scripts/3_init_ingarch_noncentered.R",
                          ref  = "3e52f8ad:model_scripts/ingarch_scripts/3_init_ingarch.R"),
    `centered`     = list(path = "model_scripts/ingarch_scripts/3_init_ingarch.R")
  ),
  gaussian_iid = list(
    fn = "init_gaussian_iid",
    `non-centered` = list(path = "model_scripts/ingarch_scripts_customer_gaussian_iid/3_init_gaussian_iid_noncentered.R",
                          ref  = "c0c8d560:model_scripts/ingarch_scripts_customer_gaussian_iid/3_init_gaussian_iid.R"),
    `centered`     = list(path = "model_scripts/ingarch_scripts_customer_gaussian_iid/3_init_gaussian_iid.R")
  )
)

## Only two init variants are needed. The 2026-08-01 change (a9f8c504) is purely
## additive -- it wraps non-scalar inits in as.array() so Stan accepts a length-1
## vector -- and is value-preserving otherwise. Checked against all 36 centered
## _cp fits: the pre-August and current init functions produce identical values,
## and none of those fits has a length-1 non-scalar parameter, so the fix never
## engages. The current 3_init_ingarch.R therefore reproduces them exactly.
init_variant <- function(model, param, era) {
  if (param == "non-centered") "non-centered" else "centered"
}

## Resolve a staged source: prefer the archived file in the repo, fall back to
## the git blob it was taken from if that file has not been added yet.
resolve_src <- function(entry, target) {
  if (!is.null(entry$path) && file.exists(file.path(REPO, entry$path))) {
    file.copy(file.path(REPO, entry$path), target, overwrite = TRUE)
    return(entry$path)
  }
  if (is.null(entry$ref)) stop("missing ", entry$path, " and no git fallback")
  blob <- system2("git", c("-C", shQuote(REPO), "show", shQuote(entry$ref)), stdout = TRUE)
  if (!length(blob)) stop("could not read ", entry$ref)
  writeLines(blob, target)
  paste0(entry$ref, " (git fallback)")
}

args     <- commandArgs(trailingOnly = TRUE)
getarg   <- function(flag, default = NA) {
  i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[i + 1]
}
OUT      <- getarg("--out")
ERA      <- getarg("--era")
ONLY     <- getarg("--only")
DRY      <- "--dry-run" %in% args
## --validate: run a handful of iterations per fit instead of the real thing.
## Proves the stored data_list, the era's .stan and the era's init function are
## mutually compatible and that a chain can actually start -- which is exactly
## what fails silently if the inits are wrong. It does NOT check the estimates.
VALIDATE <- "--validate" %in% args
VAL_ITER <- as.integer(getarg("--validate-iter", "1"))
LIST     <- "--list" %in% args

## ---- read the spec straight out of each fit ------------------------------

spec_for <- function(path) {
  md <- file.path(path, "metadata.rds")
  dl <- file.path(path, "data_list.rds")
  if (!file.exists(md) || !file.exists(dl)) return(NULL)
  m <- readRDS(md)
  v <- m$stan_variables
  param <- if ("z_beta_intercept" %in% v) "non-centered"
           else if ("beta_intercept_r" %in% v) "centered"
           else NA_character_
  list(
    path          = path,
    era           = strsplit(path, "/")[[1]][2],
    rel           = sub("^model_fits/[^/]+/", "", path),
    model         = if (grepl("gaussian", m$model_name[[1]])) "gaussian_iid" else "truncated",
    param         = param,
    chains        = length(m$id),
    iter_warmup   = m$iter_warmup[[1]],
    iter_sampling = m$iter_sampling[[1]],
    thin          = m$thin[[1]],
    adapt_delta   = m$adapt_delta[[1]],
    max_treedepth = m$max_treedepth[[1]],
    seed          = m$seed[[1]],
    stan_version  = paste(m$stan_version_major[[1]], m$stan_version_minor[[1]],
                          m$stan_version_patch[[1]], sep = "."),
    restaurants   = if (file.exists(file.path(path, "restaurants_order.rds")))
                      readRDS(file.path(path, "restaurants_order.rds")) else NA
  )
}

pairs <- read.csv(MANIFEST, stringsAsFactors = FALSE)
paths <- unique(c(pairs$fit, pairs$total))
specs <- Filter(Negate(is.null), lapply(paths, spec_for))
if (!is.na(ERA))  specs <- Filter(function(s) s$era == ERA, specs)
if (!is.na(ONLY)) specs <- Filter(function(s) grepl(ONLY, s$rel, fixed = TRUE), specs)

if (LIST || DRY) {
  cat(sprintf("%d fits\n\n", length(specs)))
  cat(sprintf("%-26s %-46s %-5s %-12s %2s %5s %5s %2s %5s %2s\n",
              "era", "fit", "model", "param", "ch", "warm", "samp", "th", "delta", "td"))
  for (s in specs)
    cat(sprintf("%-26s %-46s %-5s %-12s %2d %5d %5d %2d %5.2f %2d\n",
                s$era, s$rel, substr(s$model, 1, 5), s$param, s$chains,
                s$iter_warmup, s$iter_sampling, s$thin, s$adapt_delta, s$max_treedepth))
  quit(status = 0)
}

if (is.na(OUT)) stop("--out is required (or pass --list / --dry-run)")

## ---- resolve and compile each distinct (model, parameterization) ---------

dir.create(CACHE, recursive = TRUE, showWarnings = FALSE)
compiled <- list()

get_model <- function(model, param) {
  key <- paste(model, param, sep = "/")
  if (!is.null(compiled[[key]])) return(compiled[[key]])
  entry  <- STAN_SOURCES[[model]][[param]]
  if (is.null(entry)) stop("no Stan source registered for ", key)
  target <- file.path(CACHE, sprintf("%s_%s.stan", model, gsub("-", "_", param)))
  from   <- resolve_src(entry, target)
  message(sprintf("  compiling %s (%s) from %s", model, param, from))
  compiled[[key]] <<- cmdstan_model(target)
  compiled[[key]]
}

init_envs <- list()
get_init_fn <- function(model, param, era) {
  variant <- init_variant(model, param, era)
  key <- paste(model, variant, sep = "/")
  if (is.null(init_envs[[key]])) {
    entry <- INIT_SOURCES[[model]][[variant]]
    if (is.null(entry)) stop("no init source registered for ", key)
    target <- file.path(CACHE, sprintf("init_%s_%s.R", model, gsub("-", "_", variant)))
    from <- resolve_src(entry, target)
    e <- new.env(parent = globalenv())
    sys.source(target, envir = e)
    message(sprintf("  init %s (%s) from %s", model, variant, from))
    init_envs[[key]] <<- list(env = e, fn = INIT_SOURCES[[model]]$fn, variant = variant)
  }
  init_envs[[key]]
}

## ---- run -----------------------------------------------------------------

log_rows <- list()
for (i in seq_along(specs)) {
  s <- specs[[i]]
  dest <- file.path(OUT, s$era, s$rel)
  cat(sprintf("[%d/%d] %s/%s\n", i, length(specs), s$era, s$rel))
  if (!VALIDATE && dir.exists(dest) && length(list.files(dest, pattern = "\\.csv$"))) {
    cat("        already present, skipping\n"); next
  }
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  mod  <- get_model(s$model, s$param)
  data <- readRDS(file.path(s$path, "data_list.rds"))
  ini  <- get_init_fn(s$model, s$param, s$era)
  ## seed first, exactly as run_ingarch.R does, then draw one init per chain
  set.seed(s$seed)
  init_fn <- function(chain_id = 1) do.call(ini$fn, list(data, chain_id), envir = ini$env)
  t0   <- Sys.time()
  do_sample <- function(nchain, niter, show) tryCatch(mod$sample(
    data              = data,
    init              = init_fn,
    seed              = s$seed,
    chains            = nchain,
    parallel_chains   = nchain,
    iter_warmup       = if (VALIDATE) niter else s$iter_warmup,
    iter_sampling     = if (VALIDATE) niter else s$iter_sampling,
    thin              = s$thin,
    adapt_delta       = s$adapt_delta,
    max_treedepth     = s$max_treedepth,
    refresh           = if (VALIDATE) 0 else 250,
    show_messages     = show
  ), error = function(e) NULL)

  fit <- do_sample(if (VALIDATE) 1L else s$chains, VAL_ITER, !VALIDATE)
  retried <- FALSE
  if (VALIDATE && (is.null(fit) || is.null(tryCatch(fit$metadata(), error = function(e) NULL)))) {
    ## At 1 iteration there is no adaptation, so a single chain that draws an
    ## awkward init just dies. Retry the way the fit was actually run -- its own
    ## chain count, so one surviving chain is enough -- with a few more iterations.
    cat("        retrying with", s$chains, "chains /", max(VAL_ITER * 10L, 10L), "iter\n")
    retried <- TRUE
    fit <- do_sample(s$chains, max(VAL_ITER * 10L, 10L), FALSE)
  }
  if (is.null(fit)) cat("        FAILED: sample() errored\n")
  if (is.null(fit)) {
    log_rows[[length(log_rows) + 1]] <- data.frame(
      era = s$era, fit = s$rel, model = s$model, param = s$param, status = "FAILED",
      chains = NA, warmup = NA, sampling = NA, thin = NA, adapt_delta = NA,
      max_treedepth = NA, init_variant = NA, seed = NA, orig_stan = s$stan_version,
      new_stan = NA, minutes = NA, stringsAsFactors = FALSE)
    write.csv(bind_rows(log_rows), file.path(OUT, "refit_log.csv"), row.names = FALSE)
    next
  }
  ## sample() can return a fit whose chains all died; metadata() then throws.
  ## Treat that as a failure rather than letting it halt the sweep.
  fmeta <- tryCatch(fit$metadata(), error = function(e) NULL)
  if (is.null(fmeta)) {
    cat("        FAILED: chains produced no usable output\n")
    log_rows[[length(log_rows) + 1]] <- data.frame(
      era = s$era, fit = s$rel, model = s$model, param = s$param, status = "FAILED",
      chains = NA, warmup = NA, sampling = NA, thin = NA, adapt_delta = NA,
      max_treedepth = NA, init_variant = NA, seed = NA, orig_stan = s$stan_version,
      new_stan = NA, minutes = NA, stringsAsFactors = FALSE)
    write.csv(bind_rows(log_rows), file.path(OUT, "refit_log.csv"), row.names = FALSE)
    next
  }
  if (!VALIDATE) {
    ## publication/scripts/slim_extract_one.R reads fit.rds (or samples.rds) plus
    ## data_list.rds, predictor_map.rds and restaurants_order.rds from the same
    ## directory. Write all four so the refit tree drops straight into
    ## run_slim_pass1.sh -> published_draws/ -> adj_join_pass2.R -> the plots.
    fit$save_object(file = file.path(dest, "fit.rds"))
    saveRDS(fmeta, file.path(dest, "metadata.rds"))
    for (aux in c("data_list.rds", "predictor_map.rds", "restaurants_order.rds")) {
      src_aux <- file.path(s$path, aux)
      if (file.exists(src_aux)) file.copy(src_aux, file.path(dest, aux), overwrite = TRUE)
      else warning("missing ", aux, " for ", s$rel, call. = FALSE)
    }
  }
  log_rows[[length(log_rows) + 1]] <- data.frame(
    era = s$era, fit = s$rel, model = s$model, param = s$param,
    status = if (retried) "OK (retry)" else "OK",
    chains = s$chains, warmup = s$iter_warmup, sampling = s$iter_sampling,
    init_variant = ini$variant,
    thin = s$thin, adapt_delta = s$adapt_delta, max_treedepth = s$max_treedepth,
    seed = s$seed, orig_stan = s$stan_version,
    new_stan = paste(fmeta$stan_version_major, fmeta$stan_version_minor,
                     fmeta$stan_version_patch, sep = "."),
    minutes = round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
    stringsAsFactors = FALSE)
  write.csv(bind_rows(log_rows), file.path(OUT, "refit_log.csv"), row.names = FALSE)
}
cat("\ndone. settings actually used are in ", file.path(OUT, "refit_log.csv"), "\n", sep = "")
