source("global.R")

# ─── UI ──────────────────────────────────────────────────────────────────────

ui <- fluidPage(

    tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "colors_runtime.css"),
        tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
        tags$script(src = "toggles.js"),
        tags$script(src = "plot_interactions.js")
    ),

    # Title
    tags$h1(
        class = "header-title",
        "HEARING LITERATURE EVIDENCE GAP MAP"
    ),

    div(
        class = "design-container",

        # Instructions bar
        div(
            class = "header-instructions",
            tags$h2("Instructions and Information"),
            tags$p("Text can be included here")
        ),

        # Control bar
        div(
            class = "controls-bar",

            div(
                class = "filters",
                tags$h3("Filters"),
                mod_filter_ui("egm")
            ),

            div(
                class = "toggles",
                tags$h3("Toggles"),
                div(
                    class = "toggles-group",
                    # this button toggles the table on/off; logic is in toggles.js
                    actionButton("toggle_table", "Table", class = "toggle-btn active")
                )
            )
        ),

        # Figure and table side-by-side
        div(
            class = "main-area",
            id    = "main_area",

            # Plot (left)
            div(
                class = "plot-section",
                id    = "plot_section",

                div(
                    class = "plot-header",
                    tags$h2("Evidence Gap Map"),
                    mod_click_reset_ui("egm")
                ),

                div(
                    class = "plot-wrapper",
                    id    = "plot_wrapper",
                    mod_plot_ui("egm")
                )
            ),

            # Table (right)
            div(
                class = "table-section",
                id    = "table_section",

                div(
                    class = "table-header",
                    div(
                        class = "table-header-top",
                        div(class = "table-header-top-left",  tags$h3("Selected papers")),
                        div(class = "table-header-top-right", mod_export_citations_ui("egm"))
                    ),
                    mod_click_plot_header_ui("egm")
                ),

                mod_click_plot_content_ui("egm")
            )
        )
    )
)


# ─── Server ──────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

    egm_data         <- reactiveVal(initial_egm_data)
    reset_egm_trigger <- reactiveVal(0)

    mod_plot_server(
        "egm",
        egm_data         = egm_data,
        plot_source_name = "egm_scatter_plot",
        x_col            = "WorkType",
        y_col            = "Theme.Assignment",
        n_col            = "n"
    )

    mod_click_server(
        "egm",
        egm_data         = egm_data,
        reset_egm_trigger = reset_egm_trigger,
        plot_source_name = "egm_scatter_plot",
        x_col            = "WorkType",
        y_col            = "Theme.Assignment"
    )

    mod_filter_server(
        "egm",
        egm_data          = egm_data,
        reset_egm_trigger = reset_egm_trigger
    )

    mod_export_citations_server("egm")
}


shinyApp(ui, server)
