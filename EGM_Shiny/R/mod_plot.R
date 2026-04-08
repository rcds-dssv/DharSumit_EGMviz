# =============================================================================
# mod_plot — EGM figure creation
#
# Builds the interactive plotly scatter plot that forms the Evidence Gap Map.
# Each grid cell shows up to five overlapping dots, one per evidence category
# (all papers, high / medium / low confidence, and in-progress). Dot area is
# proportional to the number of papers in that cell.
#
# Public interface:
#   mod_plot_ui(id)       — plotlyOutput placeholder
#   mod_plot_server(...)  — renders the figure and re-attaches JS handlers
#                           whenever egm_data changes
# =============================================================================


# ── Helper: text wrapping ─────────────────────────────────────────────────────

# Wraps text to `width` characters and optionally right-pads each line with
# `padding` extra spaces. Used for axis tick labels and tooltip text.
wrap_for_plotly <- function(x, width = 20, padding = 0) {
    wrapped <- str_wrap(x, width = width)
    lines <- str_split(wrapped, "\n")
    padded_lines <- lapply(lines, function(line_vec) {
        str_pad(line_vec, width = nchar(line_vec) + padding, side = "right")
    })
    sapply(padded_lines, paste, collapse = "<br>")
}


# ── Helper: grid lines ────────────────────────────────────────────────────────

# Returns a list of plotly shape definitions that draw the cell grid (vertical
# and horizontal lines) over the scatter plot.
shapes_for_plotly <- function(n_x, n_y) {
    vlines <- lapply(0:n_x, function(i) {
        list(type = "line",
             x0 = i - 0.5, x1 = i - 0.5,
             y0 = -0.5,    y1 = n_y - 0.5,
             line = list(color = "lightgray", width = 1))
    })
    hlines <- lapply(0:n_y, function(i) {
        list(type = "line",
             x0 = -0.5,    x1 = n_x - 0.5,
             y0 = i - 0.5, y1 = i - 0.5,
             line = list(color = "lightgray", width = 1))
    })
    c(vlines, hlines)
}


# ── Helper: prepare counts dataframe for plotting ─────────────────────────────

# Adds three columns to a counts dataframe so plotly can position and identify
# each dot:
#   x_num / y_num  — numeric positions on the plot axes (0-based index + jitter)
#   customdata     — list column of (x_label, y_label, trace_name) triplets,
#                    read by mod_selection.R when the user clicks or lassos
add_to_counts_df_for_plotly <- function(count_df, x_col, y_col, x_levels, y_levels,
                                        label, x_offset, y_offset) {
    count_df$x_num <- match(count_df[[x_col]], x_levels) - 1 + x_offset
    count_df$y_num <- match(count_df[[y_col]], y_levels) - 1 + y_offset
    count_df <- count_df %>%
        mutate(customdata = Map(list, .[[x_col]], .[[y_col]], label))
    count_df
}


# ── Helper: build heatmap count matrix ───────────────────────────────────────

# Returns an n_y × n_x integer matrix of paper counts for the heatmap trace.
# Cells with no papers in the filtered data are filled with 0.
# Rows correspond to y_levels, columns to x_levels, matching the numeric axis
# positions (0-based) used for the scatter traces.
build_heatmap_z <- function(counts, x_col, y_col, n_col, x_levels, y_levels) {
    z <- matrix(0L, nrow = length(y_levels), ncol = length(x_levels))
    for (i in seq_len(nrow(counts))) {
        xi <- match(as.character(counts[[x_col]][i]), x_levels)
        yi <- match(as.character(counts[[y_col]][i]), y_levels)
        if (!is.na(xi) && !is.na(yi)) {
            z[yi, xi] <- counts[[n_col]][i]
        }
    }
    z
}


# ── Helper: add one trace to the plotly figure ────────────────────────────────

# Adds a single scatter trace to `spec` for the given counts dataframe.
# Marker sizes are computed in pixels (not plotly's internal units) so that
# dot area is proportional to paper count and stays consistent across redraws:
#   - sqrt scaling gives area-proportional perception
#   - counts are clamped at the 99th percentile of the unfiltered data so that
#     a single very large cell does not compress all other dots
add_trace_to_plotly_spec <- function(spec, df, x_col, y_col, n_col,
                                     clean_x_title, clean_y_title, color,
                                     visible = TRUE) {
    desired_max_px <- 14
    desired_min_px <- 1
    # Use the unfiltered data for the cap so sizes stay consistent when filters change
    size_cap <- quantile(initial_egm_data$all$counts[[n_col]], 0.99, na.rm = TRUE)

    df <- df %>%
        mutate(
            clamped     = pmin(.data[[n_col]], size_cap),
            marker_size = scales::rescale(
                sqrt(clamped),
                to   = c(desired_min_px, desired_max_px),
                from = c(0, sqrt(size_cap))
            )
        )

    spec %>% add_trace(
        data       = df,
        x          = ~x_num,
        y          = ~y_num,
        customdata = ~customdata,
        type       = "scatter",
        mode       = "markers",
        marker = list(
            size     = ~marker_size,   # explicit pixel diameters
            sizemode = "diameter",
            sizemin  = 1,
            color    = color,
            opacity  = 1,
            line     = list(color = color, width = 1)
        ),
        text = ~paste0(
            "<b>", clean_x_title, ":</b><br>", wrap_for_plotly(df[[x_col]], 20),
            "<br><br><b>", clean_y_title, ":</b><br>", wrap_for_plotly(df[[y_col]], 20),
            "<br><br><b>N Papers:</b><br>", df[[n_col]]
        ),
        hoverinfo = "text",
        visible   = visible
    )
}


