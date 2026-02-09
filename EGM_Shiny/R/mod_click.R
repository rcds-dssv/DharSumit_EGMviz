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
                    # print(click_data$customdata)
                    clicked_x <- click_data$customdata[[1]][1]
                    clicked_y <- click_data$customdata[[1]][2]
                    trace_id <- click_data$customdata[[1]][3]

                    # update the plot colors
                    # Create color vector
                    colors <- rep("#1f77b4", nrow(egm_counts_list[[trace_id]]))
                    colors[click_data$pointNumber + 1] <- "#ff7f0e"

                    # Update the plot without re-rendering
                    plotlyProxy("egm_plot", session) %>%
                        plotlyProxyInvoke("restyle", list(marker.color = list(colors)))


                    # filter the dataframe to the papers that were in the clicked point
                    clicked_df <- df_list[[trace_id]] %>%
                        filter(.[[x_col]] == clicked_x & .[[y_col]] == clicked_y)

                    # and display as a table
                    DT::datatable(clicked_df, options = list(pageLength = 10))

                }
            })

        }
    )
}