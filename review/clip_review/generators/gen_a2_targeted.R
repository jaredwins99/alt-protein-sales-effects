suppressMessages({library(arrow); library(dplyr); library(ggplot2); library(tidyr); library(jsonlite)})
# Usage:  Rscript gen_a2_targeted.R [out_dir]      (run from the repo root)
# Writes <out_dir>/a2_targeted.json, default out_dir = review/clip_review/build
args <- commandArgs(trailingOnly = TRUE)
OUT  <- if (length(args)) args[1] else "review/clip_review/build"
dir.create(file.path(OUT, "plots"), showWarnings = FALSE, recursive = TRUE)
source("model_scripts/ingarch_scripts/1_data_ingarch.R")

UNIV <- list(
  "2HRX9P6HKXA8V"=c("2019-01-01","2023-08-01"), "JHDN7CF1C03X5"=c(NA,"2023-06-01"),
  "EMBVNVD207CC6"=c("2016-06-01","2022-09-01"), "LBZEEFSBJNB3Z"=c("2021-09-01","2023-07-01"),
  "CB2KHY1C2G9PT"=c("2020-06-01","2023-04-01"), "LFZFT3VASXPED"=c("2021-10-01","2022-11-01"),
  "75WYSXR9QBK5M"=c("2022-05-01","2023-07-01"), "SAFK7ND1HR6XS"=c("2019-04-18","2020-03-25"))

MODS <- list(
 breakfast=c("2HRX9P6HKXA8V","ED5J990H5VAZT","L69HYJ4Y3TR91","78AY09MVJVTYE","9XKJD8DQTH559","CB2KHY1C2G9PT","EMBVNVD207CC6","LBZEEFSBJNB3Z","LQ5EH4BKGV61T","V3Q26BHF3SE2H"),
 chicken=c("JHDN7CF1C03X5","W8T41JZK0ZMEP","9XKJD8DQTH559","V3Q26BHF3SE2H"),
 dairy=c("ED5J990H5VAZT","JHDN7CF1C03X5","W8T41JZK0ZMEP","9XKJD8DQTH559","C0BE4NDSW26QN","EMBVNVD207CC6","LBZEEFSBJNB3Z","SAFK7ND1HR6XS","V3Q26BHF3SE2H"),
 egg=c("ED5J990H5VAZT","W8T41JZK0ZMEP","LBZEEFSBJNB3Z","78AY09MVJVTYE","V3Q26BHF3SE2H"),
 textured=c("9XKJD8DQTH559","SAFK7ND1HR6XS"),
 untextured=c("SRQS8F7JWA9MZ","1SQPTEGYPH0GA","9XKJD8DQTH559","C0BE4NDSW26QN","CB2KHY1C2G9PT","LQ5EH4BKGV61T","S8MT0YGD2KTN9"))

LABEL <- c(breakfast="Breakfast-style meat", chicken="Chicken", dairy="Dairy",
           egg="Egg", textured="Whole-muscle meat", untextured="Ground meat")

roll <- function(x,k=30) stats::filter(x, rep(1/k,k), sides=2)

# TRAILING mean over the previous k days (partial at the start). Causal: the
# line can never rise before the event that caused it, so edge artifacts in the
# smoother are never mistaken for data artifacts.
roll_trail <- function(x, k = 21) {
  n <- length(x); cs <- c(0, cumsum(x))
  lo <- pmax(1, seq_len(n) - k + 1)
  round((cs[seq_len(n) + 1] - cs[lo]) / (seq_len(n) - lo + 1), 2)
}

# ---- recommend clip: first/last month with sustained coverage ----
recommend <- function(s) {
  s$mo <- format(s$date, "%Y-%m")
  m <- s %>% group_by(mo) %>%
       summarise(nz=sum(total_outcome>0), mn=ifelse(nz>0, mean(total_outcome[total_outcome>0]), 0), .groups="drop")
  pk <- max(m$mn)
  ok <- which(m$nz >= 8 & m$mn >= 0.20*pk)
  if (!length(ok)) return(list(start=NA, end=NA, why="no sustained month"))
  first_mo <- m$mo[min(ok)]; last_mo <- m$mo[max(ok)]
  st <- min(s$date[s$mo==first_mo & s$total_outcome>0])
  en <- max(s$date[s$mo==last_mo & s$total_outcome>0])
  lead <- sum(s$date < st & s$total_outcome > 0)
  tail_ <- sum(s$date > en & s$total_outcome > 0)
  list(start=as.character(st), end=as.character(en),
       why=sprintf("drops %d lead + %d tail nonzero days", lead, tail_))
}

