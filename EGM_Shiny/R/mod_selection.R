# =============================================================================
# mod_selection — plot selection handling and paper table
#
# Listens for plotly click / lasso-select events, highlights the selected
# dots, and renders the matching papers in a table below the plot.
#
# Selection state is stored in the reactiveVal `clicked_info`, which is a
# list of point-info lists (one per selected dot).  Each point-info list has:
#   clicked_x   — x-axis label of the selected cell (e.g. "Intervention")
#   clicked_y   — y-axis label of the selected cell (e.g. "Quality of Life")
#   trace_id    — evidence category key matching egm_metadata (e.g. "high")
#   trace_index — 0-based plotly trace index (from egm_metadata)
#   pointNumber — 0-based index of the dot within its trace (from plotly)
#
# customdata embedded in each plotly marker is a list(x_label, y_label, trace_id),
# set by add_to_counts_df_for_plotly() in mod_plot.R.
#
# Public interface (UI functions):
#   mod_click_plot_header_ui(id)  — paper count + selection attribute tags
#   mod_click_plot_content_ui(id) — scrollable list of paper cards
#   mod_click_reset_ui(id)        — "Reset Plot Selection" button
#   mod_click_server(...)         — server logic
# =============================================================================


# =============================================================================
# Plot update helpers
# =============================================================================

# Updates every trace's marker colour, opacity, and line colour via a plotly
# proxy (no full re-render).
#
# When selected_info is NULL (reset): all dots are restored to full opacity.
# When selected_info is set:  selected dots get opacity 1 + white border;
#                             all other dots are dimmed to opacity 0.4.
update_plotly_colors_opacities <- function(session, egm_data, selected_info) {

    base_opacity <- if (is.null(selected_info)) 1 else 0.4

    for (name in names(egm_data)) {
        trace_idx <- egm_metadata[[name]]$index
        n_pts     <- nrow(egm_data[[name]]$counts)

        colors         <- rep(egm_metadata[[name]]$color, n_pts)
        line_colors    <- rep(egm_metadata[[name]]$color, n_pts)
        opacities      <- rep(base_opacity, n_pts)
        line_opacities <- rep(base_opacity, n_pts)

        # Highlight each selected dot that belongs to this trace
        if (!is.null(selected_info)) {
            for (pt in selected_info) {
                if (pt$trace_index == trace_idx) {
                    idx <- pt$pointNumber + 1  # plotly is 0-based; R is 1-based
                    line_colors[idx]    <- "white"
                    opacities[idx]      <- 1
                    line_opacities[idx] <- 1
                }
            }
        }

        restyle_args <- list(
            marker.color        = list(colors),
            marker.opacity      = list(opacities),
            marker.line.color   = list(line_colors),
            marker.line.opacity = list(line_opacities)
        )
        # On reset, also clear plotly's internal selection state (which would
        # otherwise keep non-selected points dimmed independently of our opacity)
        if (is.null(selected_info)) {
            restyle_args$selectedpoints <- list(NULL)
        }

        plotlyProxy("egm_plot", session) %>%
            plotlyProxyInvoke("restyle", restyle_args, list(trace_idx))
    }
}


# =============================================================================
# Selection parsing helpers
# =============================================================================

# Converts a single-click plotly event into a length-1 list of point-info
# lists, matching the format returned by create_plotly_selected_info().
create_plotly_click_info <- function(click_data) {
    if (is.null(click_data)) return(NULL)

    # customdata is a list(x_label, y_label, trace_id) set in mod_plot.R
    cd       <- click_data$customdata[[1]]
    trace_id <- cd[[3]]

    list(list(
        clicked_x   = cd[[1]],
        clicked_y   = cd[[2]],
        trace_id    = trace_id,
        trace_index = egm_metadata[[trace_id]]$index,
        pointNumber = click_data$pointNumber
    ))
}

# Converts a lasso / box-select plotly event (a dataframe, one row per
# selected dot) into a list of point-info lists.
create_plotly_selected_info <- function(selected_data) {
    # Guard against NULL or non-dataframe input (can occur when plotly fires
    # plotly_selected in response to a programmatic restyle call)
    if (is.null(selected_data) || !is.data.frame(selected_data) || nrow(selected_data) == 0) {
        return(NULL)
    }

    lapply(seq_len(nrow(selected_data)), function(i) {
        cd       <- selected_data$customdata[[i]]
        trace_id <- cd[[3]]
        list(
            clicked_x   = cd[[1]],
            clicked_y   = cd[[2]],
            trace_id    = trace_id,
            trace_index = egm_metadata[[trace_id]]$index,
            pointNumber = selected_data$pointNumber[i]
        )
    })
}


# =============================================================================
# Table HTML helpers
# =============================================================================

# Returns the rows from egm_data that correspond to all selected points.
# Rows from multiple traces at the same grid cell are de-duplicated.
create_plotly_click_df <- function(egm_data, selected_info, x_col, y_col) {
    if (is.null(selected_info)) return(NULL)

    dfs <- lapply(selected_info, function(pt) {
        egm_data[[pt$trace_id]]$df %>%
            dplyr::filter(.[[x_col]] == pt$clicked_x,
                          .[[y_col]] == pt$clicked_y)
    })
    dplyr::bind_rows(dfs) %>% dplyr::distinct()
}

