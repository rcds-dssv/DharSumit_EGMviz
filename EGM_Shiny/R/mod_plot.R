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
    if (nrow(count_df) == 0) {
        count_df$x_num      <- numeric(0)
        count_df$y_num      <- numeric(0)
        count_df$customdata <- list()
        return(count_df)
    }
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

    
    # Use the unfiltered data for the cap so sizes stay consistent when filters change
    size_cap <- quantile(initial_egm_data$all$counts[[n_col]], 0.99, na.rm = TRUE)

    df <- df %>%
        mutate(
            clamped     = pmin(.data[[n_col]], size_cap),
            marker_size = scales::rescale(
                sqrt(clamped),
                to   = c(egm_definition$plot_points_desired_min_px, egm_definition$plot_points_desired_max_px),
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

    # data_height/data_width: pixel extents of the data area (0–1 in paper coords).
    # plot_height adds the top margin and bottom margin (10 px).
    # plot_width adds ~260 px for the y-axis label area.
    data_height <- n_y * egm_definition$plot_cell_height_px
    data_width  <- n_x * egm_definition$plot_cell_width_px
    margin_t    <- 120
    plot_width  <- data_width + 260
    plot_height <- data_height + margin_t + 10

    # Paper-coordinate positions derived from pixel offsets so the layout stays
    # consistent regardless of grid size.
    # x0_margin: left edge of both axis boxes, reaching into the y-axis label area.
    x0_margin      <- -175 / data_width
    # x title: level with the x tick labels
    ann_x_title_y  <- 1 + 20  / data_height
    # y title: just above the topmost y tick label (top of data area)
    ann_y_title_y  <- (n_y - 0.5) / n_y
    # header box top: above the x tick label row
    top_box_y1     <- 1 + 75  / data_height
    # Total N: near the top of the margin, above the header box
    ann_total_n_y  <- 1 + 100 / data_height
    # small x padding (8 px) inside the left edge of the boxes
    ann_x          <- x0_margin + 20 / data_width


    clean_x_title <- egm_definition$x_column_display
    clean_y_title <- egm_definition$y_column_display

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
    egm_spec <- plot_ly(source = plot_source_name, width = plot_width, height = plot_height) %>%
        plotly::config(
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
    # Cells are colored by the "all" paper count for the currently filtered data.
    # zmax is fixed to the initial (unfiltered) maximum so the color scale stays
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
                list(0, egm_definition$colors$heatmap_min),  # 0 papers 
                list(1, egm_definition$colors$heatmap_max)   # max papers
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
                         else if (name == "all")                        toggle_states$summary
                         else if (name %in% c("high", "medium", "low")) toggle_states$confidence
                         else if (name == "in_progress")                toggle_states$in_progress
                         else TRUE

        egm_spec <- add_trace_to_plotly_spec(
            egm_spec, egm_data[[name]]$counts,
            x_col, y_col, n_col,
            clean_x_title, clean_y_title,
            color   = egm_metadata[[name]]$color,
            visible = trace_visible
        )
    }

    # Rectangle shapes framing the axis label areas.
    axis_box_line  <- list(color = "rgba(160,170,200,0.35)", width = 1)
    axis_box_fill  <- "rgba(255,255,255,0.04)"
    top_box <- list(
        type = "rect", xref = "paper", yref = "paper",
        x0 = x0_margin, x1 = 1.0,
        y0 = 1.0,       y1 = top_box_y1,
        fillcolor = axis_box_fill, line = axis_box_line
    )
    left_box <- list(
        type = "rect", xref = "paper", yref = "paper",
        x0 = x0_margin, x1 = 0.0,
        y0 = 0.0,       y1 = 1.0,
        fillcolor = axis_box_fill, line = axis_box_line
    )

    # Note: font colors below apply to the downloaded image only.
    # In the browser, all plotly SVG text is overridden to white via styles.css.
    egm_spec <- egm_spec %>% layout(
        margin     = list(t = margin_t, b = 10, l = 0, r = 0, pad = 10),
        autosize   = FALSE,
        dragmode   = "select",
        showlegend = FALSE,
        font = list(color = "black"),
        xaxis = list(
            type      = "linear",
            tickmode  = "array",
            tickvals  = seq(0, length(x_levels) - 1),
            ticktext  = x_levels,
            range     = c(-0.5, length(x_levels) - 0.5),
            title     = list(text = ""),
            side      = "top",
            tickangle = 0,
            showgrid  = FALSE,
            zeroline  = FALSE,
            ticks     = "",
            tickfont  = list(color = "black")
        ),
        yaxis = list(
            type     = "linear",
            tickmode = "array",
            tickvals = seq(0, length(y_levels) - 1),
            ticktext = y_levels,
            range    = c(-0.5, length(y_levels) - 0.5),
            title    = list(text = ""),
            showgrid = FALSE,
            zeroline = FALSE,
            ticks    = "",
            tickfont = list(color = "black")
        ),
        shapes = c(shapes_for_plotly(n_x, n_y), list(top_box, left_box)),
        annotations = list(
            # X-axis title: upper-left, inline with x tick labels
            list(
                x = ann_x, y = ann_x_title_y,
                xref = "paper", yref = "paper",
                text = paste0("<i>", clean_x_title, " &#8594;</i>"),
                showarrow = FALSE,
                xanchor = "left", yanchor = "middle",
                font = list(size = 16, color = "black")
            ),
            # Y-axis title: upper-left, just above the topmost y tick label
            list(
                x = ann_x, y = ann_y_title_y,
                xref = "paper", yref = "paper",
                text = paste0("<i>", clean_y_title, " &#8595;</i>"),
                showarrow = FALSE,
                xanchor = "left", yanchor = "bottom",
                font = list(size = 16, color = "black")
            ),
            # Total N: top-left corner, above the header box
            list(
                x = ann_x, y = ann_total_n_y,
                xref = "paper", yref = "paper",
                text = paste0("<b>Total N:</b> ", n_total),
                showarrow = FALSE,
                xanchor = "left", yanchor = "top",
                font = list(size = 12, color = "black")
            )
        )
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
