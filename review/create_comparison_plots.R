# Create Comparison Plots (Original vs Clipped)
# Concatenates original and clipped plots horizontally
#
# Usage: Rscript review/create_comparison_plots.R
#
# Output: review/overlap_plots_combined/

library(magick)

# ─────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────

original_base <- "review/overlap_plots"
clipped_base <- "review/overlap_plots_clipped"
output_base <- "review/overlap_plots_combined"

# ─────────────────────────────────────────────────────────────
# Helper function to combine two images horizontally
# ─────────────────────────────────────────────────────────────

combine_plots <- function(original_path, clipped_path, output_path) {
  tryCatch({
    if (!file.exists(original_path)) {
      cat(paste0("  Original not found: ", original_path, "\n"))
      return(FALSE)
    }
    if (!file.exists(clipped_path)) {
      cat(paste0("  Clipped not found: ", clipped_path, "\n"))
      return(FALSE)
    }

    # Read images
    img_original <- image_read(original_path)
    img_clipped <- image_read(clipped_path)

    # Add labels
    img_original <- image_annotate(img_original, "ORIGINAL", size = 30,
                                    gravity = "northwest", color = "red",
                                    location = "+10+10")
    img_clipped <- image_annotate(img_clipped, "CLIPPED", size = 30,
                                   gravity = "northwest", color = "green",
                                   location = "+10+10")

    # Combine horizontally
    combined <- image_append(c(img_original, img_clipped), stack = FALSE)

    # Ensure output directory exists
    output_dir <- dirname(output_path)
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }

    # Save
    image_write(combined, output_path)
    return(TRUE)
  }, error = function(e) {
    cat(paste0("  Error: ", e$message, "\n"))
    return(FALSE)
  })
}

# ─────────────────────────────────────────────────────────────
# Process ITS (A3)
# ─────────────────────────────────────────────────────────────

cat("=== Processing ITS (A3) ===\n")

its_outcomes <- c("meat", "vegan", "vegetarian", "nonvegan", "total", "chicken_fish")

for (outcome in its_outcomes) {
  cat(paste0("Processing ITS: ", outcome, "\n"))

  for (tier in c("tier1", "tier2")) {
    original_dir <- file.path(original_base, "its", outcome, tier)
    clipped_dir <- file.path(clipped_base, "its", outcome, tier)
    output_dir <- file.path(output_base, "its", outcome, tier)

    if (!dir.exists(original_dir)) next

    files <- list.files(original_dir, pattern = "\\.png$", full.names = FALSE)

    for (f in files) {
      original_path <- file.path(original_dir, f)
      clipped_path <- file.path(clipped_dir, f)
      output_path <- file.path(output_dir, f)

      result <- combine_plots(original_path, clipped_path, output_path)
      if (result) cat(paste0("  Created: ", output_path, "\n"))
    }
  }
}

# ─────────────────────────────────────────────────────────────
# Process ITS Targeted (A4)
# ─────────────────────────────────────────────────────────────

cat("\n=== Processing ITS Targeted (A4) ===\n")

its_targeted_outcomes <- c("breakfast", "dairy", "chicken", "egg", "textured", "untextured")

for (outcome in its_targeted_outcomes) {
  cat(paste0("Processing ITS Targeted: ", outcome, "\n"))

  for (tier in c("tier1", "tier2")) {
    original_dir <- file.path(original_base, "its_targeted", outcome, tier)
    clipped_dir <- file.path(clipped_base, "its_targeted", outcome, tier)
    output_dir <- file.path(output_base, "its_targeted", outcome, tier)

    if (!dir.exists(original_dir)) next

    files <- list.files(original_dir, pattern = "\\.png$", full.names = FALSE)

    for (f in files) {
      original_path <- file.path(original_dir, f)
      clipped_path <- file.path(clipped_dir, f)
      output_path <- file.path(output_dir, f)

      result <- combine_plots(original_path, clipped_path, output_path)
      if (result) cat(paste0("  Created: ", output_path, "\n"))
    }
  }
}

# ─────────────────────────────────────────────────────────────
# Process Proportion (A1)
# ─────────────────────────────────────────────────────────────

cat("\n=== Processing Proportion (A1) ===\n")

proportion_outcomes <- c("meat", "vegan", "vegetarian", "nonvegan", "total", "chicken_fish")
proportion_exposures <- c("mpbamod_dishes_count", "mpbamod_dishes_prop",
                          "vegan_dishes_count", "vegan_dishes_prop",
                          "vegetarian_dishes_count", "vegetarian_dishes_prop")

for (outcome in proportion_outcomes) {
  for (exp_type in proportion_exposures) {
    cat(paste0("Processing Proportion: ", outcome, "/", exp_type, "\n"))

    for (tier in c("tier1", "tier2")) {
      original_dir <- file.path(original_base, "proportion", outcome, exp_type, tier)
      clipped_dir <- file.path(clipped_base, "proportion", outcome, exp_type, tier)
      output_dir <- file.path(output_base, "proportion", outcome, exp_type, tier)

      if (!dir.exists(original_dir)) next

      files <- list.files(original_dir, pattern = "\\.png$", full.names = FALSE)

      for (f in files) {
        original_path <- file.path(original_dir, f)
        clipped_path <- file.path(clipped_dir, f)
        output_path <- file.path(output_dir, f)

        result <- combine_plots(original_path, clipped_path, output_path)
        if (result) cat(paste0("  Created: ", output_path, "\n"))
      }
    }
  }
}

# ─────────────────────────────────────────────────────────────
# Process Proportion Targeted (A2)
# ─────────────────────────────────────────────────────────────

cat("\n=== Processing Proportion Targeted (A2) ===\n")

proportion_targeted_config <- list(
  breakfast_p = c("breakfast_dishes_count", "breakfast_dishes_presence"),
  chicken_p = c("chicken_dishes_count", "chicken_dishes_presence"),
  dairy_p = c("dairy_dishes_count", "dairy_dishes_presence"),
  egg_p = c("egg_dishes_count", "egg_dishes_presence"),
  textured_p = c("textured_dishes_count", "textured_dishes_presence"),
  untextured_p = c("untextured_dishes_count", "untextured_dishes_presence")
)

for (category in names(proportion_targeted_config)) {
  exposures <- proportion_targeted_config[[category]]

  for (exp_type in exposures) {
    cat(paste0("Processing Proportion Targeted: ", category, "/", exp_type, "\n"))

    for (tier in c("tier1", "tier2")) {
      original_dir <- file.path(original_base, "proportion_targeted", category, exp_type, tier)
      clipped_dir <- file.path(clipped_base, "proportion_targeted", category, exp_type, tier)
      output_dir <- file.path(output_base, "proportion_targeted", category, exp_type, tier)

      if (!dir.exists(original_dir)) next

      files <- list.files(original_dir, pattern = "\\.png$", full.names = FALSE)

      for (f in files) {
        original_path <- file.path(original_dir, f)
        clipped_path <- file.path(clipped_dir, f)
        output_path <- file.path(output_dir, f)

        result <- combine_plots(original_path, clipped_path, output_path)
        if (result) cat(paste0("  Created: ", output_path, "\n"))
      }
    }
  }
}

cat("\n=== Done! ===\n")
cat(paste0("Combined plots saved to: ", output_base, "/\n"))
