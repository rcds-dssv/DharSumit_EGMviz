# =============================================================================
# mod_toggles — plot layer visibility controls
#
# Sliding toggle switches control what is shown in the EGM.  Three switches
# are always present (Table, Heatmap, All Papers).  Confidence and In Progress
# switches are added only when the corresponding columns are defined in
# egm_definition (has_confidence / has_in_progress flags set in global.R).
#
# Table toggle:  sends a "toggleTable" JS message; toggles.js handles the
#                CSS class change + smooth Plotly resize animation.
# Data toggles:  plotlyProxy restyle calls update trace visibility immediately
#                without re-rendering the whole figure.  Trace indices are read
#                from egm_metadata so they stay correct regardless of which
#                optional categories are enabled.
# Filter change: create_egm_figure() reads the current toggle states via
#                isolate() so the re-rendered plot starts with correct visibility.
#
# Public interface:
#   mod_toggles_ui(id)          — switch widgets (conditional on egm_definition)
#   mod_toggles_server(id, ...) — message/proxy calls; returns reactive states
# =============================================================================


mod_toggles_ui <- function(id) {
    ns <- NS(id)

    mk <- function(input_id, label) {
        switchInput(ns(input_id), label = label, value = TRUE,
                    size = "mini", onStatus = "primary", offStatus = "default")
    }

    switches <- list(
        mk("show_table",   "Table"),
        mk("show_heatmap", "Heatmap"),
        mk("show_summary", "All Papers")
    )
    if (has_confidence)   switches <- c(switches, list(mk("show_confidence",  "Confidence")))
    if (has_in_progress)  switches <- c(switches, list(mk("show_in_progress", "In Progress")))

    div(class = "toggles-switches", switches)
}


mod_toggles_server <- function(id, egm_data) {
    moduleServer(id, function(input, output, session) {

        # ── Table toggle ──────────────────────────────────────────────────────
        observeEvent(input$show_table, {
            session$sendCustomMessage("toggleTable", list(show = input$show_table))
        }, ignoreInit = TRUE)

        # ── Data layer toggles ────────────────────────────────────────────────
        # Trace indices are read from egm_metadata (built dynamically in global.R)
        # so they remain correct whether or not optional categories are enabled.

        observeEvent(input$show_heatmap, {
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("restyle", list(visible = input$show_heatmap), list(0L))
        }, ignoreInit = TRUE)

        observeEvent(input$show_summary, {
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("restyle", list(visible = input$show_summary),
                                  list(egm_metadata$all$index))
        }, ignoreInit = TRUE)

        if (has_confidence) {
            observeEvent(input$show_confidence, {
                conf_indices <- lapply(c("high", "medium", "low"),
                                       function(n) egm_metadata[[n]]$index)
                plotlyProxy("egm_plot", session) %>%
                    plotlyProxyInvoke("restyle", list(visible = input$show_confidence),
                                      conf_indices)
            }, ignoreInit = TRUE)
        }

        if (has_in_progress) {
            observeEvent(input$show_in_progress, {
                plotlyProxy("egm_plot", session) %>%
                    plotlyProxyInvoke("restyle", list(visible = input$show_in_progress),
                                      list(egm_metadata$in_progress$index))
            }, ignoreInit = TRUE)
        }

        # Return the current toggle states as a reactive list.
        # mod_plot_server reads this (via isolate) when re-rendering after a
        # filter change, so the re-rendered plot starts with correct visibility.
        # confidence and in_progress default to NULL when the feature is disabled;
        # create_egm_figure() only reaches those branches if the traces exist.
        reactive(list(
            heatmap     = input$show_heatmap,
            summary     = input$show_summary,
            confidence  = if (has_confidence)   input$show_confidence  else NULL,
            in_progress = if (has_in_progress)  input$show_in_progress else NULL
        ))
    })
}