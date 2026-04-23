# =============================================================================
# mod_help_modal — help modal UI
#
# Returns a fixed-position overlay div (hidden by default) containing
# instructions for first-time users.  Visibility is toggled client-side
# via the .open CSS class; no Shiny server logic is required.
#
# Sections are rendered conditionally using the has_confidence and
# has_in_progress flags (set in global.R) so the instructions always match
# the data that is actually loaded.
#
# Public interface:
#   help_modal_ui()  — returns the modal tagList; call once inside fluidPage()
# =============================================================================

help_modal_ui <- function() {

    # ── Dot-types list ─────────────────────────────────────────────────────────
    # Always include the "Summary" entry; confidence and in-progress entries
    # are added only when the corresponding data columns exist.
    dot_items <- list(
        tags$div(HTML("<span class='dot-swatch' style='background:var(--color-all_points)'></span><strong>Blue \u2014 Summary:</strong> every paper at that cell"))
    )
    if (has_confidence) {
        dot_items <- c(dot_items, list(
            tags$div(HTML("<span class='dot-swatch' style='background:var(--color-high_confidence)'></span><strong>Green \u2014 High Confidence:</strong> papers rated at the highest confidence level")),
            tags$div(HTML("<span class='dot-swatch' style='background:var(--color-medium_confidence)'></span><strong>Yellow \u2014 Medium Confidence:</strong> papers rated at medium confidence")),
            tags$div(HTML("<span class='dot-swatch' style='background:var(--color-low_confidence)'></span><strong>Red \u2014 Low Confidence:</strong> papers rated at the lowest confidence level"))
        ))
    }
    if (has_in_progress) {
        dot_items <- c(dot_items, list(
            tags$div(HTML("<span class='dot-swatch' style='background:var(--color-in_progress)'></span><strong>Pink \u2014 In Progress:</strong> ongoing studies"))
        ))
    }

    # ── Filters list ───────────────────────────────────────────────────────────
    # Built from egm_definition so the descriptions always match the loaded data.
    filter_items <- lapply(seq_along(egm_definition$filter_dropdown_list), function(i) {
        tags$li(HTML(paste0(
            "<strong>", egm_definition$filter_dropdown_list_display[i], "</strong>",
            " \u2014 filter papers by ", tolower(egm_definition$filter_dropdown_list_display[i])
        )))
    })

    # ── Toggles list ───────────────────────────────────────────────────────────
    # Always include Table, Heatmap, Summary; add optional toggles when present.
    toggle_items <- list(
        tags$li(HTML("<strong>Table</strong> \u2014 shows or hides the paper detail panel on the right")),
        tags$li(HTML("<strong>Heatmap</strong> \u2014 shows or hides the cell-shading overlay (darker = more papers)")),
        tags$li(HTML("<strong>Summary Dots</strong> \u2014 shows or hides the blue Summary dots"))
    )
    if (has_confidence) {
        toggle_items <- c(toggle_items, list(
            tags$li(HTML("<strong>Confidence Dots</strong> \u2014 shows or hides the High, Medium, and Low Confidence dots"))
        ))
    }
    if (has_in_progress) {
        toggle_items <- c(toggle_items, list(
            tags$li(HTML("<strong>In Progress Dots</strong> \u2014 shows or hides the pink In Progress dots"))
        ))
    }

    # ── Export formats list ────────────────────────────────────────────────────
    # Data formats are always available; citation formats are listed by name.
    export_data_items <- list(
        tags$li(HTML("<strong>CSV / Excel / JSON</strong> \u2014 downloads a spreadsheet of the selected papers with all metadata fields")),
        tags$li(HTML("<strong>APA / Vancouver / AMA / Chicago BibTeX / RIS</strong> \u2014 fetches formatted citations and saves them as a text file"))
    )

    # ── Modal HTML ─────────────────────────────────────────────────────────────
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
                    title   = "Close",
                    HTML("&times;")
                )
            ),
            div(
                class = "modal-body",

                div(class = "modal-section",
                    tags$h3("Reading the Map"),
                    tags$p(paste0(
                        "The horizontal axis shows ", egm_definition$x_column_display,
                        " and the vertical axis shows ", egm_definition$y_column_display, "."
                    )),
                    tags$p("Each bubble represents all papers at that combination. Larger bubbles mean more papers in that cell.")
                ),

                div(class = "modal-section",
                    tags$h3("Dot Types"),
                    tags$p(paste0(
                        "For this dataset, each cell can show up to ", length(dot_items),
                        "  dot", if (length(dot_items) == 1) "" else "s, slightly offset from one another",
                        ":"
                    )),
                    tags$div(dot_items)
                ),

                div(class = "modal-section",
                    tags$h3("Selecting Papers"),
                    tags$p("Use the box-select or lasso tool in the plotly toolbar (top-right corner of the chart). Click and drag to draw a selection around one or more bubbles \u2014 the paper panel on the right will populate with matching records, sorted by first author."),
                    tags$p("Clicking directly on the chart without using a selection tool does not trigger the paper panel."),
                    tags$p("To clear your selection, double-click anywhere on the chart.")
                ),

                div(class = "modal-section",
                    tags$h3("Filters"),
                    tags$p("Open the Filters dropdown (right side of the header) to narrow the papers shown on the map:"),
                    tags$ul(filter_items),
                    tags$p("Changing a filter immediately re-renders the map and clears any current selection.")
                ),

                div(class = "modal-section",
                    tags$h3("Toggles"),
                    tags$p("Open the Toggles dropdown (right side of the header) to show or hide individual layers:"),
                    tags$ul(toggle_items),
                    tags$p("Toggles update the chart instantly and do not clear your current selection.")
                ),

                div(class = "modal-section",
                    tags$h3("Paper Panel"),
                    tags$p("The panel on the right shows details for the papers in your current selection. At the top it displays the total paper count and colour-coded tags for the selected study types, themes, and confidence levels. Each paper appears as a card with its citation and metadata fields."),
                    tags$p("Clicking a card opens the paper's DOI link in a new tab (when a DOI is available).")
                ),

                div(class = "modal-section",
                    tags$h3("Exporting Papers"),
                    tags$p("With papers selected, open the Export dropdown (top-right of the paper panel) to choose a format and click Download:"),
                    tags$ul(export_data_items),
                    tags$p("For citation formats, the app contacts the Crossref API to fetch formatted references. A progress indicator will appear while citations are being retrieved. The download begins automatically when fetching is complete."),
                    tags$p("If any papers are missing DOI information or cannot be retrieved from the API, a summary will appear listing which papers were skipped and why.")
                )
            )
        )
    )
}