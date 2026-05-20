# =============================================================================
# DEFINITIONS
# This section contains (hopefully) all of the variables one would need to 
# change in order to implement basic tweaks to the dashboard
# =============================================================================

egm_definition <- list(
    # The relative path to the data file.
    datafile_path = "data/AAHHC_Scoping_2026_final.csv",

    # App title shown in the header bar and the help modal welcome section.
    app_title = "HEARING LITERATURE EVIDENCE GAP MAP",

    # Short description shown below the title in the header bar and in the help modal.
    app_description = "Explore hearing research papers by study type. Bubble size reflects the number of papers at each intersection.",

    # Acknowledgements HTML shown in the help modal. Supports inline HTML (links, etc.).
    app_acknowledgements = paste0(
        'This app was developed by ',
        '<a href="https://www.it.northwestern.edu/departments/it-services-support/research/staff/geller.html" ',
        'target="_blank" rel="noopener noreferrer">Aaron M. Geller</a> ',
        'with assistance from ',
        '<a href="https://claude.ai" target="_blank" rel="noopener noreferrer">Claude</a> (Anthropic). ',
        'The literature review was performed by ',
        '<a href="https://www.northwestern.edu/provost/about/bios/sumitrajit-sumit-dhar.html" ',
        'target="_blank" rel="noopener noreferrer">Sumit Dhar</a>, ',
        '<a href="https://www.umass.edu/public-health-sciences/about/directory/jasleen-singh" ',
        'target="_blank" rel="noopener noreferrer">Jasleen Singh</a> and their colleagues.'
    ),

    # Initial height (px) of the comparison plots sub-panel. The user can drag to resize.
    comparison_panel_default_height_px = 300,

    # The column name to use for the x axis of the EGM figure and the display name
    x_column = "WorkType",
    x_column_display = "Article Type",

    # Optional named character vector mapping x-axis category values to descriptions.
    # Shown as a bulleted list under "Reading the Map" in the help modal. NULL to omit.
    x_column_descriptions = NULL,

    # The column name to use for the y axis of the EGM figure and the display name
    y_column = "Theme",
    y_column_display = "Theme",

    # Optional named character vector mapping y-axis category values to plain-text
    # descriptions.  When non-NULL these are shown as a bulleted list under
    # "Reading the Map" in the help modal, sorted alphabetically to match the figure.
    # Set to NULL to omit entirely.
    y_column_descriptions = c(
        "Care seeking"                                       = "Examines how perceptions, knowledge, and social influences shape the recognition of hearing needs and the decision to seek hearing health care.",
        "Care systems navigation, and innovation"            = "Examines how care pathways, delivery models, and system design affect access, navigation, and hearing healthcare outcomes.",
        "Consequences of unaddressed hearing loss"           = "Examines the physiological, cognitive, social, and societal consequences of unaddressed hearing loss, and the extent to which hearing health care can mitigate these outcomes across diverse populations.",
        "Diversity and equity"                               = "Examines how social, cultural, geographic, and structural factors shape hearing health needs, perceptions, measurement, access, and outcomes among historically underrepresented and marginalized populations.",
        "Economics and policy implications of hearing health care" = "Examines the economic value, cost effectiveness, pricing, and policy drivers of hearing health care, and how these factors influence access, adoption, and outcomes.",
        "OTC hearing aids"                                   = "Examines the uptake, use, and outcomes of over the counter hearing aids, including what supports are needed for their success.",
        "Outcomes"                                           = "Examines the individual, technological, and contextual factors that influence hearing aid outcomes, including how outcomes may be defined, measured, and experienced by hearing aid users.",
        "Screening and assessment"                           = "Examines how hearing screening and assessment can be designed, communicated, and integrated across various settings to improve usability of hearing healthcare, early action, and equitable outcomes across diverse populations.",
        "Stigma"                                             = "Examines how stigma influences the perception, access, and utilization of hearing health care.",
        "Technology"                                         = "Examines emerging technologies (i.e., artificial intelligence, machine learning, and mobile platforms) that are being leveraged to improve hearing health access, engagement, and real world outcomes.",
        "Workforce"                                          = "Examines how workforce composition, training, support, and diversity influence the delivery, acceptability, and effectiveness of hearing health care."
    ),

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
    filter_dropdown_list = c("USOrigin", "OriginalResearchType", "StudySetting", "ReviewType", "ObservationalStudy"),
    filter_dropdown_list_display = c("US Origin", "Research Type", "Study Setting", "Review Type", "Observational Study Design"),

    # Optional conditional filter dependencies.
    # Each entry hides a dependent filter until a specific parent filter value is chosen.
    #   filter    — column name of the dependent (child) filter
    #   parent    — column name of the filter it depends on
    #   show_when — parent values that make the child filter visible
    # The child filter is hidden and reset to "All" whenever the parent value is
    # not in show_when.  Its choices are drawn only from rows where the parent
    # column is in show_when.  Set to NULL to disable.
    filter_conditional = list(
        list(
            filter    = "ObservationalStudy",
            parent    = "OriginalResearchType",
            show_when = c("Observational", "Retrospective Observational")
        )
    ),

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
    paper_sort_columns         = c("year", "authors", "title", "WorkType", "Theme"),
    paper_sort_columns_display = c("Year", "Author", "Title", "Work Type", "Theme"),

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

    # Color palette — plot data colors (same for both light and dark themes).
    # These are written to styles_runtime.css as --color-* CSS custom properties.
    #
    # egm_plot_text: theme-invariant color used for EGM plot axis tick labels,
    #   axis title annotations, and the WorkType/Theme tags in the paper panel.
    #
    # plot_text (in web_dark/light_colors): theme-aware color used for comparison
    #   plot text, the Total N annotation in the EGM plot, and general UI text.
    #
    # plot_path (in web_dark/light_colors): theme-aware color used for EGM grid
    #   lines, comparison plot grid lines, mode-bar icons, and scrollbar thumbs.
    #   It cannot be moved to plot_colors because it is used outside the EGM plot.
    # Columns searched when the user types in the search bar.
    # Case-insensitive substring match; a paper matches if ANY column contains the query.
    search_columns = c("title", "authors", "journal",
                       "WorkType", "Theme",
                       "USOrigin", "OriginalResearchType", "StudySetting",
                       "ObservationalStudy", "ReviewType"),

    plot_colors = list(
        all_points        = "#30a9ff",
        high_confidence   = "#46A040",
        medium_confidence = "#FDB915",
        low_confidence    = "#CC3D3D",
        in_progress       = "#FFC0CB",
        search_points     = "#FF8C00",  # warm orange — search result dots on the EGM plot
        heatmap_min       = "rgba(31, 118, 180, 0.2)", # color at 1 paper
        heatmap_max       = "rgba(31, 118, 180, 0.95)", # color at max count
        x_axis_bg         = "#32417B", # x axis background color, and used for tags in paper panel
        y_axis_bg         = "#4B4581",  # y axis background color, and used for tags in paper panel
        egm_plot_text     = "#cfdbf6"
    ),

    # Dark-mode UI colors (default theme).
    # All keys are written as --color-* CSS custom properties in :root {}.
    web_dark_colors = list(
        body_bg              = "#0a0e27",
        body_text            = "white",
        top_gradient1        = "#667eea",
        top_gradient2        = "#a78bfa",
        container_bg         = "#141b3d",
        container_border     = "#1e2a5a",
        container_text       = "#7c8db5",
        toggle_hover_bg      = "#273a6e",
        toggle_active_bg     = "#4f46e5",
        button_text          = "#a78bfa",
        table_bg             = "#0f1629",
        table_shadow         = "rgba(79, 70, 229, 0.2)",
        tag_special_text     = "#252a36",
        scroll_bg            = "#1e1e1e",
        plot_path            = "#3c4b6c",
        plot_text            = "#cfdbf6",
        muted_text           = "#888888",
        modal_overlay        = "rgba(0, 0, 0, 0.65)",
        how_to_use_border    = "rgba(255, 255, 255, 1.0)",
        how_to_use_hover_bg  = "rgba(255, 255, 255, 0.15)"
    ),

    # Light-mode UI colors.
    # Keys are written as --color-* CSS custom properties in [data-theme="light"] {},
    # overriding the dark-mode defaults above.
    web_light_colors = list(
        body_bg              = "#f4f5fc",
        body_text            = "#1a1a2e",
        top_gradient1        = "#667eea",
        top_gradient2        = "#a78bfa",
        container_bg         = "#ffffff",
        container_border     = "#cdd0e8",
        container_text       = "#555b7a",
        toggle_hover_bg      = "#e8eaf6",
        toggle_active_bg     = "#4f46e5",
        button_text          = "#4f46e5",
        table_bg             = "#eef0fb",
        table_shadow         = "rgba(79, 70, 229, 0.12)",
        tag_special_text     = "#ffffff",
        scroll_bg            = "#dde0f0",
        plot_path            = "#a0a8cc",
        plot_text            = "#1a1a2e",
        muted_text           = "#8a90aa",
        modal_overlay        = "rgba(0, 0, 0, 0.45)",
        how_to_use_border    = "rgba(89, 91, 122, 1.0)",
        how_to_use_hover_bg  = "rgba(89, 91, 122, 0.2)"
    ),

    # Default theme on app load ("dark" or "light").
    # Users can toggle in the UI; their preference is saved in localStorage.
    default_theme = "dark"
)
