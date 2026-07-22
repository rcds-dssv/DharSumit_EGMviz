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
                                     visible = TRUE,
                                     max_px = egm_definition$plot_points_desired_max_px,
                                     min_px = egm_definition$plot_points_desired_min_px) {


    # Use the unfiltered data for the cap so sizes stay consistent when filters change
    size_cap <- quantile(initial_egm_data$all$counts[[n_col]], 0.99, na.rm = TRUE)

    df <- df %>%
        mutate(
            clamped     = pmin(.data[[n_col]], size_cap),
            marker_size = scales::rescale(
                sqrt(clamped),
                to   = c(min_px, max_px),
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
                              toggle_states = NULL, avail_width = NULL) {

    # Axis dimensions come from the unfiltered data so the grid never shrinks
    n_x <- length(unique(initial_egm_data$all$counts[[x_col]]))
    n_y <- length(unique(initial_egm_data$all$counts[[y_col]]))

    # Horizontal responsive scale.  natural_width is the desktop target; when the
    # container is narrower (mobile) the grid scales down to fit it.  hs is
    # clamped to 1 so at desktop widths every value below equals its original and
    # the figure is unchanged.  The top-margin header (margin_t and the 75/45 px
    # offsets the sticky x-axis bar in layout.js depends on) is left fixed, so
    # vertical offsets stay expressed as fixed pixels over data_height.
    label_w_natural <- 260
    natural_width   <- n_x * egm_definition$plot_cell_width_px + label_w_natural
    hs <- if (is.null(avail_width) || is.na(avail_width) || avail_width <= 0) 1
          else min(1, avail_width / natural_width)

    cell_w      <- egm_definition$plot_cell_width_px  * hs
    cell_h      <- max(34, egm_definition$plot_cell_height_px * hs)
    label_w     <- label_w_natural * hs
    data_height <- n_y * cell_h
    data_width  <- n_x * cell_w
    margin_t    <- 120
    plot_width  <- data_width + label_w
    plot_height <- data_height + margin_t + 10

    # Vertical annotation offsets are fixed px over data_height (the top-margin
    # header is unscaled).  The horizontal annotation position (ann_x) is
    # computed after the y-levels are known (it depends on the label widths).
    ann_x_title_y  <- 1 + 20  / data_height
    ann_y_title_y  <- (n_y - 0.5) / n_y
    top_box_y1     <- 1 + 75  / data_height
    ann_total_n_y  <- 1 + 100 / data_height

    # Fonts scale with hs but never below a legibility floor; the y-axis label
    # wrap width adapts to the scaled label area and font.
    title_font <- max(11, round(16 * hs))
    total_font <- max(9,  round(12 * hs))
    xtick_font <- max(9,  round(12 * hs))
    ytick_font <- max(10, round(12 * hs))
    y_wrap     <- max(10, min(24, floor((label_w - 10) / (ytick_font * 0.55))))
    marker_max <- egm_definition$plot_points_desired_max_px * hs


    clean_x_title <- egm_definition$x_column_display
    clean_y_title <- egm_definition$y_column_display

    # Numeric axis levels fixed to the unfiltered data so category order is stable
    x_levels <- levels(factor(initial_egm_data$all$counts[[x_col]]))
    y_levels <- levels(factor(initial_egm_data$all$counts[[y_col]]))

    # Corner annotations (x/y-axis titles + Total N): pin them to a fixed screen
    # offset from the figure's LEFT edge at every width, so they don't drift
    # right as plotly's y-label gutter (its auto-margin) grows on narrow screens
    # (below ~400px the tick font floors and the labels stop shrinking).
    # est_gutter approximates that auto-margin from the widest wrapped y-label;
    # the target offset is taken from the desktop (font 12) reference and the
    # historical ann_x paper value (-0.7), so at desktop widths ann_x resolves to
    # exactly -0.7 and the desktop layout is unchanged.
    max_line_ch <- max(vapply(strsplit(wrap_for_plotly(y_levels, y_wrap, 2), "<br>"),
                              function(v) max(nchar(v)), numeric(1)))
    est_gutter  <- max_line_ch * ytick_font * 0.5 + 18
    ref_gutter  <- max_line_ch * 12         * 0.5 + 18
    target_sx   <- ref_gutter + (-0.7) * (natural_width - ref_gutter)
    ann_x       <- (target_sx - est_gutter) / max(1, plot_width - est_gutter)

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

    # "select" when any dot trace is visible; "pan" when all are hidden (heatmap
    # only — selection is meaningless without dots carrying customdata).
    any_dots_visible <- if (!is.null(toggle_states)) {
        isTRUE(toggle_states$summary) ||
        isTRUE(toggle_states$confidence) ||
        isTRUE(toggle_states$in_progress)
    } else TRUE

    # Base figure + toolbar config
    egm_spec <- plot_ly(source = plot_source_name, width = plot_width, height = plot_height) %>%
        plotly::config(
            responsive      = TRUE,
            displayModeBar  = TRUE,
            doubleClick     = FALSE,
            modeBarButtonsToRemove = c(
                "zoomIn2d", "zoomOut2d", "autoScale2d",
                "hoverClosestCartesian", "hoverCompareCartesian", "toggleSpikelines",
                "pan","zoom"
            )
        )

    # ── Heatmap trace (trace index 0, rendered first / behind scatter dots) ──
    #
    # Cells are colored by the "all" paper count for the currently filtered data.
    # zmax is fixed to the initial (unfiltered) maximum so the color scale stays
    # consistent as filters are applied — the same approach used for dot sizing.
    # Cells with a count of 1 map to the heatmap_min color of the scale.
    # The color ramps from 1 to the 90th-percentile number of papers.
    # Cap at the 90th percentile so one dominant cell does not wash out the rest.
    # Cells above this value all show the heatmap_max color -- same logic as dot sizing.
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
                list(0, "rgba(0,0,0,0)"),  # 0 is fully transparent 
                list(0.0001, egm_definition$plot_colors$heatmap_min),  # zmin papers 
                list(1, egm_definition$plot_colors$heatmap_max)   # zmax papers
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
            visible = trace_visible,
            max_px  = marker_max
        )
    }

    # Search result trace — always the last trace; initialized invisible with
    # empty arrays.  mod_search_server updates x/y/marker.size/text and
    # toggles visibility via plotlyProxy without triggering a full re-render.
    # No customdata → JS click/lasso handlers ignore it (non-selectable).
    egm_spec <- egm_spec %>% add_trace(
        x          = list(),
        y          = list(),
        type       = "scatter",
        mode       = "markers",
        marker     = list(
            size     = list(),
            sizemode = "diameter",
            sizemin  = 1,
            color    = egm_definition$plot_colors$search_points,
            opacity  = 0.9,
            line     = list(color = egm_definition$plot_colors$search_points, width = 1)
        ),
        text       = list(),
        hoverinfo  = "text",
        visible    = FALSE,
        showlegend = FALSE
    )

    # Rectangle shapes framing the axis label areas.
    # box_x0 is far enough left to always reach the SVG edge (clipped there), so
    # the shaded label backgrounds cover the whole y-label gutter even when
    # plotly's auto-margin grows relative to the data area on narrow screens
    # (below ~400px the tick font floors and the labels stop shrinking).  The
    # annotations still anchor at x0_margin so their text stays on-screen.
    box_x0 <- -3
    axis_box_line  <- list(color = "rgba(160,170,200,0.35)", width = 1)
    axis_box_fill_x  <- egm_definition$plot_colors$x_axis_bg
    axis_box_fill_y  <- egm_definition$plot_colors$y_axis_bg
    top_box <- list(
        type = "rect", xref = "paper", yref = "paper",
        x0 = box_x0, x1 = 1.0,
        y0 = 1.0,    y1 = top_box_y1,
        fillcolor = axis_box_fill_x, line = axis_box_line,
        layer = "below"
    )
    left_box <- list(
        type = "rect", xref = "paper", yref = "paper",
        x0 = box_x0, x1 = 0.0,
        y0 = 0.0,       y1 = 1.0,
        fillcolor = axis_box_fill_y, line = axis_box_line,
        layer = "below"
    )

    # Note: font colors below apply to the downloaded image only.
    # In the browser, all plotly SVG text is overridden to white via styles.css.
    egm_spec <- egm_spec %>% layout(
        margin     = list(t = margin_t, b = 10, l = 0, r = 0, pad = 10),
        autosize   = FALSE,
        dragmode   = if (any_dots_visible) "select" else "pan",
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
            tickfont  = list(color = "black", size = xtick_font)
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
            tickfont = list(color = "black", size = ytick_font)
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
                font = list(size = title_font, color = "black")
            ),
            # Y-axis title: upper-left, just above the topmost y tick label
            list(
                x = ann_x, y = ann_y_title_y,
                xref = "paper", yref = "paper",
                text = paste0("<i>", clean_y_title, " &#8595;</i>"),
                showarrow = FALSE,
                xanchor = "left", yanchor = "bottom",
                font = list(size = title_font, color = "black")
            ),
            # Total N: top-left corner, above the header box
            list(
                x = ann_x, y = ann_total_n_y,
                xref = "paper", yref = "paper",
                text = paste0("<b>Total N:</b> ", n_total),
                showarrow = FALSE,
                xanchor = "left", yanchor = "top",
                font = list(size = total_font, color = "black")
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
        egm_build$x$layout$yaxis$ticktext <- wrap_for_plotly(labs, y_wrap, 2)
    } else if (!is.null(yaxis$ticktext)) {
        egm_build$x$layout$yaxis$ticktext <- wrap_for_plotly(yaxis$ticktext, y_wrap, 2)
    }

    egm_build
}


