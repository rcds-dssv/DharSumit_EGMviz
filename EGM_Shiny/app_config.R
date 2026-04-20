# =============================================================================
# LIBRARIES
# =============================================================================

library(shiny)
library(ggplot2)
library(dplyr)
library(readr)
library(tidyr)
library(forcats)
library(plotly)
library(stringr)
library(shinyWidgets)
library(writexl)
library(jsonlite)

# =============================================================================
# LOAD THE USER CONFIGURARION
# this will pull in the settings from the user config file 
# (below the colors are writting to a separate styles_runtime.css file)
# =============================================================================
source("user_config.R")


# =============================================================================
# EVIDENCE-CATEGORY METADATA
# Each entry drives one plotly trace and one confidence-level tag in the table.
#   display_text  label shown in table header tags (NULL = no tag)
#   color         marker color, taken from the palette above
#   index         0-based plotly trace index; must match create_egm_data() order
#   offset_x/y    per-category jitter so overlapping dots stay readable
# =============================================================================

# Flags derived once at startup; used throughout the app to conditionally
# enable confidence-level and in-progress trace/toggle/table features.
has_confidence <- !is.na(egm_definition$confidence_column_name)
has_in_progress <- !is.na(egm_definition$in_progress_column_name)

# Evidence-category metadata built dynamically so trace indices stay correct
# regardless of which optional categories are enabled.
# Trace index layout: 0 = heatmap (always), 1 = all (always),
# then confidence traces (if enabled), then in_progress (if enabled).
local({
    next_idx <- 2L
    meta <- list(
        all = list(display_text = NULL, color = egm_definition$plot_colors$all_points,
                   index = 1L, offset_x = 0.00, offset_y = 0.00)
    )
    if (has_confidence) {
        meta$high   <- list(display_text = "High Confidence",
                            color = egm_definition$plot_colors$high_confidence,
                            index = next_idx,      offset_x =  0.35, offset_y =  0.35)
        meta$medium <- list(display_text = "Medium Confidence",
                            color = egm_definition$plot_colors$medium_confidence,
                            index = next_idx + 1L, offset_x =  0.00, offset_y =  0.35)
        meta$low    <- list(display_text = "Low Confidence",
                            color = egm_definition$plot_colors$low_confidence,
                            index = next_idx + 2L, offset_x = -0.35, offset_y =  0.35)
        next_idx <- next_idx + 3L
    }
    if (has_in_progress) {
        meta$in_progress <- list(display_text = "In Progress",
                                 color = egm_definition$plot_colors$in_progress,
                                 index = next_idx, offset_x = -0.17, offset_y = -0.35)
    }
    egm_metadata <<- meta
})


# =============================================================================
# DATA HELPERS
# Pure transformation functions with no side effects.
# =============================================================================

# Count papers per (x_column, y_column) cell and place "Other" /
# "None Given" categories at the end of each axis.
create_counts <- function(df) {
    x_col <- egm_definition$x_column
    y_col <- egm_definition$y_column
    df %>%
        count(.data[[x_col]], .data[[y_col]]) %>%
        mutate(
            !!x_col := fct_relevel(factor(.data[[x_col]]),
                                   intersect(c("Other", "None Given"), unique(.data[[x_col]])),
                                   after = Inf),
            !!y_col := fct_relevel(factor(.data[[y_col]]),
                                   intersect(c("None Given", "Other"), unique(.data[[y_col]])))
        )
}

# Build the named list of per-category dataframes that drives the whole app.
# The names ("all", "high", ...) must match the keys in egm_metadata above.
create_egm_data <- function(df_in) {
    result <- list(
        all = list(df = df_in, counts = create_counts(df_in))
    )
    if (has_confidence) {
        conf_col <- egm_definition$confidence_column_name
        df_high   <- df_in %>% filter(!is.na(.data[[conf_col]]), .data[[conf_col]] == 3)
        df_medium <- df_in %>% filter(!is.na(.data[[conf_col]]), .data[[conf_col]] == 2)
        df_low    <- df_in %>% filter(!is.na(.data[[conf_col]]), .data[[conf_col]] == 1)
        result$high   <- list(df = df_high,   counts = create_counts(df_high))
        result$medium <- list(df = df_medium, counts = create_counts(df_medium))
        result$low    <- list(df = df_low,    counts = create_counts(df_low))
    }
    if (has_in_progress) {
        in_progress_col <- egm_definition$in_progress_column_name
        df_in_progress <- df_in %>% filter(!is.na(.data[[in_progress_col]]), .data[[in_progress_col]] == 1)
        result$in_progress <- list(df = df_in_progress, counts = create_counts(df_in_progress))
    }
    result
}


# =============================================================================
# DATA LOADING
# =============================================================================

# Read and lightly clean the papers dataset.
# NA in the two axis columns would break the EGM grid, so replace with "Other".
df_all <- read_csv(egm_definition$datafile_path) %>%
    mutate(
        !!egm_definition$x_column := replace_na(.data[[egm_definition$x_column]], "Other"),
        !!egm_definition$y_column := replace_na(.data[[egm_definition$y_column]], "Other")
    ) %>%
    mutate(across(
        all_of(egm_definition$filter_dropdown_list),
        ~ ifelse(is.na(.), "Other", as.character(.))
    ))

# Stored in the global env so mod_plot.R can reference it for consistent axis
# sizing and marker scaling as the user applies filters.
initial_egm_data <- create_egm_data(df_all)


# =============================================================================
# SAVE STYLES FOR CSS
# write colors and other styles to a runtime css file that can be used by html/js
# =============================================================================

# Compute the fixed plot width (same formula as create_egm_figure) and write a
# max-width rule so the plot-section-header never exceeds the plot right edge.
local({
    # gather the colors from the user_config.R file
    plot_colors_css <- paste0("--color-", str_replace_all(names(egm_definition$plot_colors),'_','-'), ": ", unlist(egm_definition$plot_colors), ";", collapse = "")
    web_colors_css <- paste0("--color-", str_replace_all(names(egm_definition$web_colors),'_','-'), ": ", unlist(egm_definition$web_colors), ";", collapse = "")
    colors_css <- paste0(":root {", plot_colors_css, web_colors_css, "}")
    # calculate the plot width
    n_x   <- length(unique(initial_egm_data$all$counts[[egm_definition$x_column]]))
    max_w <- n_x * egm_definition$plot_cell_width_px + 260 + 40
    plot_width <- paste0(".plot-section-header { max-width: ", max_w, "px; }")
    # combine and write to the file
    output <- paste0(colors_css, '\n', plot_width)
    writeLines(output, "www/styles_runtime.css")
})
