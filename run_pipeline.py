#!/usr/bin/env python
"""Rebuild the published figures and tables.

    python run_pipeline.py                 # from committed draws  (minutes)
    python run_pipeline.py --from-fits     # re-extract from model_fits/  (hours)
    python run_pipeline.py --refit         # refit the models first  (days)
    python run_pipeline.py --list
    python run_pipeline.py --skip-html     # omit the interactive bundle (needs node)

By default nothing is refitted. The fits are 184 GB and are not distributed;
publication/published_draws/ holds the parameters every published estimate
needs, so the plot table is regenerated from those. --refit is for changing the
models, not for reproducing the published figures.

Run from the repo root.
"""
import argparse, glob, importlib.util, os, subprocess, sys, time

ROOT = os.path.dirname(os.path.abspath(__file__))

# The twelve published analyses -> the starter directory that produces each.
# See publication/MODEL_MAP.md. A5/A6 are day-level; the *_transaction starter
# directories are model-selection leftovers and are deliberately not listed.
PUBLISHED_STARTERS = [
    "a1_proportion", "a2_proportion_t", "a3_its", "a4_its_t",
    "customer", "customer_targeted",
    "t2_a1_proportion", "t2_a2_proportion_t", "t2_a3_its", "t2_a4_its_t",
    "t2_customer", "t2_customer_targeted",
]


def r(*args):
    return ["Rscript", *args]


def fit_steps():
    out = []
    for d in PUBLISHED_STARTERS:
        for f in sorted(glob.glob(os.path.join(ROOT, "model_starters", d, "*.R"))):
            out.append((f"fit {d}/{os.path.basename(f)}", r(os.path.relpath(f, ROOT))))
    return out


def steps(mode, skip_html, skip_diagrams=False):
    s = []
    if mode == "refit":
        # A5/A6 fit at the day level and read
        # data/4_data_parquet_modeling/customer_day/finalized.parquet, which is
        # built here from the handoff rather than shipped by restaurant-sales.
        # Without this the customer-day chain has no producer on the pipeline.
        s += [("customer-day aggregation",
               r("model_scripts/customer_analysis/level_day/aggregate_customer_to_restday.R"))]
        s += fit_steps()
    if mode in ("refit", "from-fits"):
        s += [("slim extraction from model_fits/",
               ["bash", "publication/scripts/run_slim_pass1.sh", "publication/published_draws"])]
    s += [
        ("plot table from draws",
         r("publication/scripts/adj_join_pass2.R", "publication/published_draws",
           "publication/scripts/adj_fixed_pairs.csv",
           "publication/forest_data_adj_95ci_fixed.csv")),
        ("forest plots — sorted",  r("publication/render/render_professional_wide_fixed.R")),
        ("forest plots — labeled", r("publication/render/render_professional_labeled_v2.R")),
        ("table inputs",           r("publication/scripts/build_final_models.R")),
        ("tables (unadjusted RR)", r("publication/scripts/final_tables.R")),
        ("collect tables to markdown",
         [sys.executable, "publication/scripts/build_final_tables_md.py"]),
        ("mu/gamma parameter tables", r("publication/scripts/extract_mu_gamma_tables.R")),
    ]
    if not skip_diagrams:
        s += [
            ("design diagrams",
             [sys.executable, "publication/exposure_design_diagram.py"]),
            ("design diagram (LaTeX style)",
             [sys.executable, "publication/exposure_design_diagram_latex.py"]),
        ]
    if not skip_html:
        s.append(("interactive bundle", ["bash", "publication/render/render_present.sh"]))
    return s


