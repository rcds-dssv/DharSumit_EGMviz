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
# Minimum height helper
# =============================================================================

# Returns the minimum pixel height needed for a comparison plot so that axis
# tick labels and legend entries don't overlap.
#
# Bar:  50 px per group (2-line wrapped labels + spacing)
# Year: 330 px base + 15 px per group beyond the first 2 (legend rows)
# Meta: counts actual (group, meta_val) bars drawn.
#
# All values include the cp_layout margin overhead (~120 px total t+b).
compute_cp_min_height <- function(labeled_df, plot_type, meta_col = NULL) {
    OVERHEAD <- 120L
    MIN_H    <- 200L
    if (is.null(labeled_df) || nrow(labeled_df) == 0) return(MIN_H)

    n_groups <- dplyr::n_distinct(labeled_df$.group_label)

    if (plot_type == "bar")
        return(max(MIN_H, OVERHEAD + n_groups * 50L))

    if (plot_type == "year")
        return(max(MIN_H, 330L + max(0L, n_groups - 2L) * 15L))

    if (plot_type == "meta" &&
        !is.null(meta_col) && meta_col %in% names(labeled_df)) {
        # Mirror make_meta_plot's filter so we count only bars actually drawn
        filtered <- labeled_df %>%
            dplyr::filter(!is.na(.data[[meta_col]]),
                          trimws(as.character(.data[[meta_col]])) != "")
        if (nrow(filtered) == 0) return(MIN_H)
        n_cats     <- dplyr::n_distinct(filtered[[meta_col]])
        n_bars     <- dplyr::n_distinct(
                          filtered$.group_label, filtered[[meta_col]])
        return(max(MIN_H, OVERHEAD + n_cats * 12L + n_bars * 22L))
    }

    return(MIN_H)
}


# =============================================================================
# Plot builders
# =============================================================================

# Shared plotly layout settings.
# Note: font/grid colors below apply to the downloaded image only.
# In the browser, plotly SVG text and grid strokes are overridden via styles.css.
# plotly:: prefix avoids masking by httr::layout or base::layout.
cp_layout <- function(p, xlab = "", ylab = "", show_legend = FALSE) {
    plotly::layout(p,
        font          = list(color = "black", size = 11),
        # Small title standoff keeps the x-axis title tucked under the tick
        # labels so it stays clear of the horizontal legend placed below.
        xaxis = list(title        = list(text = xlab, font = list(size = 12),
                                         standoff = 10),
                     gridcolor    = "#cccccc",
                     linecolor    = "#cccccc",
                     zerolinecolor = "#cccccc",
                     tickfont     = list(color = "black")),
        yaxis = list(title        = list(text = ylab, font = list(size = 12)),
                     gridcolor    = "#cccccc",
                     linecolor    = "#cccccc",
                     zerolinecolor = "#cccccc",
                     tickfont     = list(color = "black")),
        margin     = list(l = 60, r = 20, t = 40, b = 60, pad = 2),
        showlegend = show_legend,
        legend     = list(font        = list(color = "black", size = 10),
                          bgcolor     = "rgba(0,0,0,0)",
                          orientation = "h", x = 0,
                          y = -0.30, yanchor = "top")
    )
}

# Shared plotly config: only the save-image button.
# plotly:: prefix avoids masking by httr::config (httr is a transitive dep).
cp_config <- function(p) {
    plotly::config(p,
        displaylogo = FALSE,
        modeBarButtonsToRemove = list(
            "select2d", "lasso2d",
            "zoomIn2d", "zoomOut2d", "autoScale2d",
            "hoverClosestCartesian", "hoverCompareCartesian", "toggleSpikelines"
        )
    )
}

# Placeholder shown when no selection is active or data is unavailable.
cp_placeholder <- function(msg = "Select one or more EGM points to see comparison plots.") {
    plot_ly(type = "scatter", mode = "markers") %>%
        add_annotations(text = msg, x = 0.5, y = 0.5,
                        xref = "paper", yref = "paper",
                        showarrow = FALSE,
                        font = list(color = "black", size = 13)) %>%
        cp_layout() %>%
        cp_config()
}


# ── Bar plot: total papers per group ─────────────────────────────────────────

