# =============================================================================
# mod_help_modal — help modal UI
#
# Returns a fixed-position overlay div (hidden by default) containing
# instructions for first-time users.  Visibility is toggled client-side
# via the .open CSS class; no Shiny server logic is required.
#
# Public interface:
#   help_modal_ui()  — returns the modal tagList; call once inside fluidPage()
# =============================================================================

help_modal_ui <- function() {
    tags$div(
        id    = "egm-help-modal",
        class = "modal-overlay",
        div(
            class = "modal-content",
            div(
                class = "modal-header",
                tags$h2("Instructions"),
                tags$button(
                    class   = "modal-close-btn",
                    onclick = "document.getElementById('egm-help-modal').classList.remove('open')",
                    HTML("&times;")
                )
            ),
            div(
                class = "modal-body",

                div(class = "modal-section",
                    tags$h3("Reading the Map"),
                    tags$p(paste0(
                        "The horizontal axis (X) shows ", egm_definition$x_column_display,
                        " \u2014 the type of study or intervention. The vertical axis (Y) shows ",
                        egm_definition$y_column_display,
                        " \u2014 the health outcome or research theme being addressed."
                    )),
                    tags$p("Each bubble represents all papers at that combination of study type and theme. Larger bubbles mean more papers in that cell.")
                ),

                div(class = "modal-section",
                    tags$h3("Dot Types"),
                    tags$p("Each cell can show up to five overlapping dots, slightly offset from one another:"),
                    tags$ul(
                        tags$li(HTML("<span class='dot-swatch' style='background:var(--color-all_points)'></span><strong>Blue \u2014 All Papers:</strong> every paper at that cell, regardless of confidence level")),
                        tags$li(HTML("<span class='dot-swatch' style='background:var(--color-high_confidence)'></span><strong>Green \u2014 High Confidence:</strong> papers rated at the highest confidence level")),
                        tags$li(HTML("<span class='dot-swatch' style='background:var(--color-medium_confidence)'></span><strong>Yellow \u2014 Medium Confidence:</strong> papers rated at medium confidence")),
                        tags$li(HTML("<span class='dot-swatch' style='background:var(--color-low_confidence)'></span><strong>Red \u2014 Low Confidence:</strong> papers rated at the lowest confidence level")),
                        tags$li(HTML("<span class='dot-swatch' style='background:var(--color-in_progress)'></span><strong>Pink \u2014 In Progress:</strong> ongoing studies"))
                    )
                ),

                div(class = "modal-section",
                    tags$h3("Selecting Papers"),
                    tags$p("To view paper details, use the lasso tool or box-select tool in the plotly toolbar (top-right corner of the chart). Click and drag to draw a selection region around one or more bubbles \u2014 the paper panel on the right will populate with matching records."),
                    tags$p("Clicking directly on the chart background or on a bubble without using a selection tool does not trigger the paper panel. You must use the lasso or box-select tool."),
                    tags$p("To clear your selection, double-click anywhere on the chart.")
                ),

                div(class = "modal-section",
                    tags$h3("Filters"),
                    tags$p("Open the Filters dropdown (right side of the header) to narrow the papers shown on the map by demographic reporting characteristics:"),
                    tags$ul(
                        tags$li(HTML("<strong>Gender Reported</strong> \u2014 whether the study reported on gender")),
                        tags$li(HTML("<strong>Ethnicity Reported</strong> \u2014 whether the study reported on ethnicity")),
                        tags$li(HTML("<strong>Race Reported</strong> \u2014 whether the study reported on race")),
                        tags$li(HTML("<strong>US Origin</strong> \u2014 whether the study originates from the United States"))
                    ),
                    tags$p("Each filter offers three choices: Any (default), Yes, or No. Changing a filter immediately re-renders the map and clears any current selection.")
                ),

                div(class = "modal-section",
                    tags$h3("Toggles"),
                    tags$p("Open the Toggles dropdown (right side of the header) to show or hide individual layers of the map:"),
                    tags$ul(
                        tags$li(HTML("<strong>Table</strong> \u2014 shows or hides the paper detail panel on the right")),
                        tags$li(HTML("<strong>Heatmap</strong> \u2014 shows or hides the gray cell-shading overlay (darker = more papers)")),
                        tags$li(HTML("<strong>All Papers</strong> \u2014 shows or hides the blue All Papers dots")),
                        tags$li(HTML("<strong>Confidence</strong> \u2014 shows or hides the High, Medium, and Low Confidence dots")),
                        tags$li(HTML("<strong>In Progress</strong> \u2014 shows or hides the pink In Progress dots"))
                    ),
                    tags$p("Toggles update the chart instantly and do not clear your current selection.")
                ),

                div(class = "modal-section",
                    tags$h3("Paper Panel"),
                    tags$p("The panel on the right shows details for the papers in your current selection. At the top it displays the total paper count and color-coded tags indicating which study types, themes, and confidence levels are represented. Below that, each paper appears as a card with its metadata fields."),
                    tags$p("Use the Export button (top-right of the paper panel) to download citation information for the selected papers."),
                    tags$p("If the panel is not visible, open the Toggles dropdown and turn the Table toggle back on.")
                )
            )
        )
    )
}
