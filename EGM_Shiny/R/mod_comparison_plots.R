# =============================================================================
# mod_comparison_plots — side-by-side comparison charts for selected EGM points
#
# Three switchable plotly charts driven by the current EGM selection:
#   count  — horizontal bar: total papers per selected WorkType / Theme group
#   year — stacked bar histogram of publication year, one layer per group
#   meta — grouped horizontal bars for a chosen meta column, one bar per group
#
# All charts share the same qualitative group colours defined in
# egm_definition$comparison_colors (via make_group_info() in app_config.R).
# Only the save-image modebar button is shown.
#
# Public interface:
#   mod_comparison_plots_ui(id)
#   mod_comparison_plots_server(id, clicked_info, egm_data)
# =============================================================================


# =============================================================================
# Data helpers
# =============================================================================

# Builds a per-group dataframe for plotting.  Each row is one paper; a paper
# may appear multiple times if it was selected in multiple groups (e.g. "all"
# and "high" traces for the same cell).
build_labeled_data <- function(clicked_info, egm_data, x_col, y_col) {
    if (is.null(clicked_info) || length(clicked_info) == 0) return(NULL)

    group_info <- make_group_info(clicked_info)

    group_dfs <- lapply(seq_along(clicked_info), function(i) {
        pt <- clicked_info[[i]]
        gi <- group_info[[i]]

        trace_suffix <- {
            dt <- egm_metadata[[pt$trace_id]]$display_text
            if (!is.null(dt)) paste0(" (", dt, ")") else ""
        }

        df <- egm_data[[pt$trace_id]]$df %>%
            dplyr::filter(.[[x_col]] == pt$clicked_x,
                          .[[y_col]] == pt$clicked_y)
        if (nrow(df) == 0) return(NULL)

        df$.group_label <- paste0(pt$clicked_x, " / ", pt$clicked_y, trace_suffix)
        df$.group_color <- gi$color
        df$.group_idx   <- i
        df
    })

    dplyr::bind_rows(Filter(Negate(is.null), group_dfs))
}


# =============================================================================
# Plot builders
# =============================================================================

# Shared plotly layout settings for the dark theme.
# plotly:: prefix avoids masking by httr::layout or base::layout.
cp_layout <- function(p, xlab = "", ylab = "", show_legend = FALSE) {
    txt  <- egm_definition$plot_colors$plot_text
    grid <- egm_definition$plot_colors$plot_path

    plotly::layout(p,
        font          = list(color = txt, size = 11),
        xaxis = list(title = list(text = xlab, font = list(size = 12)),
                     gridcolor    = grid, 
                     linecolor     = grid,
                     zerolinecolor = grid,
                     tickfont     = list(color = txt)),
        yaxis = list(title        = list(text = ylab, font = list(size = 12)),
                     gridcolor    = grid, 
                     linecolor     = grid,
                     zerolinecolor = grid,
                     tickfont     = list(color = txt)),
        margin     = list(l = 60, r = 20, t = 40, b = 60, pad = 2),
        showlegend = show_legend,
        legend     = list(font        = list(color = txt, size = 10),
                          bgcolor     = "rgba(0,0,0,0)",
                          orientation = "h", x = 0, y = -0.15)
    )
}

# Shared plotly config: only the save-image button.
# plotly:: prefix avoids masking by httr::config (httr is a transitive dep).
cp_config <- function(p) {
    plotly::config(p,
        displaylogo = FALSE,
        modeBarButtonsToRemove = list(
            "zoom2d", "pan2d", "select2d", "lasso2d",
            "zoomIn2d", "zoomOut2d", "autoScale2d", "resetScale2d",
            "hoverClosestCartesian", "hoverCompareCartesian", "toggleSpikelines"
        )
    )
}

# Placeholder shown when no selection is active or data is unavailable.
cp_placeholder <- function(msg = "Select one or more EGM points to see comparison plots.") {
    txt <- egm_definition$plot_colors$plot_text
    plot_ly() %>%
        add_annotations(text = msg, x = 0.5, y = 0.5,
                        xref = "paper", yref = "paper",
                        showarrow = FALSE,
                        font = list(color = txt, size = 13)) %>%
        cp_layout() %>%
        cp_config()
}


