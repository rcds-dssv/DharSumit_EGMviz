update_plotly_colors_opacities <- function(session, egm_data, selected_info){
    # Create the original color vectors but replace the selected points (if not null)

    if (is.null(selected_info)){
        #for plot reset
        opacity <- 1.
    } else {
        # for emphasizing the selected points (which will have opacity = 1)
        opacity <- 0.4
    }

    for (name in names(egm_data)) {
        trace_idx      <- egm_metadata[[name]]$index
        n_pts          <- nrow(egm_data[[name]]$counts)
        colors         <- rep(egm_metadata[[name]]$color, n_pts)
        line_colors    <- rep(egm_metadata[[name]]$color, n_pts)
        opacities      <- rep(opacity, n_pts)
        line_opacities <- rep(opacity, n_pts)

        # highlight each selected point that belongs to this trace
        if (!is.null(selected_info)) {
            for (pt in selected_info) {
                if (pt$trace_index == trace_idx) {
                    idx <- pt$pointNumber + 1   # R is 1-indexed
                    line_colors[idx]    <- "white"
                    opacities[idx]      <- 1
                    line_opacities[idx] <- 1
                }
            }
        }

        # Update the plot without re-rendering
        plotlyProxy("egm_plot", session) %>%
            plotlyProxyInvoke("restyle", list(
                marker.color        = list(colors),
                marker.opacity      = list(opacities),
                marker.line.color   = list(line_colors),
                marker.line.opacity = list(line_opacities)
            ),
            list(trace_idx)
        )
    }
}

create_plotly_click_info <- function(click_data) {
    # Returns a list containing a single point-info list (consistent with the
    # multi-point format used by create_plotly_selected_info).
    if (is.null(click_data)) return(NULL)

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

create_plotly_selected_info <- function(selected_data) {
    # Returns a list of point-info lists, one per selected point.
    if (is.null(selected_data) || nrow(selected_data) == 0) return(NULL)

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

create_plotly_click_df <- function(egm_data, selected_info, x_col, y_col) {
    if (is.null(selected_info)) return(NULL)

    dfs <- lapply(selected_info, function(pt) {
        egm_data[[pt$trace_id]]$df %>%
            dplyr::filter(
                .[[x_col]] == pt$clicked_x,
                .[[y_col]] == pt$clicked_y
            )
    })
    dplyr::bind_rows(dfs) %>% dplyr::distinct()
}

create_table_header_html <- function(selected_info, df) {
    # generate the table header (number of papers and tags for each selected point)

    # Placeholder before first click/selection
    if (is.null(selected_info) || is.null(df) || nrow(df) == 0) {
        return(tags$p(class="info", "Click on a point to display the papers"))
    }

    n <- nrow(df)

    unique_x            <- unique(sapply(selected_info, function(pt) pt$clicked_x))
    unique_y            <- unique(sapply(selected_info, function(pt) pt$clicked_y))
    # collect unique (trace_id, display_text) pairs, skipping traces with no label ("all")
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
                lapply(trace_display_pairs, function(td)
                    tags$span(class = paste("tag", td$trace_id), td$display_text))
            )
        )
    )
}

create_table_cards_html = function(df){
    # generate the cards (1 for each paper in the dataframe)

    if (is.null(df) || nrow(df) == 0) {
        # if the dataframe is empty, return an empty div
        return(div(class = "paper-list"))
    }
    # there may be a more elegant way to handle these special values
    special <- c("WorkType", "Theme.Assignment", "review_confidence", "in_progress")
    conf <- c("Low", "Medium", "High")

    cards <- lapply(seq_len(nrow(df)), function(i) {
        row <- df[i, , drop = FALSE]

        title <- tags$h4(paste("Paper Title Placeholder"))

        meta <- lapply(names(row), function(col) {
            if (!is.na(row[[col]]) && !(col %in% special)) {
                div(class = "paper-meta",
                    span(class = "paper-card-label", paste0(trimws(gsub("([A-Z])", " \\1", col)), ":")),
                    span(class = "paper-card-value", as.character(row[[col]]))
                )
            }
        })
        special_tags <- tags$div(class = "paper-tags",
            tags$span(class = "tag", row$WorkType),
            tags$span(class = "tag", row$Theme.Assignment),
            tags$span(class=paste("tag", tolower(conf[row$review_confidence])), paste(conf[row$review_confidence], "Confidence")),
            if (row$in_progress > 0) tags$span(class = "tag ongoing", "In Progress")
        )

        div(class = "paper-card",
            div(class = "paper-card-contents",
                title,
                meta,
                special_tags
            )
        )
    })

    return(div(class = "paper-list", cards))
}

###### modular ui and server functions
mod_click_plot_header_ui <- function(id) {
    ns <- NS(id)
    uiOutput(ns("table_header"))
}
mod_click_plot_content_ui <- function(id) {
    ns <- NS(id)
    uiOutput(ns("table_content"))
}
mod_click_reset_ui <- function(id, header_only = FALSE) {
    ns <- NS(id)
    actionButton(ns("reset_plot"), "Reset Plot Selection", class = "reset-btn")
}

mod_click_server <- function(id, egm_data, reset_egm_trigger, plot_source_name, x_col, y_col) {
    moduleServer(id, function(input, output, session) {

        # Holds the current selection as a list of point-info lists; NULL = no selection
        clicked_info <- reactiveVal(NULL)

        # Single point click
        observeEvent(event_data("plotly_click", source = plot_source_name), {
            clicked_info(
                create_plotly_click_info(event_data("plotly_click", source = plot_source_name))
            )
        })

        # Lasso / box selection (multiple points)
        observeEvent(event_data("plotly_selected", source = plot_source_name), {
            info <- create_plotly_selected_info(
                event_data("plotly_selected", source = plot_source_name)
            )
            if (!is.null(info)) clicked_info(info)
        })

        # create a dataframe with the papers in the selected points
        clicked_df <- reactive({
            create_plotly_click_df(egm_data(), clicked_info(), x_col, y_col)
        })

        # reset the table and plot colors when the user clicks the reset button
        observeEvent(input$reset_plot, {
            reset_egm_trigger(reset_egm_trigger() + 1)
        })
        observeEvent(reset_egm_trigger(), {
            clicked_info(NULL)
            session$sendCustomMessage("hideArrow", list())
        }, ignoreInit = TRUE)

        # update the plot colors and opacities
        observe({
            update_plotly_colors_opacities(session, egm_data(), clicked_info())
        })

        # table header (N papers, tags)
        output$table_header <- renderUI({
            create_table_header_html(clicked_info(), clicked_df())
        })

        # table content (paper cards)
        output$table_content <- renderUI({
            create_table_cards_html(clicked_df())
        })

    })
}
