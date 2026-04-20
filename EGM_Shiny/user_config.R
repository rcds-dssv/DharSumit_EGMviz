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
    plot_points_desired_max_px = 40,
    plot_points_desired_min_px = 1,

    # Minimum pixel size of each grid cell (row height and column width) in the plot.  
    plot_cell_width_px = 50,
    plot_cell_height_px = 50,

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
    plot_colors = list(
        all_points        = "#30a9ff",
        high_confidence   = "#46A040",
        medium_confidence = "#FDB915",
        low_confidence    = "#CC3D3D",
        in_progress       = "#FFC0CB",
        heatmap_min       = "rgba(31,119,180,0)",    # fully transparent (same hue as all_points)
        heatmap_max       = "rgba(31, 118, 180, 0.9)", # light blue tint at max count
        plot_path         = "#3c4b6c",
        plot_text         = "#cfdbf6"
    ),

    # Qualitative palette for comparison plot groups.
    # One color per selected EGM point; cycles if more than 8 groups are selected.
    comparison_colors = c(
        "#e6c35a", "#e05c5c", "#5ae6a0", "#5ab4e6",
        "#a05ae6", "#e65aa5", "#5ae6e6", "#e6a05a"
    ),

    web_colors = list(
        body_bg           = "#0a0e27",
        body_text         = "white",
        top_gradient1     = "#667eea",
        top_gradient2     = "#764ba2",
        container_bg      = "#141b3d",
        container_border  = "#1e2a5a",
        container_text    = "#7c8db5",
        toggle_hover_bg   = "#273a6e",
        toggle_active_bg  = "#4f46e5",
        button_text       = "#a78bfa",
        table_bg          = "#0f1629",
        table_shadow      = "rgba(79, 70, 229, 0.2)",
        tag_default       = "rgba(79, 70, 229, 0.3)",
        tag_special_text  = "#252a36",
        scroll_bg         = "#1e1e1e"
    )
)
