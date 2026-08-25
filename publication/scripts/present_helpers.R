# Helpers shared across forest plot scripts for "present/" mode —
# rebuilds HTMLs under present/ with click-to-open-pred-plot enabled.
# Normal mode (PRESENT_MODE=FALSE) is a no-op.

PRESENT_MODE <- Sys.getenv("PRESENT_MODE", "FALSE") == "TRUE"
REVIEW_MODE  <- Sys.getenv("REVIEW_MODE",  "FALSE") == "TRUE"

# Route output dir from the legacy "forest_plots/<...>" stub used in the
# create_*.R scripts to the actual on-disk locations:
#   default        -> publication/forest_plots/<...>   (forest plot tree
#                                                       lives under publication/
#                                                       after the 2026-04 reorg)
#   PRESENT_MODE   -> present/<...>                    (top-level interactive bundle)
#   REVIEW_MODE    -> review/review_t2_a2/<...>        (review HTML bundle,
#                                                       moved under review/ in
#                                                       the 2026-04 reorg)
present_path <- function(path) {
  if (REVIEW_MODE) return(gsub("^forest_plots/[^/]+/", "review/review_t2_a2/", path))
  if (PRESENT_MODE) return(gsub("^forest_plots/", "present/", path))
  # Publication mode. publication/forest_plots/ holds ONLY the two final
  # deliverables (professional_wide_fixed, professional_labeled_v2). Everything
  # the renderers write on the way there is precursor material and goes to the
  # top-level archive/ instead.
  #
  # archive/ rather than a nested z_precursors/ for a concrete reason: nesting
  # pushed the deepest plotly asset paths to 265 characters on a Windows
  # checkout, past the 260-character MAX_PATH limit, and `git pull` failed
  # outright. archive/forest_plots/ is 26 characters shorter than
  # archive/forest_plots/, which takes the worst path to 235
  # and leaves ~25 characters of headroom instead of 8.
  if (grepl("^forest_plots/z_log_and_overlay(/|$)", path))
    return(sub("^forest_plots/z_log_and_overlay", "archive/forest_plots/logs", path))
  if (grepl("^forest_plots/(total_adjusted|base)(/|$)", path))
    return(sub("^forest_plots/", "archive/forest_plots/", path))
  gsub("^forest_plots/", "publication/forest_plots/", path)
}

# From review_t2_a2/<tier>/*.html, relative path to the clipped-overlap review plot:
# review/overlap_plots_clipped/proportion_targeted/<outcome>/<exposure>/tier2/<rest>.png
# Backfill pred_path for pooled rows by taking a sibling restaurant's pred_path
# (same outcome/exposure/effect_type) and swapping the trailing <rest>.png for
# all_restaurants_weekly.png. Idempotent; pooled rows that already have a path
# (or have no matching restaurant sibling) are left unchanged.
add_pooled_pred_path <- function(df) {
  if (!PRESENT_MODE) return(df)
  if (!"pred_path" %in% names(df) || !"estimate_type" %in% names(df)) return(df)
  key_cols <- intersect(c("outcome", "exposure", "exposure_type", "exposure_group",
                          "effect_type", "series"), names(df))
  if (!length(key_cols)) return(df)
  rest <- df[df$estimate_type == "Restaurant" & !is.na(df$pred_path),
             c(key_cols, "pred_path"), drop = FALSE]
  if (!nrow(rest)) return(df)
  rest <- rest[!duplicated(rest[, key_cols, drop = FALSE]), , drop = FALSE]
  rest$pred_path <- sub("/[^/]+\\.png$", "/all_restaurants_weekly.png", rest$pred_path)
  pooled_idx <- which(df$estimate_type == "Pooled")
  if (!length(pooled_idx)) return(df)
  key_of <- function(sub) do.call(paste, c(lapply(sub[, key_cols, drop = FALSE], as.character), sep = "\x1f"))
  m <- match(key_of(df[pooled_idx, , drop = FALSE]), key_of(rest))
  new_paths <- rest$pred_path[m]
  cur <- df$pred_path[pooled_idx]
  df$pred_path[pooled_idx] <- ifelse(is.na(cur), new_paths, cur)
  df
}

review_path_rel <- function(outcome, exposure, rest_id) {
  if (!REVIEW_MODE) return(NA_character_)
  # HTML lives at review/review_t2_a2/<tier>/*.html (3 levels deep) after the
  # 2026-04 reorg, so step up 3 to reach repo root before descending into review/.
  file.path("..", "..", "..", "review", "overlap_plots_clipped", "proportion_targeted",
            outcome, exposure, "tier2", paste0(rest_id, ".png"))
}

# Wrap a plotly object with an onRender click handler that opens
# d.points[0].customdata in a new tab. Pass-through when !PRESENT_MODE.
add_click_handler <- function(p_plotly) {
  if (!PRESENT_MODE && !REVIEW_MODE) return(p_plotly)
  htmlwidgets::onRender(p_plotly, "
    function(el) {
      el.on('plotly_click', function(d) {
        var pt = d.points[0];
        var u = pt && pt.customdata;
        if (u) window.open(u, '_blank', 'noopener');
      });
    }")
}

# Relative path from present/<tier_dir>/*.html to model_fits/<root>/<analysis>/<outcome>[/<exposure>]/plots/<rest>.png
# tier_dir is e.g., "base/t1" or "total_adjusted/t2" — the HTML is 2 levels deep in present/,
# model_fits/ is copied in at present/model_fits/, so go up 2 and into model_fits.
pred_path_rel <- function(root, analysis, outcome, exposure, rest_id) {
  if (!PRESENT_MODE) return(NA_character_)
  parts <- c("..", "..", "model_fits", root, analysis, outcome)
  if (!is.null(exposure) && !is.na(exposure) && nzchar(exposure)) parts <- c(parts, exposure)
  # rest_id = NULL or "pooled" → combined across-restaurants plot
  fname <- if (is.null(rest_id) || is.na(rest_id) || identical(rest_id, "pooled") || identical(rest_id, "POOLED"))
             "all_restaurants_weekly.png"
           else paste0(rest_id, ".png")
  parts <- c(parts, "plots", fname)
  do.call(file.path, as.list(parts))
}