make_bar_plot <- function(labeled_df) {
    counts <- labeled_df %>%
        dplyr::group_by(.group_label, .group_color, .group_idx) %>%
        dplyr::summarise(n = dplyr::n(), .groups = "drop") %>%
        dplyr::arrange(.group_idx) %>%
        dplyr::mutate(.group_label = wrap_for_plotly(.group_label, width = 25))

    max_val <- max(counts$n)
    x_axis_opts <- if (max_val <= 10) {
        list(dtick = 1, tickformat = "d")
    } else {
        list(tickformat = "d", nticks = 10)
    }

    plot_ly(
        data        = counts,
        y           = ~.group_label,
        x           = ~n,
        type        = "bar",
        orientation = "h",
        marker      = list(color   = ~.group_color,
                           line    = list(width = 0)),
        hovertemplate = "%{y}<br>N Papers: %{x}<extra></extra>"
    ) %>%
        cp_layout(xlab = "Number of papers") %>%
        plotly::layout(xaxis = x_axis_opts) %>%
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
        dplyr::mutate(.year        = suppressWarnings(as.integer(.data[[year_col]])),
                      .group_label = wrap_for_plotly(.group_label, width = 25)) %>%
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
            width         = 0.8,
            name          = groups$.group_label[i],
            marker        = list(color   = groups$.group_color[i],
                                 line    = list(width = 0)),
            hovertemplate = paste0(groups$.group_label[i],
                                   "<br>Year: %{x}<br>N Papers: %{y}<extra></extra>")
        )
    }

    n_years <- dplyr::n_distinct(df$.year)
    x_axis_opts <- if (n_years <= 10) {
        list(dtick = 1, tickformat = "d")
    } else {
        list(tickformat = "d", nticks = 10)
    }

    max_y <- df %>%
        dplyr::group_by(.year) %>%
        dplyr::summarise(total = dplyr::n(), .groups = "drop") %>%
        dplyr::pull(total) %>%
        max()
    y_axis_opts <- if (max_y <= 10) {
        list(dtick = 1, tickformat = "d")
    } else {
        list(tickformat = "d", nticks = 10)
    }

    p %>%
        layout(barmode = "stack") %>%
        cp_layout(xlab = "Year", ylab = "Number of Papers",
                  show_legend = nrow(groups) > 1) %>%
        plotly::layout(xaxis = x_axis_opts, yaxis = y_axis_opts) %>%
        cp_config()
}


# ── Year line plot: one line per group, actual counts (not stacked) ──────────

make_year_line_plot <- function(labeled_df) {
    year_col <- bib_col_name("year")

    if (is.na(year_col) || !(year_col %in% names(labeled_df))) {
        return(cp_placeholder(
            "Year column not configured in paper_citation_bibtex_field_map."))
    }

    df <- labeled_df %>%
        dplyr::mutate(.year        = suppressWarnings(as.integer(.data[[year_col]])),
                      .group_label = wrap_for_plotly(.group_label, width = 25)) %>%
        dplyr::filter(!is.na(.year))

    if (nrow(df) == 0)
        return(cp_placeholder("No valid year data for the current selection."))

    groups <- df %>%
        dplyr::select(.group_label, .group_color, .group_idx) %>%
        dplyr::distinct() %>%
        dplyr::arrange(.group_idx)

    # Total papers per year summed across all groups (used for the total trace
    # and for setting the y-axis ceiling when multiple groups are shown).
    total_df <- df %>%
        dplyr::count(.group_label, .year) %>%
        dplyr::group_by(.year) %>%
        dplyr::summarise(n = sum(n), .groups = "drop") %>%
        dplyr::arrange(.year)

    p <- plot_ly()
    for (i in seq_len(nrow(groups))) {
        gdf <- df[df$.group_label == groups$.group_label[i], ] %>%
            dplyr::count(.year) %>%
            dplyr::arrange(.year)
        p <- p %>% add_trace(
            data          = gdf,
            x             = ~.year, y = ~n,
            type          = "scatter",
            mode          = "lines+markers",
            name          = groups$.group_label[i],
            line          = list(color = groups$.group_color[i], width = 2),
            marker        = list(color = groups$.group_color[i], size = 12),
            hovertemplate = paste0(groups$.group_label[i],
                                   "<br>Year: %{x}<br>N Papers: %{y}<extra></extra>")
        )
    }

    # Total line: dashed, uses the "all" trace color; only added when multiple
    # groups are selected (with one group it would duplicate that group's line).
    if (nrow(groups) > 1) {
        p <- p %>% add_trace(
            data          = total_df,
            x             = ~.year, y = ~n,
            type          = "scatter",
            mode          = "lines+markers",
            name          = "Total",
            line          = list(color = egm_metadata$all$color, width = 2, dash = "dash"),
            marker        = list(color = egm_metadata$all$color, size = 12),
            hovertemplate = "Total<br>Year: %{x}<br>N Papers: %{y}<extra></extra>"
        )
    }

    n_years <- dplyr::n_distinct(df$.year)
    x_axis_opts <- if (n_years <= 10) {
        list(dtick = 1, tickformat = "d")
    } else {
        list(tickformat = "d", nticks = 10)
    }

    # When multiple groups are present the total line reaches the highest value;
    # use total_df$n as the ceiling so the y-axis always fits all traces.
    max_y <- max(total_df$n)
    y_axis_opts <- if (max_y <= 10) {
        list(dtick = 1, tickformat = "d")
    } else {
        list(tickformat = "d", nticks = 10)
    }

    p %>%
        cp_layout(xlab = "Year", ylab = "Number of Papers",
                  show_legend = nrow(groups) > 1) %>%
        plotly::layout(xaxis = x_axis_opts, yaxis = y_axis_opts) %>%
        cp_config()
}


