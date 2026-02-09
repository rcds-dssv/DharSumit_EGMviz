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

###### modular ui and server functions
mod_click_ui <- function(id) {
  ns <- NS(id)
  DT::dataTableOutput(ns("click_table"))
}

mod_click_server <- function(id, plot_source_name, x_col, y_col) {
    moduleServer(
        id,
        function(input, output, session) {
            # Capture click events from the plotly figure
            output$click_table <-  DT::renderDataTable({
                # Access click data using event_data with the source name
                click_data <- event_data("plotly_click", source = plot_source_name)

                validate(
                  need(click_data, "Click on a point to see its data")
                )

                if (!is.null(click_data)) {
                    # get the clicked data
                    clicked_x <- click_data$customdata[[1]][1]
                    clicked_y <- click_data$customdata[[1]][2]
                    trace_id <- click_data$customdata[[1]][3]
                    trace_index <- egm_data[[trace_id]]$index

                    # print(click_data$customdata)
                    # print(trace_index)

                    # update the plot colors
                    # Create the original color vectors but replace the clicked point with black
                    for (name in names(egm_data)) {
                        trace_idx <- egm_data[[name]]$index
                        colors <- rep(egm_data[[name]]$color, nrow(egm_data[[name]]$counts))
                        line_colors <- rep(egm_data[[name]]$color, nrow(egm_data[[name]]$counts))
                        if (trace_idx == trace_index) line_colors[click_data$pointNumber + 1] <- "black"
                        update_plotly_colors(session, colors, line_colors, trace_idx)
                    }

                    # filter the dataframe to the papers that were in the clicked point
                    clicked_df <- egm_data[[trace_id]]$df %>%
                        filter(.[[x_col]] == clicked_x & .[[y_col]] == clicked_y)

                    # and display as a table
                    DT::datatable(clicked_df, options = list(pageLength = 10))

                }
            })

        }
    )
}