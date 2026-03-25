# Docker + CmdStanR + Singularity/HPC Guide

## Overview

This project uses a Docker image to package R, CmdStan, and all dependencies into a portable container that runs on HPC clusters via Singularity/Apptainer.

## Key Design Decisions

### 1. install2.r --error (not install.packages)

`install.packages()` silently continues when a package fails to install. In Docker builds this means missing packages go undetected. The rocker images ship `install2.r` (from `littler`) which supports `--error` to fail the build immediately.

```dockerfile
RUN install2.r --error --skipinstalled --ncpus -1 arrow dplyr ...
```

Source: https://rocker-project.org/use/extending.html

### 2. CmdStan at /usr/local/share/ (not /root/)

Singularity runs as the host user, not root. The `/root/` directory is inaccessible. CmdStan must be installed to a world-readable location.

```dockerfile
RUN Rscript -e 'cmdstanr::install_cmdstan(dir = "/usr/local/share", cores = parallel::detectCores())'
RUN chmod -R a+rX /usr/local/share/cmdstan*
```

Source: https://github.com/stan-dev/cmdstanr/issues/995

### 3. ENV vars written to Renviron (not just Docker ENV)

Docker `ENV` variables are not visible to R sessions under Singularity. They must be written to `/usr/local/lib/R/etc/Renviron` so R picks them up regardless of how the container is launched.

```dockerfile
RUN echo "CMDSTAN=/usr/local/share/cmdstan-2.38.0" >> /usr/local/lib/R/etc/Renviron
RUN echo "LD_LIBRARY_PATH=..." >> /usr/local/lib/R/etc/Renviron
```

Source: https://github.com/rocker-org/rocker-versioned/issues/112

### 4. Pre-compiled Stan models at /opt/stan_models/

SIF containers are read-only. CmdStan's `make` command writes intermediate files back into its own installation directory, which fails at runtime. Pre-compiling during Docker build eliminates this.

```dockerfile
RUN mkdir -p /opt/stan_models && \
    cp /app/models/*.stan /opt/stan_models/ && \
    Rscript -e 'cmdstanr::cmdstan_model("/opt/stan_models/model_multilevel_transfer_truncated.stan")'
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

Singularity maps the host user into the container. Files owned by root inside the container must be world-readable.

Source: Singularity/Apptainer best practices

### 6. R_LIBS_USER=/dev/null at runtime

Singularity auto-mounts `$HOME`, which means R finds the host's personal library (`~/R/...`) and uses those packages instead of the container's. Setting `R_LIBS_USER=/dev/null` via `--env` forces R to ignore the host library.

```bash
singularity exec --env R_LIBS_USER=/dev/null --env R_LIBS="" ...
```

## Build and Push

```bash
# Build
docker build -t ingarch .

# Tag and push to Docker Hub
docker tag ingarch jaredwins99/ingarch:latest
docker push jaredwins99/ingarch:latest
```

## Sherlock (Stanford HPC) Setup

### Pull image
```bash
export SINGULARITY_CACHEDIR=$SCRATCH/.singularity_cache
sh_dev -m 8G  # pull from a compute node, not login node
singularity pull --docker-login $GROUP_HOME/testing-models.sif docker://jaredwins99/ingarch:latest
exit
```

### Clone repo
```bash
cd ~
git clone https://github.com/jaredwins99/testing.git
cd testing
mkdir -p logs renv && touch renv/activate.R
```

### Test interactively
```bash
sh_dev -m 8G
mkdir -p $SCRATCH/model_fits
singularity exec \
    --bind $HOME/testing:/app \
    --bind $SCRATCH/model_fits:/app/model_fits \
    --pwd /app \
    --env R_LIBS_USER=/dev/null \
    --env R_LIBS="" \
    $GROUP_HOME/testing-models.sif \
    Rscript -e 'library(cmdstanr); cat("CmdStan:", cmdstan_path(), "\n"); library(patchwork); cat("All good\n")'
```

### Submit benchmark
```bash
sbatch slurm_benchmark.sh
squeue -u $USER          # check status
tail -f logs/slurm_bench_*.out  # watch progress
```

### Pull results back (from local machine)
```bash
rsync -avz sherlock:$SCRATCH/model_fits/ ./model_fits/
```

## Gotchas

- **Login nodes**: Don't pull images or compile on login nodes. Use `sh_dev` for setup tasks.
- **QOS**: Normal partition max is 2 days without `--qos=long`. Email srcc-support@stanford.edu for long QOS access if models need >48h.
- **$SCRATCH purge**: Files on $SCRATCH are deleted after 90 days of no access. Pull results back promptly.
- **Model output**: Bind `$SCRATCH/model_fits` to `/app/model_fits` so outputs land on scratch, not inside the container.
- **.Rprofile**: The repo's `.Rprofile` calls `source("renv/activate.R")`. An empty `renv/activate.R` must exist or R errors on startup.
