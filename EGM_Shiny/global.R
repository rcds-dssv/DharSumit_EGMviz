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
library(httr)


# =============================================================================
# DEFINITIONS
# This section contains (hopefully) all of the variables one would need to 
# change in order to implement basic tweaks to the dashboard
# =============================================================================

egm_definition <- list(
    # The relative path to the data file.
    datafile_path = "data/AAHHC_Scoping_2026_AMGclean.csv",

    # The column name to use for the x axis of the EGM figure and the display name 
    x_column = "WorkType",
    x_column_display = "Work Type",

    # The column name to use for the y axis of the EGM figure and the display name 
    y_column = "Theme",
    y_column_display = "Theme",

    # Desired max and min pixel size for the points in the figure
    plot_points_desired_max_px = 50,
    plot_points_desired_min_px = 1,

    # Minimum pixel size of each grid cell (row height and column width) in the plot.  
    plot_cell_width_px = 80,
    plot_cell_height_px = 60,

    # A list of column names within the data file to be used in filtering.
    # Dropdowns will be created programmatically for each of these items.
    # The first vector contains the column names.
    # The second vector contains the desired display name.
    filter_dropdown_list = c("USOrigin", "OriginalResearchType", "StudySetting", "ObservationalStudy", "ReviewType"),
    filter_dropdown_list_display = c("US Origin", "Research Type", "Study Setting", "Observational Study", "Review Type"),

    # The column name to use for the confidence level indicator.
    # If this column does not exist in the data, this functionality will be ignored.
    confidence_column_name = NA,

    # The column name to use for the in-progress indicator.
    # If this column does not exist in the data, this functionality will be ignored.
    in_progress_column_name = NA,

    # Column containing the paper title, used as the card heading.
    paper_title_column = "title",

    # Column containing the DOI; used to build the doi.org link on each card.
    # Set to NA to disable card linking.
    paper_doi_column = "doi",

    # Remaining citation fields shown as a compact inline block below the title.
    # Display names are short labels shown before the value ("Vol.", "No.", "pp.").
    # An empty string ("") means the value is shown without a label.
    paper_citation_columns         = c("year", "authors", "journal", "volume", "issue", "pages", "doi"),
    paper_citation_columns_display = c("",     "",        "Journal", "Vol.",   "No.",   "pp.",   "DOI"),
    paper_citation_columns_bold    = c(TRUE,   FALSE,     FALSE,     FALSE,    FALSE,   FALSE,   FALSE),

    # Additional metadata shown as labeled badge pills below the citation.
    # Display names are the badge labels ("Setting: Hospital").
    paper_meta_columns         = c("USOrigin", "OriginalResearchType", "StudySetting", "ObservationalStudy", "ReviewType"),
    paper_meta_columns_display = c("US Origin", "Research Type", "Study Setting", "Observational Study", "Review Type"),

    # Mapping from data column names to standard BibTeX field names.
    # Columns the user can sort the paper list by.  Must be valid column names.
    paper_sort_columns         = c("year", "authors", "title"),
    paper_sort_columns_display = c("Year", "Author", "Title"),

    # Used by the export module to build BibEntry objects for BibTeX, APA,
    # Vancouver, and RIS output.  Keys are column names in the CSV; values are
    # BibTeX field names recognised by RefManageR.
    paper_citation_bibtex_field_map = list(
        title   = "title",
        authors = "author",
        year    = "year",
        journal = "journal",
        volume  = "volume",
        issue   = "number",
        pages   = "pages",
        doi     = "doi"
    ),

    # Color pallette
    # These values are also written to www/styles_runtime.css so the stylesheet
    # can reference them as CSS custom properties (var(--color-*)).
    colors = list(
        all_points        = "#30a9ff",
        high_confidence   = "#46A040",
        medium_confidence = "#FDB915",
        low_confidence    = "#CC3D3D",
        in_progress       = "#FFC0CB",
        heatmap_min       = "rgba(31,119,180,0)",    # fully transparent (same hue as all_points)
        heatmap_max       = "rgba(31,119,180,0.35)" # light blue tint at max count
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
writeLines(css, "www/styles_runtime.css")


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
        all = list(display_text = NULL, color = egm_definition$colors$all_points,
                   index = 1L, offset_x = 0.00, offset_y = 0.00)
    )
    if (has_confidence) {
        meta$high   <- list(display_text = "High Confidence",
                            color = egm_definition$colors$high_confidence,
                            index = next_idx,      offset_x =  0.35, offset_y =  0.35)
        meta$medium <- list(display_text = "Medium Confidence",
                            color = egm_definition$colors$medium_confidence,
                            index = next_idx + 1L, offset_x =  0.00, offset_y =  0.35)
        meta$low    <- list(display_text = "Low Confidence",
                            color = egm_definition$colors$low_confidence,
                            index = next_idx + 2L, offset_x = -0.35, offset_y =  0.35)
        next_idx <- next_idx + 3L
    }
    if (has_in_progress) {
        meta$in_progress <- list(display_text = "In Progress",
                                 color = egm_definition$colors$in_progress,
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
            !!x_col := fct_relevel(factor(.data[[x_col]]), "Other", "None Given", after = Inf),
            !!y_col := fct_relevel(factor(.data[[y_col]]), "None Given", "Other")
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

# Compute the fixed plot width (same formula as create_egm_figure) and write a
# max-width rule so the plot-section-header never exceeds the plot right edge.
local({
    n_x   <- length(unique(initial_egm_data$all$counts[[egm_definition$x_column]]))
    max_w <- n_x * egm_definition$plot_cell_width_px + 260 + 40
    cat(paste0(".plot-section-header { max-width: ", max_w, "px; }
"),
        file = "www/styles_runtime.css", append = TRUE)
})