# ── Main figure builder ───────────────────────────────────────────────────────

# Builds and returns the complete EGM plotly figure for the given egm_data.
# Axis levels and marker-size scaling always reference initial_egm_data (the
# unfiltered dataset) so the grid and dot sizes stay stable as filters change.
create_egm_figure <- function(egm_data, plot_source_name, x_col, y_col, n_col,
                              toggle_states = NULL) {

    # Axis dimensions come from the unfiltered data so the grid never shrinks
    n_x <- length(unique(initial_egm_data$all$counts[[x_col]]))
    n_y <- length(unique(initial_egm_data$all$counts[[y_col]]))

    # cell_px is used only to set the relative aspect ratio of the grid shapes;
    # the actual rendered size is controlled by CSS (the plot fills its container)
    cell_px     <- 60
    plot_width  <- n_x * cell_px + 260
    plot_height <- n_y * cell_px

    # Convert column names like "Theme.Assignment" to "Theme Assignment" for display
    clean_x_title <- str_replace_all(x_col, fixed("."), " ")
    clean_y_title <- str_replace_all(y_col, fixed("."), " ")

    # Numeric axis levels fixed to the unfiltered data so category order is stable
    x_levels <- levels(factor(initial_egm_data$all$counts[[x_col]]))
    y_levels <- levels(factor(initial_egm_data$all$counts[[y_col]]))

    # Add numeric positions and customdata to each trace's counts dataframe.
    # Order must match egm_metadata so that the 0-based trace indices are correct.
    for (name in names(egm_data)) {
        egm_data[[name]]$counts <- add_to_counts_df_for_plotly(
            egm_data[[name]]$counts,
            x_col, y_col, x_levels, y_levels,
            label    = name,
            x_offset = egm_metadata[[name]]$offset_x,
            y_offset = egm_metadata[[name]]$offset_y
        )
    }

    n_total <- sum(egm_data$all$counts$n)

    # Base figure + toolbar config
    egm_spec <- plot_ly(source = plot_source_name) %>%
        config(
            responsive      = TRUE,
            displayModeBar  = TRUE,
            doubleClick     = FALSE,
            modeBarButtonsToRemove = c(
                "zoomIn2d", "zoomOut2d", "autoScale2d",
                "hoverClosestCartesian", "hoverCompareCartesian", "toggleSpikelines"
            )
        )

    # ── Heatmap trace (trace index 0, rendered first / behind scatter dots) ──
    #
    # Cells are coloured by the "all" paper count for the currently filtered data.
    # zmax is fixed to the initial (unfiltered) maximum so the colour scale stays
    # consistent as filters are applied — the same approach used for dot sizing.
    # Cells with a count of zero map to the transparent end of the scale.
    # The color ramps from transparent (0 papers) to a neutral gray (90th-percentile papers).
    # Cap at the 90th percentile so one dominant cell does not wash out the rest.
    # Cells above this value all show the maximum gray -- same logic as dot sizing.
    heatmap_zmax <- quantile(initial_egm_data$all$counts[[n_col]], 0.90, na.rm = TRUE)
    heatmap_z    <- build_heatmap_z(
        egm_data$all$counts, x_col, y_col, n_col, x_levels, y_levels
    )

    egm_spec <- egm_spec %>%
        add_trace(
            type       = "heatmap",
            x          = seq(0, length(x_levels) - 1),
            y          = seq(0, length(y_levels) - 1),
            z          = heatmap_z,
            zmin       = 0,
            zmax       = heatmap_zmax,
            colorscale = list(
                list(0, colors$heatmap_min),  # 0 papers   → fully transparent
                list(1, colors$heatmap_max)   # max papers → mid-gray
            ),
            showscale  = FALSE,
            hoverinfo  = "none",
            visible    = if (!is.null(toggle_states)) toggle_states$heatmap else TRUE
        )

    # Add one trace per evidence category.
    # Visibility is set from toggle_states so a filter-triggered re-render
    # always starts with the same layer visibility the user last chose.
    for (name in names(egm_data)) {
        trace_visible <- if (is.null(toggle_states)) TRUE
                         else if (name == "all")                            toggle_states$summary
                         else if (name %in% c("high", "medium", "low"))     toggle_states$confidence
                         else if (name == "ongoing")                        toggle_states$in_progress
                         else TRUE

        egm_spec <- add_trace_to_plotly_spec(
            egm_spec, egm_data[[name]]$counts,
            x_col, y_col, n_col,
            clean_x_title, clean_y_title,
            color   = egm_metadata[[name]]$color,
            visible = trace_visible
        )
    }

    egm_spec <- egm_spec %>% layout(
        margin     = list(t = 120, b = 0, l = 0, r = 0, pad = 10),
        autosize   = TRUE,
        dragmode   = "select",
        showlegend = FALSE,
        xaxis = list(
            type      = "linear",
            tickmode  = "array",
            tickvals  = seq(0, length(x_levels) - 1),
            ticktext  = x_levels,
            range     = c(-0.5, length(x_levels) - 0.5),
            title     = list(text = clean_x_title, standoff = 10),
            side      = "top",
            tickangle = 0,
            showgrid  = FALSE,
            zeroline  = FALSE,
            ticks     = ""
        ),
        yaxis = list(
            type     = "linear",
            tickmode = "array",
            tickvals = seq(0, length(y_levels) - 1),
            ticktext = y_levels,
            range    = c(-0.5, length(y_levels) - 0.5),
            title    = list(text = clean_y_title, standoff = 20),
            showgrid = FALSE,
            zeroline = FALSE,
            ticks    = ""
        ),
        shapes      = shapes_for_plotly(n_x, n_y),
        # "Total N" annotation in the upper-left corner.
        # x/y are in paper coordinates; the exact values are adjusted by
        # repositionPlotlyAnnotation0() in toggles.js after each resize.
        annotations = list(list(
            x         = -0.262, y = 1.072,
            xref      = "paper", yref = "paper",
            text      = paste0("<b>Total N:</b> ", n_total),
            showarrow = FALSE,
            xanchor   = "left", yanchor = "top",
            align     = "left",
            bgcolor   = "rgba(0,0,0,0)",
            bordercolor = "black", borderwidth = 1, borderpad = 10,
            font = list(size = 12)
        ))
    )

    # plotly_build() materialises the figure so we can post-process axis labels.
    # Axis tick text is wrapped here because plotly does not support line breaks
    # in tick labels natively; wrap_for_plotly() inserts <br> tags.
    egm_build <- plotly_build(egm_spec)
    xaxis <- egm_build$x$layout$xaxis
    yaxis <- egm_build$x$layout$yaxis

    if (!is.null(xaxis$categoryarray)) {
        labs <- xaxis$categoryarray
        egm_build$x$layout$xaxis$tickmode <- "array"
        egm_build$x$layout$xaxis$tickvals <- labs
        egm_build$x$layout$xaxis$ticktext <- wrap_for_plotly(labs, 5)
    } else if (!is.null(xaxis$ticktext)) {
        egm_build$x$layout$xaxis$ticktext <- wrap_for_plotly(xaxis$ticktext, 5)
    }
    if (!is.null(yaxis$categoryarray)) {
        labs <- yaxis$categoryarray
        egm_build$x$layout$yaxis$tickmode <- "array"
        egm_build$x$layout$yaxis$tickvals <- labs
        egm_build$x$layout$yaxis$ticktext <- wrap_for_plotly(labs, 24, 2)
    } else if (!is.null(yaxis$ticktext)) {
        egm_build$x$layout$yaxis$ticktext <- wrap_for_plotly(yaxis$ticktext, 24, 2)
    }

    egm_build
}


# ── Shiny module ──────────────────────────────────────────────────────────────

mod_plot_ui <- function(id) {
    ns <- NS(id)
    plotlyOutput(ns("egm_plot"), height = "100%", width = "100%")
}

mod_plot_server <- function(id, egm_data, toggle_states = NULL, plot_source_name, x_col, y_col, n_col) {
    moduleServer(id, function(input, output, session) {

        output$egm_plot <- renderPlotly({
            req(egm_data())
            # isolate() reads the current toggle states without making renderPlotly
            # depend on them — toggle changes go through plotlyProxy, not re-renders.
            ts <- if (!is.null(toggle_states)) isolate(toggle_states()) else NULL
            create_egm_figure(egm_data(), plot_source_name, x_col, y_col, n_col, ts)
        })

        # When the data (and therefore the plot) changes, tell plot_interactions.js
        # to re-attach its click/selection handlers to the newly rendered element.
        observeEvent(egm_data(), {
            req(egm_data())
            session$sendCustomMessage("triggerAttachPlotlyClickHandler", list(source = plot_source_name, ns = session$ns("")))
        })
    })
}