pages <- list()
for (cat_ in names(MODS)) {
  d <- read_parquet(sprintf("data/4_data_parquet_modeling/a2_proportion_t/finalized_%s_dishes_count.parquet", cat_))
  dp <- read_parquet(sprintf("data/4_data_parquet_modeling/a2_proportion_t/finalized_%s_dishes_presence.parquet", cat_))
  oc <- paste0(cat_, "_outcome_p")
  for (r in MODS[[cat_]]) {
    s <- d %>% filter(location_id==r) %>% arrange(date)
    if (!nrow(s)) next
    ex <- grep(paste0("^exposure_",r), names(s), value=TRUE); ex <- ex[sapply(ex,function(c) any(s[[c]]!=0))]
    v  <- if (length(ex)) s[[ex[1]]] else rep(0, nrow(s))
    sp <- dp %>% filter(location_id==r) %>% arrange(date)
    exp2 <- grep(paste0("^exposure_",r), names(sp), value=TRUE); exp2 <- exp2[sapply(exp2,function(c) any(sp[[c]]!=0))]
    vp <- if (length(exp2)) sp[[exp2[1]]] else rep(0, nrow(sp))

    uf <- UNIV[[r]]; cc <- clip_dates_proportion_targeted[[cat_]][[r]]
    rec <- recommend(s)

    # monthly coverage
    mo <- s %>% mutate(mo=format(date,"%Y-%m")) %>% group_by(mo) %>%
      summarise(days=n(), nz=sum(total_outcome>0),
                tot=round(ifelse(nz>0, mean(total_outcome[total_outcome>0]),0),1),
                out=round(sum(.data[[oc]]),0), exp=max(v[match(mo, format(s$date,"%Y-%m"))]), .groups="drop") %>% as.data.frame()
    mo$exp <- sapply(mo$mo, function(mm) max(v[format(s$date,"%Y-%m")==mm]))

    # exposure runs
    rl <- rle(v); ends <- cumsum(rl$lengths); starts <- ends-rl$lengths+1
    runs <- data.frame(from=as.character(s$date[starts]), to=as.character(s$date[ends]),
                       val=rl$values, days=rl$lengths)

    pc <- round(100*max(table(v))/length(v))
    key <- paste0(r,"__",cat_)

    # ---- plot ----
    pd <- data.frame(date=s$date, total=roll(s$total_outcome), outcome=roll(s[[oc]]), exposure=roll(v)) %>%
          pivot_longer(-date, names_to="series", values_to="y") %>% filter(!is.na(y))
    p <- ggplot(pd, aes(date,y,colour=series)) + geom_line(linewidth=0.5) +
      scale_y_continuous(trans="log1p", breaks=c(0,1,3,10,30,100,300,1000)) +
      scale_colour_manual(values=c(total="grey60", outcome="#c0392b", exposure="#27ae60")) +
      labs(x=NULL,y=NULL) + theme_minimal(base_size=9) +
      theme(legend.position="bottom", legend.title=element_blank(),
            panel.grid.minor=element_blank())
    if (!is.null(uf)) {
      lo <- if (is.na(uf[1])) min(s$date) else as.Date(uf[1]); hi <- if (is.na(uf[2])) max(s$date) else as.Date(uf[2])
      p <- p + annotate("rect", xmin=lo, xmax=hi, ymin=-Inf, ymax=Inf, alpha=0.07, fill="black")
    }
    if (!is.null(cc)) p <- p + geom_vline(xintercept=as.Date(c(cc$start,cc$end)), colour="#2980b9", linewidth=0.5)
    if (!is.na(rec$start)) p <- p + geom_vline(xintercept=as.Date(c(rec$start,rec$end)), colour="#e67e22", linetype="22", linewidth=0.7)
    ggsave(file.path(OUT, "plots", paste0(key,".png")), p, width=10, height=3.1, dpi=120)

    pages[[key]] <- list(
      key=key, restaurant=r, category=cat_, outcome_label=unname(LABEL[cat_]),
      analysis="T2 A2", models=paste0("A2_T2_",cat_,"_{count,presence}"),
      units=sum(s[[oc]]), pct_zero=round(100*mean(s[[oc]]==0)),
      n_days=nrow(s), date_min=as.character(min(s$date)), date_max=as.character(max(s$date)),
      exp_distinct_count=length(unique(v)), exp_mode_pct=pc,
      exp_distinct_presence=length(unique(vp)),
      universal=if (is.null(uf)) NULL else list(start=uf[1], end=uf[2]),
      cat_clip=if (is.null(cc)) NULL else list(start=cc$start, end=cc$end),
      rec=rec, monthly=mo, runs=runs,

      # ---- plot payloads (formerly separate series/cum/steps passes) ----
      # daily trailing-mean series, indexed from d0 so JS can offset by day
      series = list(d0 = as.character(min(s$date)),
                    total   = roll_trail(s$total_outcome),
                    outcome = roll_trail(s[[oc]])),
      # exact first/last day with data / with outcome
      marks = list(
        first_data = if (any(s$total_outcome>0)) as.character(min(s$date[s$total_outcome>0])) else NULL,
        last_data  = if (any(s$total_outcome>0)) as.character(max(s$date[s$total_outcome>0])) else NULL,
        first_out  = if (any(s[[oc]]>0)) as.character(min(s$date[s[[oc]]>0])) else NULL,
        last_out   = if (any(s[[oc]]>0)) as.character(max(s$date[s[[oc]]>0])) else NULL),
      # exposure as exact step change-points, not a smoothed line
      exp_steps = list(date = c(as.character(s$date[starts]), as.character(max(s$date))),
                       val  = c(rl$values, tail(rl$values, 1))),
      exp_max = max(v),
      # cumulative arrays on a gap-free daily grid -> live unit accounting
      cum = local({
        d0 <- min(s$date); grid <- seq(d0, max(s$date), by = "day")
        o <- t_ <- dd <- rep(0, length(grid))
        idx <- as.integer(s$date - d0) + 1
        o[idx] <- s[[oc]]; t_[idx] <- s$total_outcome; dd[idx] <- as.integer(s$total_outcome > 0)
        list(d0 = as.character(d0), n = length(grid),
             out = cumsum(o), tot = cumsum(t_), days = cumsum(dd))
      }))
  }
}
write_json(pages, file.path(OUT, "a2_targeted.json"), auto_unbox=TRUE, digits=4, na="null")
cat("wrote", length(pages), "pages\n")