# ── Meta breakdown: grouped horizontal bars per group ─────────────────────────

make_meta_plot <- function(labeled_df, meta_col,
                           meta_display_name = meta_col) {
    if (is.null(meta_col) || !(meta_col %in% names(labeled_df)))
        return(cp_placeholder("Meta column not available."))

    df <- labeled_df %>%
        dplyr::filter(!is.na(.data[[meta_col]]),
                      trimws(as.character(.data[[meta_col]])) != "")

    if (nrow(df) == 0)
        return(cp_placeholder("No data available to plot."))



    counts <- df %>%
        dplyr::mutate(.meta_val    = as.character(.data[[meta_col]]),
                      .group_label = wrap_for_plotly(.group_label, width = 25)) %>%
        dplyr::group_by(.group_label, .group_color, .group_idx, .meta_val) %>%
        dplyr::summarise(n = dplyr::n(), .groups = "drop") %>%
        dplyr::mutate(.meta_val = wrap_for_plotly(.meta_val, width = 20))

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
                                 line    = list(width = 0)),
            hovertemplate = paste0(groups$.group_label[i], "<br>",
                                   meta_display_name,
                                   ": %{y}<br>N Papers: %{x}<extra></extra>")
        )
    }

    max_val <- max(counts$n)
    x_axis_opts <- if (max_val <= 10) {
        list(dtick = 1, tickformat = "d")
    } else {
        list(tickformat = "d", nticks = 10)
    }

    p %>%
        layout(barmode = "group") %>%
        cp_layout(xlab = "Number of Papers", ylab = meta_display_name,
                  show_legend = nrow(groups) > 1) %>%
        plotly::layout(xaxis = x_axis_opts) %>%
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
        div(class = "panel-strip panel-strip-h", "Comparison Plots"),
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
            # cp_inner height is 100% (fills panel) OR the computed min-height
            # (whichever is larger), set via sendCustomMessage → layout.js.
            # This lets the wrapper scroll when many groups/categories are shown.
            div(id = ns("cp_inner"), style = "height: 100%;",
                plotlyOutput(ns("plot"), height = "100%")
            )
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
        # Persists the year chart style ("bar" = stacked bar, "line" = line plot)
        # across type switches so the user's choice is restored on re-render.
        active_year_view <- reactiveVal("bar")

        observeEvent(input$type_bar,   active_type("bar"),  ignoreInit = TRUE)
        observeEvent(input$type_year,  active_type("year"), ignoreInit = TRUE)
        observeEvent(input$type_meta,  active_type("meta"), ignoreInit = TRUE)
        observeEvent(input$meta_col,   active_meta(input$meta_col),       ignoreInit = TRUE)
        observeEvent(input$year_view,  active_year_view(input$year_view), ignoreInit = TRUE)

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
                if (active == "year")
                    selectInput(ns("year_view"), NULL,
                                choices  = c("Stacked Bar" = "bar", "Line" = "line"),
                                selected = isolate(active_year_view()),
                                width    = "120px"),
                if (active == "meta" && length(meta_choices) > 0)
                    selectInput(ns("meta_col"), NULL,
                                choices  = meta_choices,
                                selected = isolate(active_meta()),
                                width    = "160px")
            )
        })

        output$plot <- renderPlotly({
            ld <- labeled_data()
            if (is.null(ld) || nrow(ld) == 0) {
                session$sendCustomMessage("setCompPlotHeight",
                    list(wrapperId = session$ns("cp_inner"), height = 200L))
                return(cp_placeholder())
            }

            type      <- active_type()
            year_view <- if (type == "year") {
                if (!is.null(input$year_view)) input$year_view else isolate(active_year_view())
            } else NULL
            mc        <- if (type == "meta") {
                if (!is.null(input$meta_col)) input$meta_col else isolate(active_meta())
            } else NULL

            min_h <- compute_cp_min_height(ld, type, mc)
            session$sendCustomMessage("setCompPlotHeight",
                list(wrapperId = session$ns("cp_inner"), height = min_h))

            switch(type,
                bar  = make_bar_plot(ld),
                year = if (isTRUE(year_view == "line"))
                           make_year_line_plot(ld)
                       else
                           make_year_plot(ld),
                meta = {
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

        # Keep outputs live even when their panel is collapsed (display:none).
        # Without this, Shiny suspends hidden outputs and they go stale.
        outputOptions(output, "type_switcher", suspendWhenHidden = FALSE)
        outputOptions(output, "plot",          suspendWhenHidden = FALSE)
    })
}
