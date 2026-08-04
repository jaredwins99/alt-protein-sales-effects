suppressMessages({library(arrow); library(dplyr); library(stringr); library(purrr); library(jsonlite)})
# Usage:  Rscript gen_a4_its.R [out_dir]      (run from the repo root)
# Writes <out_dir>/a4_its.json, default out_dir = review/clip_review/build
args <- commandArgs(trailingOnly = TRUE)
OUT  <- if (length(args)) args[1] else "review/clip_review/build"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

UNIV <- list(
  "2HRX9P6HKXA8V"=c("2019-01-01","2023-08-01"), "JHDN7CF1C03X5"=c(NA,"2023-06-01"),
  "EMBVNVD207CC6"=c("2016-06-01","2022-09-01"), "LBZEEFSBJNB3Z"=c("2021-09-01","2023-07-01"),
  "CB2KHY1C2G9PT"=c("2020-06-01","2023-04-01"), "LFZFT3VASXPED"=c("2021-10-01","2022-11-01"),
  "75WYSXR9QBK5M"=c("2022-05-01","2023-07-01"), "SAFK7ND1HR6XS"=c("2019-04-18","2020-03-25"))

LABEL <- c(breakfast="Breakfast-style meat", dairy="Dairy", textured="Whole-muscle meat",
           untextured="Ground meat", chicken="Chicken")

intro_tbl <- read.csv("data/mpba_introductions.csv") %>%
  mutate(date = as.character(as.Date(substr(intro_date,1,10))))

raw <- read_parquet("data/4_data_parquet_modeling/its/finalized.parquet")
# Optional: if the A2 pages exist, reuse their dish/analog tables for the same
# (restaurant, category) so the A4 page shows the same qualitative context.
.a2 <- file.path(OUT, "a2_targeted.json")
A2  <- if (file.exists(.a2)) fromJSON(.a2, simplifyVector = FALSE) else list()

# trailing 21d mean: causal, cannot rise before an event
trail <- function(x, k=21) {
  cs <- cumsum(c(0, x)); n <- length(x)
  out <- (cs[(1:n)+1] - cs[pmax(1, (1:n)+1-k)]) / pmin(1:n, k)
  round(as.numeric(out), 2)
}

starters <- c(Sys.glob("model_starters/a4_its_t/A4_*.R"), Sys.glob("model_starters/t2_a4_its_t/A4_T2_*.R"))
cells <- list()
for (f in starters) {
  blob  <- paste(sub("#.*$","",readLines(f, warn=FALSE)), collapse=" ")
  out   <- str_match(blob, 'outcome\\s*=\\s*"([^"]+)"')[,2]
  rests <- str_match_all(str_match(blob,'restaurants_to_model\\s*=\\s*c\\(([^)]*)\\)')[,2],"'([A-Za-z0-9]+)'")[[1]][,2]
  cat_  <- sub("_t2$","", out)
  for (r in rests) cells[[paste0(r,"__",cat_,"__A4")]] <-
    c(cells[[paste0(r,"__",cat_,"__A4")]], list(list(file=basename(f), out=out, rest=r, cat=cat_)))
}

