source("global.R")

ui <- fluidPage(
    
    # include the style sheet
    tags$head(
        tags$link(
            rel = "stylesheet",
            type = "text/css",
            href = "styles_design1.css"
        )
    ),
  
    # title
    tags$h1(
        class="header-title",
        "HEARING LITERATURE EVIDENCE GAP MAP"
    ),

    div(
        class="design-container",

        # instructions bar
        div(
            class="header-instructions",
            tags$h2("Instructions and Information"),
            tags$p("Text can be included here")
        ),

        # Control bar at the top
        div(
            class = "controls-bar",

            # filters
            div(
                class = "filters",
                tags$h3("Filters"),

                div(
                    class = "filters-group",
                    div(
                        class = "filters-item",
                        tags$label("Filter 1:"),
                        selectInput("filter1", label = NULL, choices = c("Option 1", "Option 2"))
                    ),
                    div(
                        class = "filters-item",
                        tags$label("Filter 2:"),
                        selectInput("filter2", label = NULL, choices = c("Option A", "Option B"))
                    ),
                    div(
                        class = "filters-item",
                        tags$label("Filter 3:"),
                        selectInput("filter3", label = NULL, choices = c("Option 1A", "Option 1B"))
                    ),
                    div(
                        class = "filters-item",
                        tags$label("Filter 4:"),
                        selectInput("filter4", label = NULL, choices = c("Option 2A", "Option 2B"))
                    ),
                ),
            ),

            # View toggle buttons on the right
            div(
                class = "toggles",
                tags$h3("Toggles"),
                div(
                    class = "toggles-group",
            
                    actionButton("toggle_1", "Toggle 1", class = "toggle-btn active"),
                    actionButton("toggle_2", "Toggle 2", class = "toggle-btn active"),
                    actionButton("toggle_table", "Table →", class = "toggle-btn active")
                ),
            )
        ),
        
        # Figure and table side-by-side
        div(
            class = "main-area",  
            id = "main_area",

            # figure (left)
            div(
                class = "plot-section",

                # plot header
                div(
                    class = "plot-header",
                    tags$h2("Evidence Gap Map"),
                    actionButton("expand_plot", "⛶ Fullscreen", class = "expand-btn")
                ),

                # plot 
                div(
                    class = "plot-wrapper",
                    mod_plot_ui("egm")
                )
            ),

            # table (right)
            div(
                class = "table-section",
                id = "table_section",

                # Table header (sticky)
                div(
                    class = "table-header",
                    tags$h3("Selected papers"),
                    mod_click_ui("egm", header_only = TRUE)
                ),
                
                # Paper list
                mod_click_ui("egm")
                
            )
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