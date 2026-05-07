# =============================================================================
# mod_toggles — plot layer visibility controls
#
# Sliding toggle switches control what is shown in the EGM.  Three switches
# are always present (Table, Heatmap, Summary).  Confidence and In Progress
# switches are added only when the corresponding columns are defined in
# egm_definition (has_confidence / has_in_progress flags set in app_config.R).
#
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
        mk("show_heatmap", "Heatmap"),
        mk("show_summary", "Summary Dots")
    )
    if (has_confidence)   switches <- c(switches, list(mk("show_confidence",  "Confidence Dots")))
    if (has_in_progress)  switches <- c(switches, list(mk("show_in_progress", "In Progress Dots")))

    div(class = "toggles-switches", switches, uiOutput(ns("dots_notice")))
}


mod_toggles_server <- function(id, egm_data) {
    moduleServer(id, function(input, output, session) {

        # TRUE when at least one dot trace (summary / confidence / in_progress) is
        # visible.  Used to switch plotly dragmode and show the selection notice.
        compute_any_dots_visible <- function() {
            isTRUE(input$show_summary) ||
            (has_confidence  && isTRUE(input$show_confidence)) ||
            (has_in_progress && isTRUE(input$show_in_progress))
        }

        # Switch plotly dragmode to match dot visibility: "select" when any dot
        # layer is on, "pan" when all are off (selection is meaningless on the
        # heatmap alone).
        update_dragmode <- function() {
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("relayout",
                    list(dragmode = if (compute_any_dots_visible()) "select" else "pan"))
        }

        # ── Data layer toggles ────────────────────────────────────────────────
        # Trace indices are read from egm_metadata (built dynamically in app_config.R)
        # so they remain correct whether or not optional categories are enabled.

        observeEvent(input$show_heatmap, {
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("restyle", list(visible = input$show_heatmap), list(0L))
        }, ignoreInit = TRUE)

        observeEvent(input$show_summary, {
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("restyle", list(visible = input$show_summary),
                                  list(egm_metadata$all$index))
            update_dragmode()
        }, ignoreInit = TRUE)

        if (has_confidence) {
            observeEvent(input$show_confidence, {
                conf_indices <- lapply(c("high", "medium", "low"),
                                       function(n) egm_metadata[[n]]$index)
                plotlyProxy("egm_plot", session) %>%
                    plotlyProxyInvoke("restyle", list(visible = input$show_confidence),
                                      conf_indices)
                update_dragmode()
            }, ignoreInit = TRUE)
        }

        if (has_in_progress) {
            observeEvent(input$show_in_progress, {
                plotlyProxy("egm_plot", session) %>%
                    plotlyProxyInvoke("restyle", list(visible = input$show_in_progress),
                                      list(egm_metadata$in_progress$index))
                update_dragmode()
            }, ignoreInit = TRUE)
        }

        # Notice shown inside the config popup when all dot layers are hidden.
        output$dots_notice <- renderUI({
            if (compute_any_dots_visible()) return(NULL)
            tags$p(class = "dots-notice",
                "Paper selection is unavailable when all dot layers are hidden."
            )
        })

        # Return the current toggle states as a reactive list.
        # mod_plot_server reads this (via isolate) when re-rendering after a
        # filter change, so the re-rendered plot starts with correct visibility.
        # confidence and in_progress default to NULL when the feature is disabled;
        # create_egm_figure() only reaches those branches if the traces exist.
        # any_dots_visible is used by app.R to clear selection when dots go hidden.
        reactive(list(
            heatmap          = input$show_heatmap,
            summary          = input$show_summary,
            confidence       = if (has_confidence)   input$show_confidence  else NULL,
            in_progress      = if (has_in_progress)  input$show_in_progress else NULL,
            any_dots_visible = compute_any_dots_visible()
        ))
    })
}