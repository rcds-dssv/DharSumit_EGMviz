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

# =============================================================================
# DEFINITIONS
# This section contains (hopefully) all of the variables one would need to 
# change in order to implement basic tweaks to the dashboard
# =============================================================================

egm_definition <- list(
    # The relative path to the data file.
    datafile_path = "data/AAHHC_Scoping_2026.csv",

    # The column name to use for the x axis of the EGM figure and the display name 
    x_column = "WorkType",
    x_column_display = "Work Type",

    # The column name to use for the y axis of the EGM figure and the display name 
    y_column = "Theme",
    y_column_display = "Theme",

    # A list of column names within the data file to be used in filtering.
    # Dropdowns will be created programmatically for each of these items.
    # The first vector contains the column names.
    # The second vector contains the desired display name.
    filter_dropdown_list = c("USOrigin", "OriginalResearchType", "StudySetting", "ObservationalStudy", "ReviewType", "RT"),
    filter_dropdown_list_display = c("US Origin", "Original Research Type", "Study Setting", "Observational Study", "Review Type", "RT"),

    # The column name to use for the confidence level indicator.
    # If this column does not exist in the data, this functionality will be ignored.
    confidence_column_name = NA,

    # The column name to use for the ongoing indicator.
    # If this column does not exist in the data, this functionality will be ignored.
    ongoing_column_name = NA,

    # Color pallette
    # These values are also written to www/colors_runtime.css so the stylesheet
    # can reference them as CSS custom properties (var(--color-*)).
    colors <- list(
        all_points        = "#1f77b4",
        high_confidence   = "#46A040",
        medium_confidence = "#FDB915",
        low_confidence    = "#CC3D3D",
        in_progress       = "#FFC0CB",
        heatmap_min       = "rgba(130,130,130,0)", # fully transparent
        heatmap_max       = "rgba(130,130,130,1)"  # mid-gray
    )
)

# =============================================================================
# SAVE COLORS FOR CSS
# to ensure consistent colors, write to a css file that can be used by html/js
# =============================================================================
css <- paste0(
    ":root {",
    paste0("--color-", names(egm_definition$colors), ": ", unlist(egm_definition$colors), ";", collapse = ""),
    "}"
)
writeLines(css, "www/colors_runtime.css")


# =============================================================================
# EVIDENCE-CATEGORY METADATA
# Each entry drives one plotly trace and one confidence-level tag in the table.
#   display_text  label shown in table header tags (NULL = no tag)
#   color         marker colour, taken from the palette above
#   index         0-based plotly trace index; must match create_egm_data() order
#   offset_x/y    per-category jitter so overlapping dots stay readable
# =============================================================================

egm_metadata <- list(
    all     = list(display_text = NULL,                color = colors$all_points,        index = 1, offset_x =  0.00, offset_y =  0.00),
    high    = list(display_text = "High Confidence",   color = colors$high_confidence,   index = 2, offset_x =  0.35, offset_y =  0.35),
    medium  = list(display_text = "Medium Confidence", color = colors$medium_confidence, index = 3, offset_x =  0.00, offset_y =  0.35),
    low     = list(display_text = "Low Confidence",    color = colors$low_confidence,    index = 4, offset_x = -0.35, offset_y =  0.35),
    ongoing = list(display_text = "In Progress",       color = colors$in_progress,       index = 5, offset_x = -0.17, offset_y = -0.35)
)


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
            !!x_col := fct_relevel(factor(.data[[x_col]]), "Other", "None Given", after = Inf),
            !!y_col := fct_relevel(factor(.data[[y_col]]), "None Given", "Other")
        )
}

# Build the named list of per-category dataframes that drives the whole app.
# The names ("all", "high", ...) must match the keys in egm_metadata above.
create_egm_data <- function(df_in) {
    df_high    <- df_in %>% filter(review_confidence == 3)
    df_medium  <- df_in %>% filter(review_confidence == 2)
    df_low     <- df_in %>% filter(review_confidence == 1)
    df_ongoing <- df_in %>% filter(in_progress == 1)

    list(
        all     = list(df = df_in,      counts = create_counts(df_in)),
        high    = list(df = df_high,    counts = create_counts(df_high)),
        medium  = list(df = df_medium,  counts = create_counts(df_medium)),
        low     = list(df = df_low,     counts = create_counts(df_low)),
        ongoing = list(df = df_ongoing, counts = create_counts(df_ongoing))
    )
}


# =============================================================================
# DATA LOADING
# =============================================================================

# Read and lightly clean the papers dataset.
# NA in the two axis columns would break the EGM grid, so replace with "None Given".
df_all <- read_csv(egm_definition$datafile_path) %>%
    mutate(
        !!egm_definition$x_column := replace_na(.data[[egm_definition$x_column]], "None Given"),
        !!egm_definition$y_column := replace_na(.data[[egm_definition$y_column]], "None Given")
    )

# Stored in the global env so mod_plot.R can reference it for consistent axis
# sizing and marker scaling as the user applies filters.
initial_egm_data <- create_egm_data(df_all)