# app_config.R is sourced here so the app can also be launched via source("app.R")
# in addition to the standard shiny::runApp() workflow.
source("app_config.R")


# =============================================================================
# UI
# =============================================================================

ui <- fluidPage(

    tags$head(
        # Google material icons for bar chart icon
        tags$link(rel="stylesheet", href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0&icon_names=insert_chart,search"),
        # Inline script exposes EGM_DEFAULT_THEME before layout.js runs, so the
        # top-level theme IIFE in layout.js can read it before CSS is parsed,
        # preventing a flash of the wrong theme.
        tags$script(HTML(paste0("window.EGM_DEFAULT_THEME=\"", egm_definition$default_theme, "\""))),
        tags$script(src = "layout.js"),            # panel drag-resize and UI interaction
        tags$script(src = "plot_interactions.js"),  # plot click/selection handlers
        # styles_runtime.css is generated at startup by app_config.R
        tags$link(rel = "stylesheet", type = "text/css", href = "styles_runtime.css"),
        tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")
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
                class = "section-strip",
                tags$button(
                    class   = "section-collapse-btn",
                    onclick = "toggleSectionCollapse(this)",
                    title   = "Collapse / expand this section",
                    HTML("&#9652;")
                ),
                tags$span(class = "section-collapsed-title", "Instructions"),
                tags$button(
                    id      = "theme-toggle-btn",
                    class   = "theme-toggle-btn",
                    onclick = "toggleTheme()",
                    title   = "Toggle light / dark mode",
                    tags$span(class = "theme-icon theme-icon-light", HTML("&#9728;")),  # ☀
                    tags$span(class = "theme-icon theme-icon-dark",  HTML("&#9789;"))   # ☽
                )
            ),
            div(
                class = "section-main header-text",
                tags$h1(egm_definition$app_title),
                tags$span(egm_definition$app_description),
                tags$button(
                    class   = "how-to-use-btn",
                    onclick = "document.getElementById('egm-help-modal').classList.add('open')",
                    title   = "Open the help and instructions panel",
                    "Information and Instructions"
                )
            )
        ),

        # Always-visible controls toolbar: Filters grid on the left, Toggles column on the right
        div(
            class = "controls-toolbar",
            div(
                class = "section-strip",
                tags$button(
                    class   = "section-collapse-btn",
                    onclick = "toggleSectionCollapse(this)",
                    title   = "Collapse / expand this section",
                    HTML("&#9652;")
                ),
                tags$span(class = "section-collapsed-title", "Filters")
            ),
            div(
                class = "section-main",
                mod_filter_ui("egm")
            )
        ),

        # Search toolbar: collapsed by default; populated by mod_search_ui
        div(
            class = "search-toolbar section-collapsed",
            div(
                class = "section-strip",
                tags$button(
                    class   = "section-collapse-btn",
                    onclick = "toggleSectionCollapse(this)",
                    title   = "Collapse / expand this section",
                    HTML("&#9662;")
                ),
                tags$span(class = "section-collapsed-title", "Search")
            ),
            div(
                class = "section-main",
                mod_search_ui("egm")
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
                div(class = "panel-strip panel-strip-v", "Evidence Gap Map"),
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

                div(class = "panel-strip panel-strip-v", "Selected Papers and Comparison Plots"),

                # Papers sub-panel (top)
                div(
                    class = "papers-subpanel",
                    id    = "papers_subpanel",
                    div(class = "panel-strip panel-strip-h", "Selected Papers"),
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
                        mod_click_plot_header_ui("egm")
                    ),
                    mod_click_plot_content_ui("egm")
                ),

                # Draggable divider between papers and comparison plots
                div(class = "v-resize-handle", id = "v_resize_handle",
                    div(class = "v-resize-handle-grip")),

                # Comparison plots sub-panel (bottom)
                mod_comparison_plots_ui("egm")
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

    # Incremented by mod_click_server when a real plot selection is made while
    # search is active; mod_search_server observes it to clear the query.
    clear_search_trigger <- reactiveVal(0L)

    search_results <- mod_search_server(
        "egm",
        egm_data             = egm_data,
        clear_search_trigger = clear_search_trigger
    )

    # When all dot layers are hidden, clear any active selection so the paper
    # table doesn't show stale results with no visible dots to explain them.
    # notifyR = TRUE tells plot_interactions.js to also fire plotly_deselect_trigger
    # so mod_click_server clears clicked_info on the R side.
    observeEvent(toggle_states()$any_dots_visible, {
        if (!isTRUE(toggle_states()$any_dots_visible)) {
            session$sendCustomMessage("clearPlotlySelection",
                list(plotId = NS("egm")("egm_plot"), notifyR = TRUE))
        }
    }, ignoreInit = TRUE)

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
        egm_data             = egm_data,
        reset_egm_trigger    = reset_egm_trigger,
        plot_source_name     = "egm_scatter_plot",
        x_col                = egm_definition$x_column,
        y_col                = egm_definition$y_column,
        any_dots_visible     = reactive(toggle_states()$any_dots_visible),
        search_results       = search_results,
        clear_search_trigger = clear_search_trigger
    )

    # When search is active, replace egm_data$all$df with search results so
    # build_labeled_data() in mod_comparison_plots.R fetches only matched papers.
    comparison_egm_data <- reactive({
        if (isTRUE(search_results$active()) && !is.null(search_results$df())) {
            modified     <- egm_data()
            modified$all <- list(df = search_results$df(), counts = egm_data()$all$counts)
            modified
        } else {
            egm_data()
        }
    })

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

    mod_comparison_plots_server(
        "egm",
        clicked_info = egm_selection$clicked_info,
        egm_data     = comparison_egm_data
    )
}


shinyApp(ui, server)