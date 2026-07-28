#!/usr/bin/env Rscript
# slim_extract_one.R <model_dir> <out_rds>
#
# Pass 1 of the two-pass adjusted-estimate extraction.
#
# Reads ONE fit (fit.rds or samples.rds) in a dedicated process and writes a
# small "slim" file holding only the draws we actually need:
#   mu_gamma[m]                     - pooled exposure effect per param
#   beta[col, rest] for exposures   - per-introduction effect, named by model_col
#   eta[m, rest]                    - per-restaurant mean exposure effect
# plus the metadata needed to join by NAME (predictor_map, restaurants_order).
#
# Why a separate process per fit: a fit.rds materialises every parameter on
# readRDS (lambda, log_lik, y_rep ...), which is ~2.9x its on-disk size in RAM.
# The variables we need are tiny (beta is ~15 MB even at 6000 x 324), so the
# peak is entirely readRDS. Running one fit per process means the OS reclaims
# that peak before the next fit starts, and we never hold an outcome AND a
# total fit at the same time -- which the current extractors do.
#
# Slim files are ~1-50 MB, so pass 2 can join them with trivial memory.

suppressPackageStartupMessages({
  library(posterior)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("usage: slim_extract_one.R <model_dir> <out_rds>")
model_dir <- args[1]
out_rds   <- args[2]

read_draws_any <- function(dir) {
  # samples.rds is a plain named list of draw vectors; fit.rds is a CmdStanMCMC.
  sp <- file.path(dir, "samples.rds")
  if (file.exists(sp)) {
    s <- readRDS(sp)
    return(list(kind = "samples", obj = s))
  }
  fp <- file.path(dir, "fit.rds")
  if (file.exists(fp)) {
    suppressPackageStartupMessages(library(cmdstanr))
    f <- readRDS(fp)
    return(list(kind = "fit", obj = f))
  }
  stop("no fit.rds or samples.rds in ", dir)
}

# Pull a variable group as a draws_matrix, returning NULL if absent.
grab <- function(src, group) {
  if (src$kind == "fit") {
    ok <- tryCatch({
      any(sub("\\[.*", "", src$obj$metadata()$variables) == group)
    }, error = function(e) FALSE)
    if (!ok) return(NULL)
    m <- tryCatch(as.matrix(src$obj$draws(variables = group, format = "draws_matrix")),
                  error = function(e) NULL)
    return(m)
  }
  nm <- names(src$obj)
  keep <- nm[sub("\\[.*", "", nm) == group]
  if (!length(keep)) return(NULL)
  m <- do.call(cbind, lapply(keep, function(k) as.numeric(src$obj[[k]])))
  colnames(m) <- keep
  m
}

dl   <- tryCatch(readRDS(file.path(model_dir, "data_list.rds")),        error = function(e) NULL)
pmap <- tryCatch(readRDS(file.path(model_dir, "predictor_map.rds")),    error = function(e) NULL)
rest <- tryCatch(readRDS(file.path(model_dir, "restaurants_order.rds")), error = function(e) NULL)

src <- read_draws_any(model_dir)

mu  <- grab(src, "mu_gamma")
eta <- grab(src, "eta")
bet <- grab(src, "beta")

# Keep only the exposure columns of beta, labelled by model_col + restaurant so
# pass 2 can join by name instead of by index (this is the bug being fixed).
beta_expo <- NULL
if (!is.null(bet) && !is.null(dl) && !is.null(pmap) && length(dl$idx_exposure)) {
  keep <- character(0); lab <- character(0); labrest <- character(0)
  for (k in seq_along(dl$idx_exposure)) {
    col <- dl$idx_exposure[k]
    r   <- dl$expo_to_rest[k]
    vn  <- sprintf("beta[%d,%d]", col, r)
    if (!(vn %in% colnames(bet))) next
    mc <- pmap$model_col[pmap$col_index == col][1]
    if (is.na(mc)) next
    keep    <- c(keep, vn)
    lab     <- c(lab, mc)
    labrest <- c(labrest, if (!is.null(rest) && r <= length(rest)) rest[r] else NA_character_)
  }
  if (length(keep)) {
    beta_expo <- bet[, keep, drop = FALSE]
    colnames(beta_expo) <- lab           # name-keyed, not index-keyed
    attr(beta_expo, "restaurant") <- labrest
    attr(beta_expo, "param")      <- dl$expo_to_param[match(keep, sprintf("beta[%d,%d]", dl$idx_exposure, dl$expo_to_rest))]
  }
}

# eta labelled as eta[param, restaurantName]
if (!is.null(eta) && !is.null(rest)) {
  cn <- colnames(eta)
  ix <- regmatches(cn, regexec("eta\\[(\\d+),(\\d+)\\]", cn))
  pr <- vapply(ix, function(x) if (length(x) == 3) as.integer(x[2]) else NA_integer_, integer(1))
  rr <- vapply(ix, function(x) if (length(x) == 3) as.integer(x[3]) else NA_integer_, integer(1))
  attr(eta, "param")      <- pr
  attr(eta, "restaurant") <- ifelse(!is.na(rr) & rr <= length(rest), rest[rr], NA_character_)
}

slim <- list(
  model_dir         = model_dir,
  n_draws           = if (!is.null(mu)) nrow(mu) else if (!is.null(bet)) nrow(bet) else 0L,
  mu_gamma          = mu,
  eta               = eta,
  beta_expo         = beta_expo,
  restaurants_order = rest,
  source            = src$kind
)

dir.create(dirname(out_rds), showWarnings = FALSE, recursive = TRUE)
saveRDS(slim, out_rds, compress = "xz")

cat(sprintf("OK %s | draws=%d mu_gamma=%s eta=%s beta_expo=%s | out %.1f MB\n",
            model_dir, slim$n_draws,
            if (is.null(mu)) "-" else paste(dim(mu), collapse="x"),
            if (is.null(eta)) "-" else paste(dim(eta), collapse="x"),
            if (is.null(beta_expo)) "-" else paste(dim(beta_expo), collapse="x"),
            file.size(out_rds)/2^20))
