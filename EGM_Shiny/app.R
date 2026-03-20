# global.R is sourced here so the app can also be launched via source("app.R")
# in addition to the standard shiny::runApp() workflow.
source("global.R")


# =============================================================================
# UI
# =============================================================================

ui <- fluidPage(

    tags$head(
        # colors_runtime.css is generated at startup by global.R from the colors list
        tags$link(rel = "stylesheet", type = "text/css", href = "colors_runtime.css"),
        tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
        tags$script(src = "toggles.js"),           # show/hide toggles
        tags$script(src = "plot_interactions.js")  # plot click/selection arrows
    ),

    # tags$h1(class = "header-title", "HEARING LITERATURE EVIDENCE GAP MAP"),

    # ── Help modal (see R/mod_help_modal.R) ─────────────────────────────────────
    help_modal_ui(),

    div(
        class = "design-container",

        # Header bar: instructions text on the left, Filters + Toggles buttons on the right
        div(
            class = "header-instructions",
            div(
                class = "header-text",
                tags$h1("HEARING LITERATURE EVIDENCE GAP MAP"),
                tags$p("Explore hearing research papers plotted by study type and health outcome. Bubble size reflects the number of papers at each intersection."),
                tags$button(
                    class   = "how-to-use-btn",
                    onclick = "document.getElementById('egm-help-modal').classList.add('open')",
                    "Instructions"
                )
            ),
            div(class = "header-divider"),
            div(
                class = "header-controls",
                mod_filter_ui("egm"),   # Filters dropdown
                tags$details(
                    class = "toggles-details dropdown-details",
                    tags$summary("Toggles"),
                    mod_toggles_ui("egm")
                )
            )
        ),

        # Main area: plot on the left, paper table on the right
        div(
            class = "main-area",
            id    = "main_area",

            # ── Plot panel ────────────────────────────────────────────────
            div(
                class = "plot-section",
                id    = "plot_section",
                div(
                    class = "plot-wrapper",
                    id    = "plot_wrapper",
                    mod_plot_ui("egm")
                )
            ),

            # ── Table panel ───────────────────────────────────────────────
            div(
                class = "table-section",
                id    = "table_section",
                div(
                    class = "table-header",
                    div(
                        class = "table-header-top",
                        div(class = "table-header-top-left",  tags$h3("Selected papers")),
                        div(class = "table-header-top-right",
                            mod_export_citations_ui("egm")     # "Export"
                        )
                    ),
                    mod_click_plot_header_ui("egm")   # paper count + selection tags
                ),
                mod_click_plot_content_ui("egm")      # scrollable list of paper cards
            )
        )
    )
)


# =============================================================================
# Server
# =============================================================================

server <- function(input, output, session) {

    # egm_data holds the currently filtered dataset (a named list of dataframes,
    # one per evidence category). It is updated by the filter module.
    egm_data <- reactiveVal(initial_egm_data)

    # Incrementing this value triggers a full plot re-render and clears the
    # paper table.  Currently only driven by filter changes.
    reset_egm_trigger <- reactiveVal(0)

    toggle_states <- mod_toggles_server("egm", egm_data = egm_data)

    mod_plot_server(
        "egm",
        egm_data         = egm_data,
        toggle_states    = toggle_states,
        plot_source_name = "egm_scatter_plot",
        x_col            = "WorkType",
        y_col            = "Theme.Assignment",
        n_col            = "n"
    )

    mod_click_server(
        "egm",
        egm_data          = egm_data,
        reset_egm_trigger = reset_egm_trigger,
        plot_source_name  = "egm_scatter_plot",
        x_col             = "WorkType",
        y_col             = "Theme.Assignment"
    )

    mod_filter_server(
        "egm",
        egm_data          = egm_data,
        reset_egm_trigger = reset_egm_trigger
    )

    mod_export_citations_server("egm")
}


shinyApp(ui, server)