# =============================================================================
# mod_selection — plot selection handling and paper table
#
# Listens for plotly lasso / box-select events and renders the matching papers
# in a table below the plot.  Plotly's native selectedpoints mechanism handles
# visual dimming of unselected points automatically — no manual restyle needed.
#
# Selection state is stored in the reactiveVal `clicked_info`, which is a
# list of point-info lists (one per selected dot).  Each point-info list has:
#   clicked_x — x-axis label of the selected cell (e.g. "Intervention")
#   clicked_y — y-axis label of the selected cell (e.g. "Quality of Life")
#   trace_id  — evidence category key matching egm_metadata (e.g. "high")
#
# customdata embedded in each plotly marker is a list(x_label, y_label, trace_id),
# set by add_to_counts_df_for_plotly() in mod_plot.R.
#
# Public interface:
#   mod_click_plot_header_ui(id)  — paper count + selection attribute tags
#   mod_click_plot_content_ui(id) — scrollable list of paper cards
#   mod_click_server(...)         — server logic
# =============================================================================




# =============================================================================
# Table HTML helpers
# =============================================================================

# Returns the rows from egm_data that correspond to all selected points.
# Rows from multiple traces at the same grid cell are de-duplicated.
create_plotly_click_df <- function(egm_data, selected_info, x_col, y_col) {
    if (is.null(selected_info)) return(NULL)
    dfs <- lapply(selected_info, function(pt) {
        egm_data[[pt$trace_id]]$df %>%
            dplyr::filter(.[[x_col]] == pt$clicked_x,
                          .[[y_col]] == pt$clicked_y)
    })
    dplyr::bind_rows(dfs) %>% dplyr::distinct()
}

# Renders the table header: paper count and one color-coded tag per unique
# x-axis value, y-axis value, and evidence-category label in the selection.
create_table_header_html <- function(selected_info, df) {
    if (is.null(selected_info) || is.null(df) || nrow(df) == 0) {
        return(tagList())
    }

    n        <- nrow(df)
    unique_x <- unique(sapply(selected_info, function(pt) pt$clicked_x))
    unique_y <- unique(sapply(selected_info, function(pt) pt$clicked_y))

    # Collect unique (trace_id, display_text) pairs, skipping the "all" trace
    # which has display_text = NULL and no dedicated color tag.
    trace_display_pairs <- unique(Filter(Negate(is.null), lapply(selected_info, function(pt) {
        dt <- egm_metadata[[pt$trace_id]]$display_text
        if (is.null(dt)) NULL else list(trace_id = pt$trace_id, display_text = dt)
    })))

    tagList(
        tags$p(paste("Number of papers:", n)),
        tags$div(
            tags$p("Selection attributes:"),
            tags$div(class = "paper-tags",
                lapply(unique_x, function(v) tags$span(class = "tag", v)),
                lapply(unique_y, function(v) tags$span(class = "tag", v)),
                # CSS class "tag high" / "tag medium" / etc. controls badge color
                lapply(trace_display_pairs, function(td)
                    tags$span(class = paste("tag", td$trace_id), td$display_text))
            )
        )
    )
}