# Renders the table header: paper count and one colour-coded tag per unique
# x-axis value, y-axis value, and evidence-category label in the selection.
create_table_header_html <- function(selected_info, df) {
    if (is.null(selected_info) || is.null(df) || nrow(df) == 0) {
        return(tags$p(class = "info", "Click on a point to display the papers"))
    }

    n        <- nrow(df)
    unique_x <- unique(sapply(selected_info, function(pt) pt$clicked_x))
    unique_y <- unique(sapply(selected_info, function(pt) pt$clicked_y))

    # Collect unique (trace_id, display_text) pairs, skipping the "all" trace
    # which has display_text = NULL and no dedicated colour tag
    trace_display_pairs <- unique(Filter(Negate(is.null), lapply(selected_info, function(pt) {
        dt <- egm_metadata[[pt$trace_id]]$display_text
        if (is.null(dt)) NULL else list(trace_id = pt$trace_id, display_text = dt)
    })))

    tagList(
        tags$p(paste("Number of papers:", n)),
        tags$div(
            tags$p("Selection attributes:"),
            tags$div(class = "paper-tags",
                lapply(unique_x, function(v) tags$span(class = "tag", v)),
                lapply(unique_y, function(v) tags$span(class = "tag", v)),
                # CSS class "tag high" / "tag medium" / etc. controls badge colour
                lapply(trace_display_pairs, function(td)
                    tags$span(class = paste("tag", td$trace_id), td$display_text))
            )
        )
    )
}

# Renders one card per paper row.  Columns in the `special` vector are handled
# separately as colour-coded tags rather than plain label-value pairs.
create_table_cards_html <- function(df) {
    if (is.null(df) || nrow(df) == 0) {
        return(div(class = "paper-list"))
    }

    # Columns shown as colour-coded tags rather than plain metadata rows
    special <- c("WorkType", "Theme.Assignment", "review_confidence", "in_progress")
    # Maps numeric review_confidence values (1/2/3) to labels
    conf    <- c("Low", "Medium", "High")

    cards <- lapply(seq_len(nrow(df)), function(i) {
        row <- df[i, , drop = FALSE]

        # TODO: replace with the actual title column once data is finalised
        title <- tags$h4("Paper Title Placeholder")

        # Render non-special, non-NA columns as "Label: Value" rows.
        # Column names are converted from CamelCase to "Camel Case" for display.
        meta <- lapply(names(row), function(col) {
            if (!is.na(row[[col]]) && !(col %in% special)) {
                div(class = "paper-meta",
                    span(class = "paper-card-label",
                         paste0(trimws(gsub("([A-Z])", " \\1", col)), ":")),
                    span(class = "paper-card-value", as.character(row[[col]]))
                )
            }
        })

        special_tags <- tags$div(class = "paper-tags",
            tags$span(class = "tag", row$WorkType),
            tags$span(class = "tag", row$Theme.Assignment),
            tags$span(class = paste("tag", tolower(conf[row$review_confidence])),
                      paste(conf[row$review_confidence], "Confidence")),
            if (row$in_progress > 0) tags$span(class = "tag ongoing", "In Progress")
        )

        div(class = "paper-card",
            div(class = "paper-card-contents", title, meta, special_tags))
    })

    div(class = "paper-list", cards)
}


# =============================================================================
# Shiny module
# =============================================================================

mod_click_plot_header_ui <- function(id) {
    ns <- NS(id)
    uiOutput(ns("table_header"))
}

mod_click_plot_content_ui <- function(id) {
    ns <- NS(id)
    uiOutput(ns("table_content"))
}

mod_click_reset_ui <- function(id) {
    ns <- NS(id)
    actionButton(ns("reset_plot"), "Reset Plot Selection", class = "reset-btn")
}

mod_click_server <- function(id, egm_data, reset_egm_trigger, plot_source_name, x_col, y_col) {
    moduleServer(id, function(input, output, session) {

        # Current selection: list of point-info lists, or NULL when nothing is selected
        clicked_info <- reactiveVal(NULL)

        # Single-point click
        observeEvent(event_data("plotly_click", source = plot_source_name), {
            clicked_info(
                create_plotly_click_info(event_data("plotly_click", source = plot_source_name))
            )
        })

        # Lasso / box multi-point selection
        observeEvent(event_data("plotly_selected", source = plot_source_name), {
            info <- create_plotly_selected_info(
                event_data("plotly_selected", source = plot_source_name)
            )
            if (!is.null(info)) clicked_info(info)
        })

        # Dataframe of papers matching the current selection
        clicked_df <- reactive({
            create_plotly_click_df(egm_data(), clicked_info(), x_col, y_col)
        })

        # The reset button increments reset_egm_trigger, which is also watched
        # by mod_filter_server so both the button and filter changes share the
        # same reset path.
        observeEvent(input$reset_plot, {
            reset_egm_trigger(reset_egm_trigger() + 1)
        })

        observeEvent(reset_egm_trigger(), {
            clicked_info(NULL)
            update_plotly_colors_opacities(session, egm_data(), NULL)
            # Clear the lasso / box selection shape drawn by plotly
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("relayout", list(selections = list()))
            # Tell plot_interactions.js to remove the arrow SVG
            session$sendCustomMessage("hideArrow", list())
        }, ignoreInit = TRUE)

        # Keep dot colours / opacities in sync with the current selection
        observe({
            update_plotly_colors_opacities(session, egm_data(), clicked_info())
        })

        output$table_header <- renderUI({
            create_table_header_html(clicked_info(), clicked_df())
        })

        output$table_content <- renderUI({
            create_table_cards_html(clicked_df())
        })
    })
}
