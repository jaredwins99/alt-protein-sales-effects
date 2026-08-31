#!/usr/bin/env python
"""Rebuild the published figures and tables from committed draws.

    python run_pipeline.py              # everything
    python run_pipeline.py --list       # show the steps
    python run_pipeline.py --from 3     # resume partway
    python run_pipeline.py --skip-html  # skip the interactive bundle (needs node)

The model fits are 184 GB and are not distributed. publication/published_draws/
holds the parameters every published estimate needs, so the plot table is
regenerated from those rather than refitted. Run from the repo root.
"""
import argparse, os, subprocess, sys, time

ROOT = os.path.dirname(os.path.abspath(__file__))

STEPS = [
    ("1  plot table from committed draws",
     ["Rscript", "publication/scripts/adj_join_pass2.R",
      "publication/published_draws", "publication/scripts/adj_fixed_pairs.csv",
      "publication/forest_data_adj_95ci_fixed.csv"]),
    ("2  forest plots — sorted",
     ["Rscript", "publication/render/render_professional_wide_fixed.R"]),
    ("3  forest plots — labeled",
     ["Rscript", "publication/render/render_professional_labeled_v2.R"]),
    ("4  table inputs",
     ["Rscript", "publication/scripts/build_final_models.R"]),
    ("5  tables (unadjusted RR)",
     ["Rscript", "publication/scripts/final_tables.R"]),
    ("6  collect tables into markdown",
     [sys.executable, "publication/scripts/build_final_tables_md.py"]),
    ("7  interactive bundle (needs node)",
     ["bash", "publication/render/render_present.sh"]),
]


def preflight(skip_html):
    problems = []
    if not os.path.isdir(os.path.join(ROOT, "publication", "published_draws")):
        problems.append("publication/published_draws/ not found — is this the repo root?")

    r = subprocess.run(["Rscript", "--vanilla", "-e", "cat(as.character(getRversion()))"],
                       capture_output=True, text=True)
    ver = r.stdout.strip().splitlines()[-1].strip() if r.stdout.strip() else ""
    if r.returncode:
        problems.append("Rscript not found on PATH — install R 4.4.2")
    elif ver != "4.4.2":
        problems.append(f"Rscript is R {ver}, expected 4.4.2 — the renv library "
                        "is built for 4.4.2 and will not load")
    else:
        r = subprocess.run(["Rscript", "-e",
                            'cat(all(sapply(c("ggplot2","patchwork","dplyr"), requireNamespace, quietly=TRUE)))'],
                           cwd=ROOT, capture_output=True, text=True)
        if "TRUE" not in r.stdout:
            problems.append("R packages not installed — run `renv::activate()` then "
                            "`renv::restore()` from the repo root (not with --vanilla). "
                            "This repo has its own lockfile, separate from restaurant-sales.")

    if not skip_html and subprocess.run(["which", "node"], capture_output=True).returncode:
        problems.append("node not found — install it, or pass --skip-html")

    if problems:
        print("Cannot start:\n")
        for p in problems:
            print(f"  - {p}")
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="start", type=int, default=1)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--skip-html", action="store_true")
    a = ap.parse_args()

    steps = STEPS[:-1] if a.skip_html else STEPS
    if a.list:
        for i, (name, cmd) in enumerate(steps, 1):
            print(f"  {i:>2}. {name:38s} {os.path.basename(cmd[1] if len(cmd) > 1 else cmd[0])}")
        return 0

    preflight(a.skip_html)

    t0 = time.time()
    failed = []
    for i, (name, cmd) in enumerate(steps, 1):
        if i < a.start:
            continue
        print(f"\n=== step {name}", flush=True)
        t = time.time()
        p = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if p.returncode:
            failed.append((name, p.stderr.decode()[-400:].strip()))
            print(f"    FAILED exit {p.returncode}   {time.time()-t:5.0f}s", flush=True)
        else:
            print(f"    ok                {time.time()-t:5.0f}s", flush=True)

    print(f"\n{'='*66}\ndone in {(time.time()-t0)/60:.1f} min")
    if failed:
        print(f"\nFAILED — {len(failed)} step(s):")
        for name, err in failed:
            print(f"  {name}\n      {err.splitlines()[-1] if err else '(no stderr)'}")
        print("\nResume with:  python run_pipeline.py --from N")
        return 1

    print("\nOutputs:")
    print("  publication/forest_plots/professional_wide_fixed/    sorted forest plots")
    print("  publication/forest_plots/professional_labeled_v2/    labeled forest plots")
    print("  publication/tables_final/                            tables (unadjusted RR)")
    if not a.skip_html:
        print("  present/                                             interactive bundle")
    print("\nVerify:  git status --porcelain -- publication/ present/   (clean = reproduced)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
