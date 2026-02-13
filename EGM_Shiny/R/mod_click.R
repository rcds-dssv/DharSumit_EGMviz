update_plotly_colors <- function(session, colors, line_colors, trace_index){
    # Update the plot without re-rendering
    plotlyProxy("egm_plot", session) %>%
        plotlyProxyInvoke("restyle", list(
            marker.color = list(colors),
            marker.line.color = list(line_colors)
        ),
        list(trace_index)
    )
}

update_plotly_opacities <- function(session, opacities, line_opacities, trace_index){
    # Update the plot without re-rendering
    plotlyProxy("egm_plot", session) %>%
        plotlyProxyInvoke("restyle", list(
            marker.opacity = list(opacities),
            marker.line.opacity = list(line_opacities)
        ),
        list(trace_index)
    )
}
###### modular ui and server functions
mod_click_ui <- function(id, header_only = FALSE) {
    ns <- NS(id)
    if (header_only) {
        uiOutput(ns("table_count"))
    } else {
        uiOutput(ns("click_cards"))
    }
}

mod_click_server <- function(id, plot_source_name, x_col, y_col) {
    moduleServer(
        id,
        function(input, output, session) {
            # Capture click events from the plotly figure and save the info
            clicked_info <- reactive({
                click_data <- event_data("plotly_click", source = plot_source_name)
                if (is.null(click_data)) return(NULL)

                clicked_x <- click_data$customdata[[1]][1]
                clicked_y <- click_data$customdata[[1]][2]
                trace_id  <- click_data$customdata[[1]][3]
                trace_index <- egm_data[[trace_id]]$index

                # print(trace_index)
                # print(click_data$customdata)

                list(
                    clicked_x = clicked_x,
                    clicked_y = clicked_y,
                    trace_id = trace_id,
                    trace_index = trace_index,
                    pointNumber = click_data$pointNumber
                )
            })

            # create a dataframe with the papers in the clicked point
            clicked_df <- reactive({
                info <- clicked_info()
                if (is.null(info)) return(NULL)
                egm_data[[info$trace_id]]$df %>%
                    dplyr::filter(
                        .[[x_col]] == info$clicked_x,
                        .[[y_col]] == info$clicked_y
                    )
            })

            # update the plot colors
            observe({
                info <- clicked_info()
                if (is.null(info)) return()

                # Create the original color vectors but replace the clicked point with black
                for (name in names(egm_data)) {
                    trace_idx <- egm_data[[name]]$index
                    colors <- rep(egm_data[[name]]$color, nrow(egm_data[[name]]$counts))
                    line_colors <- rep(egm_data[[name]]$color, nrow(egm_data[[name]]$counts))
                    opacities <- rep(0.4, nrow(egm_data[[name]]$counts))
                    line_opacities <- rep(0.4, nrow(egm_data[[name]]$counts))
                    if (trace_idx == info$trace_index) {
                        line_colors[info$pointNumber + 1] <- "white"
                        opacities[info$pointNumber + 1] <- 1;
                        line_opacities[info$pointNumber + 1] <- 1;
                    }
                    update_plotly_colors(session, colors, line_colors, trace_idx)
                    update_plotly_opacities(session, opacities, line_opacities, trace_idx)
                }
            })

            # Count
            output$table_count <- renderUI({
                info <- clicked_info()
                df  <- clicked_df()

                # Placeholder before first click
                if (is.null(info) || is.null(df) || nrow(df) == 0) {
                    return(tags$p(class="info", "Click on a point to display the papers"))
                }

                # Now info and df exist
                n <- nrow(df)
                display_text <- egm_data[[info$trace_id]]$display_text
                special <- 
                tagList(
                    tags$p(paste("Number of papers:", n)),
                    tags$div(class = "paper-tags",
                        tags$span(class = "tag", info$clicked_x),
                        tags$span(class = "tag", info$clicked_y),
                        if (!is.null(display_text)) tags$span(class = paste("tag", info$trace_id), display_text)
                    )
                )

            })


            # Paper cards
            output$click_cards <- renderUI({
                df <- clicked_df()
                if (is.null(df)) return()

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

                div(class = "paper-list", cards)
            })

        }
    )
}