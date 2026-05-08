# =============================================================================
# mod_help_modal — help modal UI
#
# Returns a fixed-position overlay div (visible at load) containing
# instructions for first-time users.  Visibility is toggled client-side
# via the .open CSS class; no Shiny server logic is required.
#
# Sections are rendered conditionally using the has_confidence and
# has_in_progress flags (set in app_config.R) so the instructions always match
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
        tags$div(HTML("<span class='dot-swatch' style='background:var(--color-all-points)'></span><strong>Blue \u2014 Summary:</strong> every paper at that cell"))
    )
    if (has_confidence) {
        dot_items <- c(dot_items, list(
            tags$div(HTML("<span class='dot-swatch' style='background:var(--color-high-confidence)'></span><strong>Green \u2014 High Confidence:</strong> papers rated at the highest confidence level")),
            tags$div(HTML("<span class='dot-swatch' style='background:var(--color-medium-confidence)'></span><strong>Yellow \u2014 Medium Confidence:</strong> papers rated at medium confidence")),
            tags$div(HTML("<span class='dot-swatch' style='background:var(--color-low-confidence)'></span><strong>Red \u2014 Low Confidence:</strong> papers rated at the lowest confidence level"))
        ))
    }
    if (has_in_progress) {
        dot_items <- c(dot_items, list(
            tags$div(HTML("<span class='dot-swatch' style='background:var(--color-in-progress)'></span><strong>Pink \u2014 In Progress:</strong> ongoing studies"))
        ))
    }
    # Search dot is always present (appears only when a search is active)
    dot_items <- c(dot_items, list(
        tags$div(HTML(paste0(
            "<span class='dot-swatch' style='background:", egm_definition$plot_colors$search_points, "'></span>",
            "<strong>Orange \u2014 Search Results:</strong> cells that contain at least one paper matching the current search query (visible only when a search is active)"
        )))
    ))

    # ── Filters list ───────────────────────────────────────────────────────────
    # Built from egm_definition so the descriptions always match the loaded data.
    filter_items <- lapply(seq_along(egm_definition$filter_dropdown_list), function(i) {
        tags$li(HTML(paste0("<strong>", egm_definition$filter_dropdown_list_display[i], "</strong>")))
    })

    # ── Toggles list ───────────────────────────────────────────────────────────
    # Always include Table, Heatmap, Summary; add optional toggles when present.
    toggle_items <- list(
        tags$li(HTML("<strong>Heatmap</strong> \u2014 shows or hides the cell-shading overlay (darker = more papers)")),
        tags$li(HTML("<strong>Summary Dots</strong> \u2014 shows or hides the Summary dots"))
    )
    if (has_confidence) {
        toggle_items <- c(toggle_items, list(
            tags$li(HTML("<strong>Confidence Dots</strong> \u2014 shows or hides the High, Medium, and Low Confidence dots"))
        ))
    }
    if (has_in_progress) {
        toggle_items <- c(toggle_items, list(
            tags$li(HTML("<strong>In Progress Dots</strong> \u2014 shows or hides the In Progress dots"))
        ))
    }

    # ── Export formats list ────────────────────────────────────────────────────
    # Data formats are always available; citation formats are listed by name.
    export_data_items <- list(
        tags$li(HTML("<strong>CSV / Excel / JSON</strong> \u2014 contains all bibliographic and metadata fields from the selected papers")),
        tags$li(HTML("<strong>APA / AMA / Chicago / BibTeX / RIS</strong> \u2014 follows the given citation format, and excludes metadata fields"))
    )

    # ── Modal HTML ─────────────────────────────────────────────────────────────
    tags$div(
        id    = "egm-help-modal",
        class = "modal-overlay open",
        div(
            class = "modal-content",
            div(
                class = "modal-header",
                tags$h1("Information and Instructions"),
                tags$button(
                    class   = "modal-close-btn",
                    onclick = "document.getElementById('egm-help-modal').classList.remove('open')",
                    title   = "Close",
                    HTML("&times;")
                )
            ),
            div(
                class = "modal-body",

                # ── Intro section ──────────────────────────────────────────

                div(class = "modal-section",
                    tags$h2("Welcome"),
                    tags$p(egm_definition$app_description),
                    tags$p(HTML(
                        "Start by reading the instructions below. When you're ready, use the <strong>\u00d7</strong> in the upper-right ",
                        "or type <strong>Esc</strong> on your keyboard to close this box and start exploring the data. ",
                        "(You can reopen this section by clicking the ",
                        "<em>Information and Instructions</em> button at the top of the main page.)"
                    ))
                ),

                # ── Credits section ────────────────────────────────────────
                div(class = "modal-section",
                    tags$h3("Acknowledgements"),
                    tags$p(HTML(egm_definition$app_acknowledgements))
                ),


                # ── Instructions header ────────────────────────────────────
                div(class = "modal-section",
                    tags$h2("Instructions")
                ),

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
                    tags$p("There are multiple ways to select papers from the map.  You can click on a single point and use 'Ctrl/Cmd' + click to add (or remove) points from your selection.  Alternatively, you can use the box-select or lasso tool in the plotly toolbar (top-right corner of the chart). For either tool, click and drag to draw a selection around one or more bubbles.  After selecting papers, the  panel on the right will populate with matching records."),
                    tags$p(HTML("To clear your selection, double-click anywhere on the chart. or use the <em>Deselect all</em> button in the top-right corner of the map section."))
                ),

                div(class = "modal-section",
                    tags$h3("Searching Papers"),
                    tags$p("Use the Search panel (below the Filters panel) to find papers by keyword. Expand it with the arrow button, then type a query into the text box. The search checks the title, authors, journal, and several other fields simultaneously — a paper matches if any of those fields contain the query text (case-insensitive)."),
                    tags$p("While a search is active:"),
                    tags$ul(
                        tags$li("Orange dots appear on the map showing which cells contain matching papers."),
                        tags$li("The papers panel and comparison plots update to reflect the matched papers only."),
                        tags$li("A status line shows how many papers were matched.")
                    ),
                    tags$p(HTML("Click <em>✕ Clear</em> to exit search mode, or click any bubble on the map to switch back to a cell selection (this also clears the search). Making a map selection while a search is active will exit the search and show the papers for the selected bubble(s) instead."))
                ),

                div(class = "modal-section",
                    tags$h3("Filters"),
                    tags$p("Use the dropdowns within the filters panel to narrow the papers shown on the map:"),
                    tags$ul(filter_items),
                    tags$p("Changing a filter immediately re-renders the map and clears any current selection.")
                ),

                div(class = "modal-section",
                    tags$h3("Toggles"),
                    tags$p("Open the Toggles menu (upper-right corner of the map section) to show or hide individual layers:"),
                    tags$ul(toggle_items),
                    tags$p("Toggles update the chart instantly and do not clear your current selection.")
                ),

                div(class = "modal-section",
                    tags$h3("Papers Comparison Panel"),
                    tags$p("The panel on the right shows details for the papers in your current selection."),
                    tags$p("At the top you will see information about each paper, including a summary of the selection followed by a card for each paper with its citation and metadata fields.  Clicking a card opens the paper's DOI link in a new tab (when a DOI is available)."),
                    tags$p("At the bottom you will see figures that compare various features of the papers in your selection.  Use the buttons in the top-right of this section to change the plot type.")
                ),

                div(class = "modal-section",
                    tags$h3("Exporting Papers"),
                    tags$p("With papers selected, open the Export dropdown (top-right of the paper panel) to choose a format and click Download:"),
                    tags$ul(export_data_items)
                ),

                div(class = "modal-section",
                    tags$h3("Configuring the Page Layout"),
                    tags$p("Many of the panels can be manually resized to better fit your screen. The top two panels can be collapsed upwards with the arrow buttons in the upper-left corners.  The panels below have click+draggable dividers that can be used to expand or shrink the sections."),
                )
            )
        )
    )
}