pages <- list()
for (key in names(cells)) {
  cl <- cells[[key]][[1]]
  r <- cl$rest; oc <- paste0(cl$out, "_outcome")
  tiers <- paste(unique(map_chr(cells[[key]], ~ if (grepl("_T2_", .x$file)) "T2" else "T1")), collapse="+")
  models <- paste(unique(map_chr(cells[[key]], ~ sub("\\.R$","",.x$file))), collapse=", ")

  s <- raw %>% filter(location_id == r) %>% arrange(date)
  uf <- UNIV[[r]]
  if (!is.null(uf)) {
    if (!is.na(uf[1])) s <- s %>% filter(date > as.Date(uf[1]))
    if (!is.na(uf[2])) s <- s %>% filter(date < as.Date(uf[2]))
  }
  s <- s %>% filter(total_outcome > 0)
  if (!nrow(s) || is.null(s[[oc]]) || sum(s[[oc]]) == 0) next
  s <- s[seq_len(floor(0.95*nrow(s))), ]          # train rows only

  y <- s[[oc]]; tot <- s$total_outcome
  ex <- grep(paste0("^exposure_", r, "_"), names(s), value=TRUE)
  ex <- setdiff(ex, "exposure_JHDN7CF1C03X5_2")
  ex <- ex[sapply(ex, function(c0) any(s[[c0]] != 0))]
  v  <- if (length(ex)) s[[ex[1]]] else rep(0, nrow(s))
  i1 <- which(v > 0)[1]
  npre <- if (is.na(i1)) nrow(s) else i1 - 1L

  lead0 <- which(y > 0)[1] - 1L
  tail0 <- nrow(s) - max(which(y > 0))
  post  <- y[(npre+1):length(y)]

  # ---- sensitivity: does dropping more of the head converge? ----
  sens <- map_dfr(c(0, 30, 60, 90, 120, 180), function(k) {
    if (k >= npre) return(NULL)
    p <- y[(k+1):npre]
    data.frame(drop = paste0(k, "d"), `pre n` = length(p),
               `pre mean` = round(mean(p), 2),
               `zero %` = round(100*mean(p == 0)),
               `naive step` = sprintf("%+.0f%%", 100*(mean(post)/mean(p) - 1)),
               check.names = FALSE)
  })
  steps <- as.numeric(sub("%","", sub("\\+","", sens$`naive step`)))
  spread <- if (length(steps) > 1) max(steps) - min(steps) else 0
  converged <- length(steps) > 2 && abs(steps[length(steps)] - steps[length(steps)-1]) < 0.15*max(1,abs(steps[1]))

  # recommendation
  if (lead0 >= 60) {
    rec <- list(start = as.character(s$date[lead0 + 1]), end = as.character(max(s$date)),
                why = sprintf("%d consecutive structural zeros before first sale", lead0))
    verdict <- sprintf("CLIP head: %d consecutive zero-outcome days = product absent; natural cut at first sale %s.",
                       lead0, as.character(s$date[lead0 + 1]))
  } else {
    rec <- list(start = as.character(min(s$date)), end = as.character(max(s$date)),
                why = "no structural zero run at head")
    verdict <- sprintf("NO CLIP: head has %d zero days, pre-period %.1f%% zeros; step slides %.0f pts across cut points with no plateau = trend, not artifact.",
                       lead0, 100*mean(y[1:npre] == 0), spread)
  }

  mo <- s %>% mutate(mo = format(date, "%Y-%m")) %>% group_by(mo) %>%
        summarise(days = n(), out = round(sum(.data[[oc]])),
                  tot = round(mean(total_outcome)), exp = max(v[match(mo, format(s$date,"%Y-%m"))]),
                  .groups = "drop") %>% as.data.frame()
  mo$exp <- sapply(mo$mo, function(mm) max(v[format(s$date,"%Y-%m") == mm]))

  rl <- rle(v); ends <- cumsum(rl$lengths); starts <- ends - rl$lengths + 1
  runs <- data.frame(from = as.character(s$date[starts]), to = as.character(s$date[ends]),
                     val = rl$values, days = rl$lengths)

  intros <- intro_tbl %>% filter(location_id == r) %>%
            transmute(name = promo_name, date = date) %>% arrange(date) %>% as.data.frame()

  twin <- A2[[paste0(r, "__", cl$cat)]]
  # per-FIELD fallback: a twin page that lacks the dish enrichment must not
  # inject NULL (jsonlite writes that as {}, which breaks numeric formatting)
  tw <- function(f, default) {
    v <- if (is.null(twin)) NULL else twin[[f]]
    if (is.null(v) || length(v) == 0) default else v
  }
  pages[[key]] <- list(
    analogs = tw("analogs", paste(intros$name, collapse=", ")),
    analog_dishes = tw("analog_dishes", list()),
    dishes = tw("dishes", list()),
    n_dishes = tw("n_dishes", 0L),
    n_animal = tw("n_animal", 1L),
    animal_units = tw("animal_units", sum(y)),
    plant_units = tw("plant_units", 0L),
    mod_units = tw("mod_units", 0L),
    pre_first_analog = tw("pre_first_analog", NA_character_),
    pre_units = tw("pre_units", NA_integer_),
    exp_mode_pct = round(100*max(table(v))/length(v)),
    exp_distinct_count = length(unique(v)), exp_distinct_presence = length(unique(v)),
    key = key, restaurant = r, category = cl$cat, outcome_label = unname(LABEL[cl$cat]),
    analysis = paste(tiers, "A4 (ITS)"), models = models,
    units = sum(y), pct_zero = round(100*mean(y == 0)), n_days = nrow(s),
    date_min = as.character(min(s$date)), date_max = as.character(max(s$date)),
    n_pre = npre, n_post = length(post),
    intro_date = if (is.na(i1)) NA_character_ else as.character(s$date[i1]),
    lead0 = lead0, tail0 = tail0,
    pre_mean = round(mean(y[1:npre]), 2), post_mean = round(mean(post), 2),
    converged = converged, spread = round(spread),
    universal = if (is.null(uf)) NULL else list(start = uf[1], end = uf[2]),
    cat_clip = NULL,
    rec = rec, verdict_line = verdict,
    sensitivity = sens, monthly = mo, runs = runs, intros = intros,
    marks = list(first_data = as.character(min(s$date)), last_data = as.character(max(s$date)),
                 first_out = as.character(s$date[which(y>0)[1]]),
                 last_out  = as.character(s$date[max(which(y>0))])),
    exp_steps = list(date = as.character(s$date[starts]), val = rl$values),
    exp_max = max(1, v),
    series = list(d0 = as.character(min(s$date)), total = trail(tot), outcome = trail(y)),
    cum = list(d0 = as.character(min(s$date)), n = nrow(s),
               out = cumsum(y), tot = cumsum(tot), days = seq_len(nrow(s)))
  )
}

# candidates first
ord <- names(pages)[order(-sapply(pages, function(p) p$lead0))]
pages <- pages[ord]
write_json(pages, file.path(OUT, "a4_its.json"), auto_unbox = TRUE, digits = 4, na = "null")
cat("wrote", length(pages), "A4 pages\n")
for (k in names(pages)) cat(sprintf("  %-30s lead0=%-4d %s\n", k, pages[[k]]$lead0,
                                    substr(pages[[k]]$verdict_line, 1, 60)))
