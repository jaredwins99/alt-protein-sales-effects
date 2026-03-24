FROM rocker/tidyverse:4.3.3

# System dependencies for R packages and CmdStan
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagick++-dev \
    cmake \
    python3-pil \
    && rm -rf /var/lib/apt/lists/*

# R packages not included in rocker/tidyverse
RUN R -e 'install.packages(c( \
    "arrow", "conflicted", "crayon", "data.table", "doParallel", \
    "fable", "feasts", "fixest", "fpp3", "future", "furrr", "glarma", \
    "gridExtra", "gt", "htmlwidgets", "lmtest", "magick", "patchwork", \
    "plotly", "posterior", "pryr", "R.utils", "reticulate", "renv", \
    "rprojroot", "sandwich", "shiny", "skimr", "tscount", "png" \
  ), repos = "https://cloud.r-project.org")'

# cmdstanr (from r-universe)
RUN R -e 'install.packages("cmdstanr", repos = c("https://stan-dev.r-universe.dev", "https://cloud.r-project.org"))'

# CmdStan
RUN R -e 'cmdstanr::install_cmdstan()'

# Set CmdStan library path
ENV LD_LIBRARY_PATH="/root/.cmdstan/cmdstan-2.38.0/stan/lib/stan_math/lib/tbb:${LD_LIBRARY_PATH}"

# Create empty renv/activate.R so .Rprofile doesn't error
RUN mkdir -p /app/renv && touch /app/renv/activate.R

# Copy project
COPY . /app
WORKDIR /app

CMD ["bash"]
