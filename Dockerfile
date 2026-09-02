FROM rocker/tidyverse:4.3.3

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagick++-dev \
    cmake \
    python3-pil \
    && rm -rf /var/lib/apt/lists/*

# R packages batch 1 (install2.r --error fails build if any package fails)
RUN install2.r --error --skipinstalled --ncpus -1 \
    arrow conflicted crayon data.table doParallel \
    fable feasts fixest fpp3 future furrr glarma \
    gridExtra gt htmlwidgets lmtest magick \
    && rm -rf /tmp/downloaded_packages

# R packages batch 2
RUN install2.r --error --skipinstalled --ncpus -1 \
    patchwork plotly posterior pryr R.utils reticulate \
    renv rprojroot sandwich shiny skimr tscount png \
    && rm -rf /tmp/downloaded_packages

# cmdstanr from r-universe
RUN install2.r --error --skipinstalled --ncpus -1 \
    --repos https://stan-dev.r-universe.dev --repos getOption \
    cmdstanr \
    && rm -rf /tmp/downloaded_packages

# Install CmdStan to a world-readable location (NOT /root/ — inaccessible under Singularity)
# Pin CmdStan. renv.lock pins the cmdstanr R package (0.9.0) but not CmdStan
# itself, and install_cmdstan() with no version= takes whatever is newest at
# build time -- so an unpinned image silently drifts off the version the
# published results were produced under. 2.38.0 is what .Rprofile expects.
RUN Rscript -e 'cmdstanr::install_cmdstan(version = "2.38.0", dir = "/usr/local/share", cores = parallel::detectCores())'

# Find the actual versioned cmdstan path and write to Renviron so R can find it
RUN CMDSTAN_PATH=$(ls -d /usr/local/share/cmdstan-*) && \
    echo "CMDSTAN=${CMDSTAN_PATH}" >> /usr/local/lib/R/etc/Renviron && \
    echo "LD_LIBRARY_PATH=${CMDSTAN_PATH}/stan/lib/stan_math/lib/tbb" >> /usr/local/lib/R/etc/Renviron

# Ensure CmdStan is world-readable for Singularity (runs as host user, not root)
RUN chmod -R a+rX /usr/local/share/cmdstan*

# Create empty renv/activate.R so .Rprofile doesn't error
RUN mkdir -p /app/renv && touch /app/renv/activate.R

# Copy project
COPY . /app
WORKDIR /app

# Pre-compile Stan models to /opt/stan_models (won't be overlaid by bind mounts)
RUN mkdir -p /opt/stan_models && \
    cp /app/models/*.stan /opt/stan_models/ && \
    Rscript -e 'cmdstanr::cmdstan_model("/opt/stan_models/model_multilevel_transfer_truncated.stan")' && \
    Rscript -e 'cmdstanr::cmdstan_model("/opt/stan_models/model_multilevel_transfer_customer_gaussian_iid.stan")' && \
    chmod -R a+rX /opt/stan_models

# Verify critical packages
RUN Rscript -e 'for (p in c("patchwork","skimr","pryr","arrow","cmdstanr","posterior","shiny","plotly")) { if (!requireNamespace(p, quietly=TRUE)) stop(paste(p, "MISSING")) }'

CMD ["bash"]