# ── Bar plot: total papers per group ─────────────────────────────────────────

make_bar_plot <- function(labeled_df) {
    counts <- labeled_df %>%
        dplyr::group_by(.group_label, .group_color, .group_idx) %>%
        dplyr::summarise(n = dplyr::n(), .groups = "drop") %>%
        dplyr::arrange(.group_idx)

    plot_ly(
        data        = counts,
        y           = ~.group_label,
        x           = ~n,
        type        = "bar",
        orientation = "h",
        marker      = list(color   = ~.group_color,
                           line    = list(width = 0)),
        hovertemplate = "%{y}<br>Papers: %{x}<extra></extra>"
    ) %>%
        cp_layout(xlab = "Number of papers") %>%
        cp_config()
}


# ── Year histogram: stacked bars per group ────────────────────────────────────

make_year_plot <- function(labeled_df) {
    year_col <- bib_col_name("year")

    if (is.na(year_col) || !(year_col %in% names(labeled_df))) {
        return(cp_placeholder(
            "Year column not configured in paper_citation_bibtex_field_map."))
    }

    df <- labeled_df %>%
        dplyr::mutate(.year = suppressWarnings(as.integer(.data[[year_col]]))) %>%
        dplyr::filter(!is.na(.year))

    if (nrow(df) == 0)
        return(cp_placeholder("No valid year data for the current selection."))

    groups <- df %>%
        dplyr::select(.group_label, .group_color, .group_idx) %>%
        dplyr::distinct() %>%
        dplyr::arrange(.group_idx)

    p <- plot_ly()
    for (i in seq_len(nrow(groups))) {
        gdf <- df[df$.group_label == groups$.group_label[i], ] %>%
            dplyr::count(.year) %>%
            dplyr::arrange(.year)
        p <- p %>% add_trace(
            data          = gdf,
            x             = ~.year, y = ~n,
            type          = "bar",
            name          = groups$.group_label[i],
            marker        = list(color   = groups$.group_color[i],
                                 line    = list(width = 0)),
            hovertemplate = paste0(groups$.group_label[i],
                                   "<br>Year: %{x}<br>Papers: %{y}<extra></extra>")
        )
    }

    p %>%
        layout(barmode = "stack") %>%
        cp_layout(xlab = "Year", ylab = "Papers",
                  show_legend = nrow(groups) > 1) %>%
        cp_config()
}


# ── Meta breakdown: grouped horizontal bars per group ─────────────────────────

make_meta_plot <- function(labeled_df, meta_col,
                           meta_display_name = meta_col) {
    if (is.null(meta_col) || !(meta_col %in% names(labeled_df)))
        return(cp_placeholder("Meta column not available."))

    df <- labeled_df %>%
        dplyr::filter(!is.na(.data[[meta_col]]),
                      trimws(as.character(.data[[meta_col]])) != "",
                      as.character(.data[[meta_col]]) != "Other")

    if (nrow(df) == 0)
        return(cp_placeholder("No data for the selected meta column."))

    counts <- df %>%
        dplyr::mutate(.meta_val = as.character(.data[[meta_col]])) %>%
        dplyr::group_by(.group_label, .group_color, .group_idx, .meta_val) %>%
        dplyr::summarise(n = dplyr::n(), .groups = "drop")

    groups <- counts %>%
        dplyr::select(.group_label, .group_color, .group_idx) %>%
        dplyr::distinct() %>%
        dplyr::arrange(.group_idx)

    p <- plot_ly()
    for (i in seq_len(nrow(groups))) {
        gdf <- counts[counts$.group_label == groups$.group_label[i], ]
        p <- p %>% add_trace(
            data          = gdf,
            y             = ~.meta_val, x = ~n,
            type          = "bar",
            orientation   = "h",
            name          = groups$.group_label[i],
            marker        = list(color   = groups$.group_color[i],
                                 opacity = 0.85,
                                 line    = list(width = 0)),
            hovertemplate = paste0(groups$.group_label[i], "<br>",
                                   meta_display_name,
                                   ": %{y}<br>Papers: %{x}<extra></extra>")
        )
    }

    p %>%
        layout(barmode = "group") %>%
        cp_layout(xlab = "Papers", ylab = meta_display_name,
                  show_legend = nrow(groups) > 1) %>%
        cp_config()
}


