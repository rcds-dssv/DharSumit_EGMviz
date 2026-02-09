source("global.R")

ui <- fluidPage(
  tags$head(
    tags$link(
      rel = "stylesheet",
      type = "text/css",
      href = "styles.css"
    )
  ),
  
  titlePanel("EGM Skeleton"),
  
    # Filters at the top
    fluidRow(
      column(3, selectInput("filter1", "filter 1:", choices = c("Option 1", "Option 2"))),
      column(3, selectInput("filter2", "filter 2:", choices = c("Option A", "Option B"))),
      column(3, selectInput("filter3", "filter 3:", choices = c("Option 1A", "Option 1B"))),
      column(3, selectInput("filter4", "filter 4:", choices = c("Option 2A", "Option 2B"))),
    ),
  
    hr(),
    
    # Figure and table side-by-side
    fluidRow(
      column(6,
        h4("EGM Figure:"),
        div(mod_plot_ui("egm"), style = "overflow: auto")
      ),
      column(6,
        h4("Clicked Point Info:"),
        div(mod_click_ui("egm"), style = "overflow: auto")
      )
    )


)

server <- function(input, output, session) {
  
    # server module for the plot
    mod_plot_server(
        "egm", 
        plot_source_name = "egm_scatter_plot",
        x_col = "WorkType", 
        y_col = "Theme.Assignment", 
        n_col = "n"
      )
  
    # server module to handle clicks on the plot and display the table
    mod_click_server(
        "egm", 
        plot_source_name = "egm_scatter_plot",
        x_col = "WorkType", 
        y_col = "Theme.Assignment"
    )
}

shinyApp(ui, server)