# Docker + CmdStanR + Singularity/HPC Guide

## Overview

This project uses a Docker image to package R, CmdStan, and all dependencies into a portable container that runs on HPC clusters via Singularity/Apptainer. The image is built locally in WSL, pushed to Docker Hub, pulled as a .sif file on Sherlock (Stanford HPC), and run via Slurm batch scripts.

## End-to-End Process

### Step 1: Build the Docker image (local WSL machine)

```bash
# Fix WSL Docker credential issue (one-time)
mkdir -p ~/.docker && echo '{"credsStore":""}' > ~/.docker/config.json

# Log into Docker Hub
docker login -u jaredwins99  # use access token as password (Docker Hub > Security > New Access Token, read+write)

# Build
docker build -t ingarch .

# Tag and push
docker tag ingarch jaredwins99/ingarch:latest
docker push jaredwins99/ingarch:latest
```

### Step 2: Pull image on Sherlock

Login nodes have limited memory. Pull images on a compute node.

```bash
ssh SUNETID@login.sherlock.stanford.edu
sh_dev -m 8G
export SINGULARITY_CACHEDIR=$SCRATCH/.singularity_cache
singularity pull --docker-login $GROUP_HOME/testing-models.sif docker://jaredwins99/ingarch:latest
exit
```

To overwrite an existing .sif, add `--force`.

### Step 3: Clone repo and set up directories

```bash
cd ~
git clone https://github.com/jaredwins99/testing.git
cd testing
git checkout reviewer
mkdir -p logs renv && touch renv/activate.R
mkdir -p $SCRATCH/model_fits
```

The `renv/activate.R` is needed because `.Rprofile` tries to source it.

### Step 4: Test interactively

```bash
sh_dev -m 8G

# Quick sanity check
singularity exec \
    --bind $HOME/testing:/app \
    --bind $SCRATCH/model_fits:/app/model_fits \
    --pwd /app \
    --env R_LIBS_USER=/dev/null \
    --env R_LIBS="" \
    $GROUP_HOME/testing-models.sif \
    Rscript -e 'library(cmdstanr); cat("CmdStan:", cmdstan_path(), "\n"); library(patchwork); cat("All good\n")'

# Full model test (Ctrl+C once you see iterations)
singularity exec \
    --bind $HOME/testing:/app \
    --bind $SCRATCH/model_fits:/app/model_fits \
    --pwd /app \
    --env R_LIBS_USER=/dev/null \
    --env R_LIBS="" \
    $GROUP_HOME/testing-models.sif \
    Rscript model_starters/t2_a1_proportion/A1_T2_chicken_fish_on_mpbamod_count.R

exit
```

### Step 5: Submit batch jobs

```bash
cd ~/testing
sbatch slurm_proportion.sh
sbatch slurm_its_and_customer.sh
```

### Step 6: Monitor

```bash
squeue -u $USER                              # job status (PD=pending, R=running)
sacct -u $USER --format=JobID,JobName,State,Elapsed,Start,End --starttime=2026-03-25  # detailed history
grep "Iteration" logs/slurm_prop_*_1.out | tail -5    # check iteration progress
for f in logs/slurm_prop_*.out; do echo "=== $f ==="; grep "Iteration" "$f" | tail -2; done  # all at once
scancel JOBID                                # kill a job
scancel JOBID_ARRAYINDEX                     # kill one array task
```

### Step 7: Pull results back (from local WSL machine)

```bash
rsync -avz sherlock:$SCRATCH/model_fits/ ./model_fits/
```

## Dockerfile Design Decisions

### 1. install2.r --error (not install.packages)

`install.packages()` silently continues when a package fails. We lost patchwork, skimr, and pryr this way on the first build. The rocker images ship `install2.r` which supports `--error` to fail the build immediately.

```dockerfile
RUN install2.r --error --skipinstalled --ncpus -1 arrow dplyr ...
```

Source: https://rocker-project.org/use/extending.html

### 2. CmdStan at /usr/local/share/ (not /root/)

Singularity runs as the host user, not root. `/root/` is inaccessible. We hit this as "System command 'make' failed" at runtime. CmdStan must be installed to a world-readable location.