# =============================================================================
# Shiny module
# =============================================================================

mod_comparison_plots_ui <- function(id) {
    ns <- NS(id)
    div(
        class = "comparison-subpanel",
        id    = "comparison_subpanel",
        div(
            class = "comparison-header",
            div(class = "comparison-header-left", tags$h3("Comparison Plots")),
            div(class = "comparison-header-right",
                # Switcher + optional meta dropdown rendered together so the
                # dropdown can appear/disappear without a separate renderUI.
                uiOutput(ns("type_switcher"))
            )
        ),
        div(
            class = "comparison-plot-wrapper",
            plotlyOutput(ns("plot"), height = "100%")
        )
    )
}


mod_comparison_plots_server <- function(id, clicked_info, egm_data) {
    moduleServer(id, function(input, output, session) {
        ns <- session$ns

        active_type <- reactiveVal("bar")
        # Persists the meta column selection across type switches so it is
        # restored (via `selected = isolate(active_meta())`) on re-render.
        active_meta <- reactiveVal(
            if (length(egm_definition$paper_meta_columns) > 0)
                egm_definition$paper_meta_columns[[1]]
            else NULL
        )

        observeEvent(input$type_bar,  active_type("bar"),  ignoreInit = TRUE)
        observeEvent(input$type_year, active_type("year"), ignoreInit = TRUE)
        observeEvent(input$type_meta, active_type("meta"), ignoreInit = TRUE)
        observeEvent(input$meta_col,  active_meta(input$meta_col), ignoreInit = TRUE)

        # Labeled per-group dataframe for all three plots.
        labeled_data <- reactive({
            build_labeled_data(clicked_info(), egm_data(),
                               egm_definition$x_column,
                               egm_definition$y_column)
        })

        # Switcher: pipe-separated links + meta dropdown (shown only for "meta").
        output$type_switcher <- renderUI({
            active <- active_type()

            mk_link <- function(input_id, label, type) {
                tags$span(
                    class   = paste0("cp-type-link",
                                     if (active == type) " cp-type-active"),
                    onclick = sprintf(
                        "Shiny.setInputValue('%s', Math.random(), {priority:'event'})",
                        ns(input_id)
                    ),
                    label
                )
            }

            meta_choices <- if (length(egm_definition$paper_meta_columns) > 0)
                setNames(egm_definition$paper_meta_columns,
                         egm_definition$paper_meta_columns_display)
            else c()

            tagList(
                mk_link("type_bar",  "Count",  "bar"),
                tags$span(class = "cp-type-sep", "|"),
                mk_link("type_year", "Year", "year"),
                tags$span(class = "cp-type-sep", "|"),
                mk_link("type_meta", "Meta", "meta"),
                if (active == "meta" && length(meta_choices) > 0)
                    selectInput(ns("meta_col"), NULL,
                                choices  = meta_choices,
                                selected = isolate(active_meta()),
                                width    = "160px")
            )
        })

        output$plot <- renderPlotly({
            ld <- labeled_data()
            if (is.null(ld) || nrow(ld) == 0) return(cp_placeholder())

            switch(active_type(),
                bar  = make_bar_plot(ld),
                year = make_year_plot(ld),
                meta = {
                    mc <- if (!is.null(input$meta_col)) input$meta_col else isolate(active_meta())
                    if (is.null(mc))
                        return(cp_placeholder("No meta columns configured."))
                    disp_idx <- match(mc, egm_definition$paper_meta_columns)
                    disp     <- if (!is.na(disp_idx))
                        egm_definition$paper_meta_columns_display[[disp_idx]]
                    else mc
                    make_meta_plot(ld, mc, disp)
                }
            )
        })
    })
}
