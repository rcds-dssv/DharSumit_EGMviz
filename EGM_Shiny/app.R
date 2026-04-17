# global.R is sourced here so the app can also be launched via source("app.R")
# in addition to the standard shiny::runApp() workflow.
source("global.R")


# =============================================================================
# UI
# =============================================================================

ui <- fluidPage(

    tags$head(
        # styles_runtime.css is generated at startup by global.R
        tags$link(rel = "stylesheet", type = "text/css", href = "styles_runtime.css"),
        tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
        tags$script(src = "layout.js"),            # panel drag-resize and UI interaction
        tags$script(src = "plot_interactions.js")  # plot click/selection handlers
    ),

    # tags$h1(class = "header-title", "HEARING LITERATURE EVIDENCE GAP MAP"),

    # ── Help modal (see R/mod_help_modal.R) ─────────────────────────────────────
    help_modal_ui(),

    div(
        class = "design-container",

        # Header bar: title, description, and how-to button
        div(
            class = "header-instructions",
            div(
                class = "header-text",
                tags$h1("HEARING LITERATURE EVIDENCE GAP MAP"),
                tags$p("Explore hearing research papers plotted by study type and health outcome. Bubble size reflects the number of papers at each intersection."),
                tags$button(
                    class   = "how-to-use-btn",
                    onclick = "document.getElementById('egm-help-modal').classList.add('open')",
                    "Information and Instructions"
                )
            )
        ),

        # Always-visible controls toolbar: Filters grid on the left, Toggles column on the right
        div(
            class = "controls-toolbar",
            mod_filter_ui("egm")
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
                    class = "plot-section-header",
                    div(
                        class = "plot-section-header-top",
                        div(class = "plot-section-header-top-left", tags$h3("Evidence Gap Map")),
                        div(
                            class = "plot-section-header-top-right",
                            mod_deselect_ui("egm"),
                            tags$details(
                                class = "plot-config-details",
                                tags$summary("Plot configuration"),
                                mod_toggles_ui("egm")
                            )
                        )
                    ),
                    mod_plot_info_ui("egm")
                ),
                div(
                    class = "plot-wrapper",
                    id    = "plot_wrapper",
                    mod_plot_ui("egm")
                )
            ),

            # Draggable handle to resize plot / table columns
            div(class = "resize-handle", id = "resize_handle", div(class = "resize-handle-grip")),

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
                            mod_sort_ui("egm"),
                            mod_export_citations_ui("egm")
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
        x_col            = egm_definition$x_column,
        y_col            = egm_definition$y_column,
        n_col            = "n"
    )

    egm_selection <- mod_click_server(
        "egm",
        egm_data          = egm_data,
        reset_egm_trigger = reset_egm_trigger,
        plot_source_name  = "egm_scatter_plot",
        x_col             = egm_definition$x_column,
        y_col             = egm_definition$y_column
    )

    mod_filter_server(
        "egm",
        egm_data          = egm_data,
        reset_egm_trigger = reset_egm_trigger
    )

    mod_export_citations_server(
        "egm",
        clicked_df   = egm_selection$clicked_df,
        clicked_info = egm_selection$clicked_info
    )
}


shinyApp(ui, server)