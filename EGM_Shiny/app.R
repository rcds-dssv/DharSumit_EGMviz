source("global.R")

ui <- fluidPage(
    
    # include the style sheet
    tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "colors_base.css"),
        tags$link(rel = "stylesheet", type = "text/css", href = "colors_runtime.css"),
        tags$link(rel = "stylesheet", type = "text/css", href = "styles_design1.css"),
        tags$script(src="toggles.js"),
        tags$script(src="plot_clicks.js")
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
                mod_filter_ui("egm"),
            ),

            # View toggle buttons on the right
            div(
                class = "toggles",
                tags$h3("Toggles"),
                div(
                    class = "toggles-group",
            
                    # actionButton("toggle_1", "Toggle 1", class = "toggle-btn active"),
                    # actionButton("toggle_2", "Toggle 2", class = "toggle-btn active"),
                    # this button toggles the table on/off and is controlled in javascript within toggles.js
                    actionButton("toggle_table", "Table", class = "toggle-btn active")
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
                id = "plot_section",

                # plot header
                div(
                    class = "plot-header",
                    tags$h2("Evidence Gap Map"),
                    mod_click_reset_ui("egm")
                ),

                # plot 
                div(
                    class = "plot-wrapper",
                    id = "plot_wrapper",
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
                    div(
                        class = "table-header-top",
                        div(
                            class = "table-header-top-left",
                            tags$h3("Selected papers")
                        ),
                        div(
                            class = "table-header-top-right",
                            mod_export_citations_ui("egm")
                        ),
                    ),
                    mod_click_plot_header_ui("egm"),
                ),
                
                # Paper list
                mod_click_plot_content_ui("egm")
                
            )
        )
    )
)

server <- function(input, output, session) {
  
    # initialize the reactiveVal for the data set
    egm_data <- reactiveVal(initial_egm_data)

    # initialize the reactiveVal to trigger a reste of the plot and table
    reset_egm_trigger <- reactiveVal(0)

    # server module for the plot
    mod_plot_server(
        "egm", 
        egm_data = egm_data,
        plot_source_name = "egm_scatter_plot",
        x_col = "WorkType", 
        y_col = "Theme.Assignment", 
        n_col = "n"
      )
  
    # server module to handle clicks on the plot and display the table
    mod_click_server(
        "egm", 
        egm_data = egm_data,
        reset_egm_trigger = reset_egm_trigger,
        plot_source_name = "egm_scatter_plot",
        x_col = "WorkType", 
        y_col = "Theme.Assignment"
    )

    # server module to handle the filters
    mod_filter_server(
        "egm",
        egm_data = egm_data,
        reset_egm_trigger = reset_egm_trigger
    )

    # server module to handle the citation exporter
    mod_export_citations_server(
        "egm"
    )
}

shinyApp(ui, server)