```dockerfile
RUN Rscript -e 'cmdstanr::install_cmdstan(dir = "/usr/local/share", cores = parallel::detectCores())'
RUN chmod -R a+rX /usr/local/share/cmdstan*
```

Source: https://github.com/stan-dev/cmdstanr/issues/995

### 3. ENV vars written to Renviron (not just Docker ENV)

Docker `ENV` variables are not visible to R sessions under Singularity. We hit this as "Path not set. Can't find directory: ~/.cmdstan/cmdstan-2.38.0". They must be written to `/usr/local/lib/R/etc/Renviron`.

```dockerfile
RUN CMDSTAN_PATH=$(ls -d /usr/local/share/cmdstan-*) && \
    echo "CMDSTAN=${CMDSTAN_PATH}" >> /usr/local/lib/R/etc/Renviron && \
    echo "LD_LIBRARY_PATH=${CMDSTAN_PATH}/stan/lib/stan_math/lib/tbb" >> /usr/local/lib/R/etc/Renviron
```

Source: https://github.com/rocker-org/rocker-versioned/issues/112

### 4. Pre-compiled Stan models at /opt/stan_models/

SIF containers are read-only. CmdStan writes intermediate files into its own directory during compilation, which fails at runtime. We hit this as "System command 'make' failed". Pre-compiling during Docker build and storing at `/opt/stan_models/` (which is NOT overlaid by bind mounts) fixes this.

```dockerfile
RUN mkdir -p /opt/stan_models && \
    cp /app/models/*.stan /opt/stan_models/ && \
    Rscript -e 'cmdstanr::cmdstan_model("/opt/stan_models/model_multilevel_transfer_truncated.stan")' && \
    chmod -R a+rX /opt/stan_models
```

At runtime, R checks for the pre-compiled binary first:
```r
precompiled <- file.path("/opt/stan_models", tools::file_path_sans_ext(stan_file))
if (file.exists(precompiled)) {
  mod <- cmdstan_model(exe_file = precompiled)
} else {
  mod <- cmdstan_model(file.path("models", stan_file))
}
```

Source: https://github.com/stan-dev/cmdstan/issues/1175

### 5. chmod -R a+rX for Singularity

Singularity maps the host user into the container. Files owned by root must be world-readable or you get permission denied silently.

### 6. R_LIBS_USER=/dev/null at runtime

Singularity auto-mounts `$HOME`, so R finds the host's personal library (`~/R/...`) and uses those packages instead of the container's. We hit this as "there is no package called 'skimr'" even though skimr was in the container. The fix:

```bash
singularity exec --env R_LIBS_USER=/dev/null --env R_LIBS="" ...
```

### 7. Don't use --no-home

We tried `--no-home` to isolate from host R libraries, but it also blocked access to the pre-compiled CmdStan at `/root/`. Using `--env R_LIBS_USER=/dev/null` is the correct approach — it prevents host R library leakage without blocking container paths.

### 8. Code goes via bind mount, not baked into image

The `COPY . /app` in the Dockerfile copies code into the image, but at runtime `--bind $HOME/testing:/app` overlays it. The image's code is never used — only the environment (packages, CmdStan, pre-compiled models). This means code changes only require `git pull` on Sherlock, not a Docker rebuild.

## Sherlock-Specific Notes

### Partitions and QOS

| Partition | Public | Max Time | Notes |
|---|---|---|---|
| normal | yes | 2d (7d with --qos=long) | Main partition, 248 nodes |
| qsu | no (group) | 2d (7d with --qos=long) | Private, 6 nodes, less competition |
| dev | yes | 2h | Interactive testing via sh_dev |
| bigmem | yes | 1d | Up to 4TB RAM |
| gpu | yes | 2d | GPU nodes |

- `--qos=long` may not be available by default. Check with `sacctmgr show assoc where user=$USER format=user,account,partition,qos%50`
- On qsu, max time with long is `6-23:59:00` (not a clean 7 days)
- `--qos=long` requires time > 2 days. If you set --time=2-00:00:00 with --qos=long, it errors "too short for long"