# Renders one card per paper row with four distinct sections:
#   1. Title        -- from egm_definition$paper_title_column (card heading)
#   2. Citation     -- compact inline block with short labeled fields
#   3. EGM tags     -- x/y axis values + optional confidence / in-progress badges
#   4. Meta badges  -- labeled pills for paper_meta_columns ("Setting: Hospital")
create_table_cards_html <- function(df) {
    if (is.null(df) || nrow(df) == 0) return(div(class = "paper-list"))

    title_col    <- egm_definition$paper_title_column
    doi_col      <- egm_definition$paper_doi_column
    cite_cols    <- egm_definition$paper_citation_columns
    cite_display <- egm_definition$paper_citation_columns_display
    cite_bold    <- egm_definition$paper_citation_columns_bold
    meta_cols    <- egm_definition$paper_meta_columns
    meta_display <- egm_definition$paper_meta_columns_display
    x_col        <- egm_definition$x_column
    y_col        <- egm_definition$y_column
    conf_col     <- egm_definition$confidence_column_name
    in_prog_col  <- egm_definition$in_progress_column_name
    conf_labels  <- c("Low", "Medium", "High")

    # TRUE when a value should be treated as absent in display
    is_blank <- function(v) is.na(v) || trimws(as.character(v)) == "" ||
                             as.character(v) == "None Given"

    cards <- lapply(seq_len(nrow(df)), function(i) {
        row <- df[i, , drop = FALSE]

        # -- 1. Title ----------------------------------------------------------
        title_text <- if (!is.null(title_col) && !is.na(title_col) &&
                         title_col %in% names(row) && !is_blank(row[[title_col]])) {
            as.character(row[[title_col]])
        } else "(No title)"
        title <- tags$h4(paste0(i, ". ", title_text))

        # -- 2. Citation block -------------------------------------------------
        # Build inline field elements then join with middot separators.
        cite_parts <- Filter(Negate(is.null), lapply(seq_along(cite_cols), function(j) {
            col  <- cite_cols[[j]]
            lbl  <- cite_display[[j]]
            bold <- isTRUE(cite_bold[[j]])
            if (!(col %in% names(row)) || is_blank(row[[col]])) return(NULL)
            val <- as.character(row[[col]])
            val_tag <- if (bold) tags$strong(class = "cite-value", val) else span(class = "cite-value", val)
            if (nchar(lbl) == 0) {
                val_tag
            } else {
                tagList(span(class = "cite-label", lbl), " ", val_tag)
            }
        }))

        citation <- if (length(cite_parts) > 0) {
            separated <- vector("list", length(cite_parts) * 2 - 1)
            for (k in seq_along(cite_parts)) {
                separated[[k * 2 - 1]] <- cite_parts[[k]]
                if (k < length(cite_parts))
                    separated[[k * 2]] <- span(class = "cite-sep", "; ")
            }
            div(class = "paper-citation", separated)
        }

        # -- 3. EGM attribute tags ---------------------------------------------
        conf_tag <- if (has_confidence && !is.na(row[[conf_col]])) {
            level <- row[[conf_col]]
            tags$span(class = paste("tag", tolower(conf_labels[level])),
                      paste(conf_labels[level], "Confidence"))
        }
        in_progress_tag <- if (has_in_progress && !is_blank(row[[in_prog_col]]) &&
                               row[[in_prog_col]] > 0) {
            tags$span(class = "tag in_progress", "In Progress")
        }
        egm_tags <- tags$div(class = "paper-tags",
            tags$span(class = "tag", row[[x_col]]),
            tags$span(class = "tag", row[[y_col]]),
            conf_tag, in_progress_tag
        )

        # -- 4. Meta rows (italic label: separated by vertical bar) -----------------
        meta_items <- Filter(Negate(is.null), lapply(seq_along(meta_cols), function(j) {
            col <- meta_cols[[j]]
            lbl <- meta_display[[j]]
            if (!(col %in% names(row)) || is_blank(row[[col]])) return(NULL)
            div(class = "paper-meta",
                tags$em(class = "paper-meta-label", paste0(lbl, ":")),
                span(class = "paper-meta-value", as.character(row[[col]])))
        }))
        meta_section <- if (length(meta_items) > 0)
            div(class = "paper-meta-list", meta_items)

        doi_val <- if (!is.null(doi_col) && !is.na(doi_col) &&
                        doi_col %in% names(row) && !is_blank(row[[doi_col]])) {
            as.character(row[[doi_col]])
        } else NULL

        card_inner <- div(class = "paper-card-contents",
            title, citation, meta_section, egm_tags)

        if (!is.null(doi_val)) {
            tags$a(
                href   = paste0("https://doi.org/", doi_val),
                target = "_blank",
                rel    = "noopener noreferrer",
                class  = "paper-card paper-card-link",
                card_inner
            )
        } else {
            div(class = "paper-card", card_inner)
        }
    })

    div(class = "paper-list", cards)
}


# =============================================================================
# Shiny module
# =============================================================================

mod_plot_info_ui <- function(id) {
    ns <- NS(id)
    uiOutput(ns("plot_info"))
}

mod_click_plot_header_ui <- function(id) {
    ns <- NS(id)
    uiOutput(ns("table_header"))
}

mod_click_plot_content_ui <- function(id) {
    ns <- NS(id)
    uiOutput(ns("table_content"))
}

mod_deselect_ui <- function(id) {
    ns <- NS(id)
    actionButton(ns("deselect_all"), "Deselect all", class = "reset-btn filters-reset-btn")
}

mod_sort_ui <- function(id) {
    ns <- NS(id)
    div(
        class = "sort-select-wrapper",
        selectInput(
            ns("sort_by"),
            label    = "Sort by",
            choices  = setNames(egm_definition$paper_sort_columns,
                                egm_definition$paper_sort_columns_display),
            selected = egm_definition$paper_sort_columns[1]
        ),
        actionButton(ns("sort_dir_toggle"), "\u2191", class = "sort-dir-btn", title = "Toggle sort direction")
    )
}

mod_click_reset_ui <- function(id) {
    ns <- NS(id)
    actionButton(ns("reset_plot"), "Reset Selection", class = "reset-btn")
}