def preflight(mode, skip_html, skip_diagrams=False):
    p = []
    if not os.path.isdir(os.path.join(ROOT, "publication")):
        p.append("publication/ not found — is this the repo root?")

    if mode == "default" and not glob.glob(os.path.join(ROOT, "publication", "published_draws", "*.rds")):
        p.append("publication/published_draws/ is empty — pass --from-fits or --refit")
    if mode in ("refit", "from-fits") and not os.path.isdir(os.path.join(ROOT, "model_fits")):
        p.append("model_fits/ not found — the fits are not distributed; "
                 "run without --from-fits to use the committed draws")

    res = subprocess.run(["Rscript", "--vanilla", "-e", "cat(as.character(getRversion()))"],
                         capture_output=True, text=True)
    ver = res.stdout.strip().splitlines()[-1].strip() if res.stdout.strip() else ""
    if res.returncode:
        p.append("Rscript not found on PATH — install R 4.4.2")
    elif ver != "4.4.2":
        p.append(f"Rscript is R {ver}, expected 4.4.2 — the renv library is built for 4.4.2")
    else:
        res = subprocess.run(
            ["Rscript", "-e",
             'cat(all(sapply(c("ggplot2","patchwork","dplyr","arrow"), requireNamespace, quietly=TRUE)))'],
            cwd=ROOT, capture_output=True, text=True)
        if "TRUE" not in res.stdout:
            p.append("R packages not installed. From the repo root, in R:\n"
                     "        source('renv/activate.R'); renv::restore()\n"
                     "      Activate the project first — a plain `Rscript -e \"renv::restore()\"` "
                     "installs to the cache without linking, and exits 0.\n"
                     "      This repo has its own lockfile, separate from restaurant-sales.")

    # The design-diagram steps are the only Python in the pipeline that needs
    # third-party packages; everything else is standard library.
    missing = [] if skip_diagrams else [
        m for m in ("matplotlib", "numpy") if importlib.util.find_spec(m) is None]
    if missing:
        p.append(f"python packages missing for the design diagrams: {', '.join(missing)} — "
                 f"`pip install {' '.join(missing)}`, or pass --skip-diagrams")

    if not skip_html and subprocess.run(["which", "node"], capture_output=True).returncode:
        p.append("node not found — install it, or pass --skip-html")

    if p:
        print("Cannot start:\n")
        for x in p:
            print(f"  - {x}")
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="start", type=int, default=1)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--skip-html", action="store_true")
    ap.add_argument("--skip-diagrams", action="store_true",
                    help="omit the design diagrams (skips the matplotlib requirement)")
    ap.add_argument("--refit", action="store_true", help="refit every published model first (days)")
    ap.add_argument("--from-fits", action="store_true", help="re-extract draws from model_fits/ (hours)")
    a = ap.parse_args()

    mode = "refit" if a.refit else ("from-fits" if a.from_fits else "default")
    st = steps(mode, a.skip_html, a.skip_diagrams)

    if a.list:
        print(f"  mode: {mode}\n")
        for i, (name, cmd) in enumerate(st, 1):
            print(f"  {i:>3}. {name}")
        return 0

    preflight(mode, a.skip_html, a.skip_diagrams)
    print(f"mode: {mode}   steps: {len(st)}")

    t0 = time.time()
    failed = []
    for i, (name, cmd) in enumerate(st, 1):
        if i < a.start:
            continue
        print(f"\n=== [{i}/{len(st)}] {name}", flush=True)
        t = time.time()
        p = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if p.returncode:
            err = p.stderr.decode().strip().splitlines()
            failed.append((i, name, err[-1] if err else "(no stderr)"))
            print(f"    FAILED exit {p.returncode}   {time.time()-t:5.0f}s", flush=True)
        else:
            print(f"    ok                {time.time()-t:5.0f}s", flush=True)

    print(f"\n{'='*68}\ndone in {(time.time()-t0)/60:.1f} min")
    if failed:
        print(f"\nFAILED — {len(failed)} step(s):")
        for i, name, err in failed:
            print(f"  [{i}] {name}\n        {err}")
        print(f"\nResume after fixing:  python run_pipeline.py --from {failed[0][0]}")
        return 1

    print("\nOutputs:")
    print("  publication/forest_plots/professional_wide_fixed/   forest plots, sorted")
    print("  publication/forest_plots/professional_labeled_v2/   forest plots, labeled")
    print("  publication/tables_final/                           tables (unadjusted RR)")
    print("  publication/exposure_design_diagram*.{png,pdf}      design diagrams")
    if not a.skip_html:
        print("  present/                                            interactive bundle")
    print("\nVerify:  git status --porcelain -- publication/ present/   (clean = reproduced)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