### Storage

| Location | Size | Persistence | Use for |
|---|---|---|---|
| $HOME | ~15GB | Permanent | Code repo |
| $GROUP_HOME | Shared | Permanent | .sif image |
| $SCRATCH | Terabytes | Purged after 90 days idle | Model output |
| $OAK | Paid | Permanent | Long-term storage |

### Array jobs and throttling

```bash
#SBATCH --array=1-23%8   # 23 tasks, max 8 running at once
```

The `%8` means max 8 concurrent. As one finishes, the next starts automatically. Each task uses 3 cores, so %8 = 24 cores max. Submit everything at once — Slurm handles the queuing.

On qsu (private partition), there's minimal queue competition from outsiders, but fairshare is global — heavy usage on qsu lowers your priority on normal partition later.

### Login nodes vs compute nodes

- **Login nodes**: git, sbatch, squeue, editing files. NO heavy computation.
- **Compute nodes**: Model fitting, image pulling, anything resource-intensive.
- Use `sh_dev -m 8G` for interactive compute access (no queue wait).
- `sbatch` sends work to compute nodes. You never SSH to them directly.

### Log files

- Slurm writes stdout to the file specified by `--output`
- `%A` = job ID, `%a` = array task index
- Submitting the same script twice appends to logs if job IDs match the same `_a` suffix — this can cause confusing interleaved output
- Use different script names for different submissions to avoid this

### WSL Docker credential fix

Docker Desktop's WSL credential helper fails with `UtilAcceptVsock:271: accept4 failed`. Fix:

```bash
mkdir -p ~/.docker && echo '{"credsStore":""}' > ~/.docker/config.json
docker login -u USERNAME  # then enter access token
```

This stores credentials in plaintext (~/.docker/config.json) instead of going through Docker Desktop's broken credential manager.

## Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `cannot open file 'renv/activate.R'` | .Rprofile sources it, doesn't exist | `mkdir -p renv && touch renv/activate.R` |
| `there is no package called 'X'` | Host R library leaking in, or package missing from image | Add `--env R_LIBS_USER=/dev/null --env R_LIBS=""` to singularity exec |
| `System command 'make' failed` | SIF is read-only, CmdStan can't compile | Pre-compile models in Dockerfile at /opt/stan_models/ |
| `Path not set. Can't find directory: ~/.cmdstan/` | CMDSTAN env var not visible to R | Write to /usr/local/lib/R/etc/Renviron in Dockerfile |
| `error getting credentials` | Docker Desktop WSL credential helper broken | `echo '{"credsStore":""}' > ~/.docker/config.json` |
| `mksquashfs command failed: signal: killed` | Login node ran out of memory during pull | Use `sh_dev -m 8G` then pull |
| `Invalid qos specification` | Don't have access to that QOS | Check `sacctmgr show assoc where user=$USER` |
| `timelimit request too long` | Partition max exceeded | Use --qos=long (if available) or reduce --time |
| `MASS::select masks dplyr::select` | .Rprofile not loaded (conflict_prefer skipped) | Ensure renv/activate.R exists so .Rprofile loads fully |
| `libtbb.so.2: cannot open shared object` | LD_LIBRARY_PATH not set for CmdStan's TBB | Set in Renviron or export before running |

## Model Output Safety

All `saveRDS` calls in `run_ingarch.R` and `run_gaussian_iid.R` happen BEFORE the `plot_ingarch`/`plot_gaussian_iid` call. If plotting fails (e.g., missing patchwork), results are already saved. The plotting call is inside `tryCatch`, so errors are caught gracefully. "Done." prints regardless.

## Rebuilding the Image

Only rebuild when:
- R packages change
- Stan models change (need recompilation)
- System dependencies change

Code-only changes just need `git push` + `git pull` on Sherlock.

```bash
docker build -t ingarch .
docker tag ingarch jaredwins99/ingarch:latest
docker push jaredwins99/ingarch:latest
# Then on Sherlock:
sh_dev -m 8G
singularity pull --force --docker-login $GROUP_HOME/testing-models.sif docker://jaredwins99/ingarch:latest
```
