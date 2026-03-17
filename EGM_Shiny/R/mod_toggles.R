# =============================================================================
# mod_toggles — plot layer visibility controls
#
# Five sliding toggle switches control what is shown in the EGM:
#   Table        — shows/hides the paper table panel (layout toggle)
#   Heatmap      — the gray cell-count heatmap (trace 0)
#   All Papers   — the blue "all papers" dots   (trace 1)
#   Confidence   — the green/yellow/red dots    (traces 2–4)
#   In Progress  — the pink dots                (trace 5)
#
# Table toggle:  sends a "toggleTable" JS message; toggle_table.js does the
#                CSS class change + smooth Plotly resize animation.
# Data toggles:  plotlyProxy restyle calls update trace visibility immediately
#                without re-rendering the whole figure.
# Filter change: create_egm_figure() reads the current toggle states via
#                isolate() so the re-rendered plot starts with correct visibility.
#
# Public interface:
#   mod_toggles_ui(id)          — Table switch (full-width) + 2×2 data grid
#   mod_toggles_server(id, ...) — message/proxy calls; returns reactive states
# =============================================================================


mod_toggles_ui <- function(id) {
    ns <- NS(id)
    div(
        class = "toggles-switches",
        switchInput(ns("show_table"),      label = "Table",       value = TRUE, size = "mini", onStatus = "primary", offStatus = "default"),
        switchInput(ns("show_heatmap"),    label = "Heatmap",     value = TRUE, size = "mini", onStatus = "primary", offStatus = "default"),
        switchInput(ns("show_summary"),    label = "All Papers",  value = TRUE, size = "mini", onStatus = "primary", offStatus = "default"),
        switchInput(ns("show_confidence"), label = "Confidence",  value = TRUE, size = "mini", onStatus = "primary", offStatus = "default"),
        switchInput(ns("show_progress"),   label = "In Progress", value = TRUE, size = "mini", onStatus = "primary", offStatus = "default")
    )
}


mod_toggles_server <- function(id, egm_data) {
    moduleServer(id, function(input, output, session) {

        # ── Table toggle ──────────────────────────────────────────────────────
        # Sends a message to toggle_table.js which handles the CSS class change
        # and the smooth Plotly resize animation.
        observeEvent(input$show_table, {
            session$sendCustomMessage("toggleTable", list(show = input$show_table))
        }, ignoreInit = TRUE)

        # ── Data layer toggles ────────────────────────────────────────────────
        # Each observeEvent fires when the user flips a switch.
        # plotlyProxy updates only the `visible` property of the relevant
        # trace(s) without triggering a full plot re-render.
        #
        # Trace index reference (matches egm_metadata in global.R):
        #   0 = heatmap, 1 = all, 2 = high, 3 = medium, 4 = low, 5 = ongoing

        observeEvent(input$show_heatmap, {
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("restyle", list(visible = input$show_heatmap), list(0))
        }, ignoreInit = TRUE)

        observeEvent(input$show_summary, {
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("restyle", list(visible = input$show_summary), list(1))
        }, ignoreInit = TRUE)

        observeEvent(input$show_confidence, {
            # Three traces share the confidence toggle (high / medium / low)
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("restyle", list(visible = input$show_confidence), list(2, 3, 4))
        }, ignoreInit = TRUE)

        observeEvent(input$show_progress, {
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("restyle", list(visible = input$show_progress), list(5))
        }, ignoreInit = TRUE)

        # Return the current toggle states as a reactive list.
        # mod_plot_server reads this (via isolate) when re-rendering after a
        # filter change, so the re-rendered plot starts with correct visibility.
        reactive(list(
            heatmap     = input$show_heatmap,
            summary     = input$show_summary,
            confidence  = input$show_confidence,
            in_progress = input$show_progress
        ))
    })
}