mod_click_server <- function(id, egm_data, reset_egm_trigger, plot_source_name, x_col, y_col) {
    moduleServer(id, function(input, output, session) {

        # Current selection: list of point-info lists, or NULL when nothing is selected
        clicked_info <- reactiveVal(NULL)

        # Sort direction: "asc" or "desc"; toggled by the ↑/↓ button.
        sort_dir <- reactiveVal("asc")

        observeEvent(input$sort_dir_toggle, {
            new_dir <- if (sort_dir() == "asc") "desc" else "asc"
            sort_dir(new_dir)
            updateActionButton(session, "sort_dir_toggle",
                               label = if (new_dir == "asc") "\u2191" else "\u2193")
        })

        # Selection events come from plot_interactions.js as a custom input.
        # JS handles Ctrl/Cmd+click accumulation and applies selectedpoints
        # visually before sending; R just converts the customdata list to
        # clicked_info format and updates the paper table.
        observeEvent(input$plotly_accumulated_selection, {
            sel <- input$plotly_accumulated_selection
            if (is.null(sel) || length(sel) == 0) {
                clicked_info(NULL)
                return()
            }
            # Shiny/jsonlite flattens JS [[a,b,c],[d,e,f]] into a plain character
            # vector of length 3*N.  Each customdata tuple is always 3 elements,
            # so split the flat vector into consecutive 3-element chunks.
            if (is.character(sel)) {
                n_pts <- length(sel) / 3L
                sel <- lapply(seq_len(n_pts), function(i) sel[((i - 1L) * 3L + 1L):(i * 3L)])
            }
            info <- Filter(Negate(is.null), lapply(sel, function(cd) {
                if (length(cd) < 3) return(NULL)
                list(clicked_x = cd[[1]], clicked_y = cd[[2]], trace_id = cd[[3]])
            }))
            clicked_info(if (length(info) > 0) info else NULL)
        }, ignoreNULL = TRUE, ignoreInit = TRUE)

        # Dataframe of papers matching the current selection, sorted by the chosen column.
        clicked_df <- reactive({
            df <- create_plotly_click_df(egm_data(), clicked_info(), x_col, y_col)
            if (is.null(df) || nrow(df) == 0) return(df)
            sort_col <- input$sort_by
            if (!is.null(sort_col) && sort_col %in% names(df))
                df <- df[order(df[[sort_col]], decreasing = sort_dir() == "desc", na.last = TRUE), ]
            df
        })

        # Double-click fires plotly_deselect (handled in plot_interactions.js),
        # which clears plotly's selection visual.  Mirror that by clearing the table.
        observeEvent(input$plotly_deselect_trigger, {
            clicked_info(NULL)
        })

        # "Deselect all" button: clear state, remove the plotly selection shape, and
        # restore full opacity by resetting selectedpoints on all traces.
        observeEvent(input$deselect_all, {
            clicked_info(NULL)
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("relayout", list(selections = list()))
            session$sendCustomMessage("clearPlotlySelection",
                                      list(plotId = session$ns("egm_plot")))
        })

        # Reset button: increment the shared trigger so mod_filter_server also
        # reacts (they share the same reset path).
        observeEvent(input$reset_plot, {
            reset_egm_trigger(reset_egm_trigger() + 1)
        })

        # Filter changes and the Reset button both increment reset_egm_trigger.
        # A filter change also triggers a full plot re-render, so the proxy
        # relayout is harmless overlap; dragmode = "select" is set explicitly
        # to recover from any drag-state confusion caused by the re-render racing
        # with prior proxy calls.
        observeEvent(reset_egm_trigger(), {
            clicked_info(NULL)
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("relayout", list(
                    selections = list(),
                    dragmode   = "select"
                ))
        }, ignoreInit = TRUE)

        # Show/hide the table section and resize handle based on selection state.
        observe({
            session$sendCustomMessage("toggleTableSection",
                                      list(visible = !is.null(clicked_info())))
        })

        output$plot_info <- renderUI({
            if (is.null(clicked_info())) {
                tags$p(class = "info", "Click on a point or click+drag with the box-select or lasso tool to display papers.")
            } else {
                tags$p(class = "info", 'Use the "Deselect all" button or double click within the plot to deselect.')
            }
        })

        output$table_header <- renderUI({
            create_table_header_html(clicked_info(), clicked_df())
        })

        output$table_content <- renderUI({
            create_table_cards_html(clicked_df())
        })

        # Return the selection state so other modules (e.g. mod_export) can
        # react to it without duplicating the observer logic.
        list(
            clicked_df   = clicked_df,
            clicked_info = clicked_info
        )
    })
}