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
                  
                    # update the plot colors
                    # Create color vector
                    colors <- rep("#1f77b4", nrow(batch3_egm_counts))
                    colors[click_data$pointNumber + 1] <- "#ff7f0e"
                    
                    # Update the plot without re-rendering
                    plotlyProxy("egm_plot", session) %>%
                      plotlyProxyInvoke("restyle", list(marker.color = list(colors)))
                  
                  
                    # filter the dataframe to the papers that were in the clicked point
                    clicked_df <- batch3_df %>%
                        filter(.[[x_col]] == click_data$x & .[[y_col]] == click_data$y)
                    
                    # and display as a table
                    DT::datatable(clicked_df, options = list(pageLength = 10))
                    

     
                   
                }
            })

        }
    )
}