# ── Helper: sticky x-axis overlay bar ────────────────────────────────────────

# Returns an empty shell div for the sticky x-axis overlay.  All content is
# filled by syncStickyBar() in layout.js after each plotly render: it clones
# the actual rendered SVG and crops it to the top margin_t pixels, guaranteeing
# the bar is pixel-identical to the plot's own x-axis header regardless of
# responsive scaling.
build_sticky_xaxis_html <- function() {
    # threshold: scrollTop (px) at which the top of the plotly colored x-axis
    # rectangle reaches the visible edge of .plot-wrapper.
    # = wrapper padding (20) + (margin_t (120) - colored-rect height (75)) = 65
    HTML('<div id="egm_sticky_xaxis" data-threshold="65"
              style="display:none;position:absolute;top:0;left:0;z-index:10;
                     pointer-events:none;overflow:hidden;"></div>')
}


mod_plot_ui <- function(id) {
    ns <- NS(id)
    tagList(
        build_sticky_xaxis_html(),
        plotlyOutput(ns("egm_plot"), height = "100%", width = "100%")
    )
}

mod_plot_server <- function(id, egm_data, toggle_states = NULL, plot_source_name, x_col, y_col, n_col,
                            viewport_width = reactive(NULL)) {
    moduleServer(id, function(input, output, session) {

        # Desktop target width for the unfiltered grid; the responsive scale is
        # clamped to this so desktop always renders at natural size.
        n_x_global    <- length(unique(initial_egm_data$all$counts[[x_col]]))
        natural_width <- n_x_global * egm_definition$plot_cell_width_px + 260

        # Effective width fed to create_egm_figure.  Only mobile viewports
        # (< 900 px) shrink the figure; on desktop it stays natural so panel
        # drag-resize keeps scrolling a fixed-size plot (unchanged behavior).
        # Bucketed so the plot re-renders only when the layout actually changes.
        layout_width <- reactiveVal(NULL)
        observe({
            vw  <- viewport_width()
            # Floor the screen width at 350px: below that the x-axis labels would
            # overlap, so the plot stays at its 350px-fit size and the plot
            # wrapper's overflow:auto provides horizontal scroll instead.
            eff <- if (!is.null(vw) && !is.na(vw) && vw < 900)
                       min(natural_width, max(vw, 350) - 24)   # -24 for container padding
                   else natural_width
            bucket <- round(eff / 10) * 10
            if (!identical(bucket, isolate(layout_width()))) layout_width(bucket)
        })

        output$egm_plot <- renderPlotly({
            req(egm_data())
            aw <- layout_width()
            if (is.null(aw)) aw <- natural_width
            # isolate() reads the current toggle states without making renderPlotly
            # depend on them — toggle changes go through plotlyProxy, not re-renders.
            ts <- if (!is.null(toggle_states)) isolate(toggle_states()) else NULL
            create_egm_figure(egm_data(), plot_source_name, x_col, y_col, n_col, ts,
                              avail_width = aw)
        })

        # After any re-render (data change or responsive width change), tell
        # plot_interactions.js to re-attach its click/selection handlers.
        observeEvent(list(egm_data(), layout_width()), {
            req(egm_data())
            session$sendCustomMessage("triggerAttachPlotlyClickHandler", list(source = plot_source_name, ns = session$ns("")))
        })
    })
}
