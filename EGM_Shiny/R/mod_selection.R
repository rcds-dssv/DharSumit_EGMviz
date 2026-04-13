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
# Selection parsing helper
# =============================================================================

# Converts a lasso / box-select plotly event (a dataframe, one row per selected
# dot) into a list of point-info lists.  Returns NULL for empty or invalid input.
# Rows without valid 3-element customdata (e.g. heatmap cells) are silently skipped.
create_plotly_selected_info <- function(selected_data) {
    if (is.null(selected_data) || !is.data.frame(selected_data) || nrow(selected_data) == 0) {
        return(NULL)
    }
    infos <- lapply(seq_len(nrow(selected_data)), function(i) {
        cd <- selected_data$customdata[[i]]
        if (is.null(cd) || length(cd) < 3) return(NULL)
        list(clicked_x = cd[[1]], clicked_y = cd[[2]], trace_id = cd[[3]])
    })
    infos <- Filter(Negate(is.null), infos)
    if (length(infos) == 0) NULL else infos
}


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
        return(tags$p(class = "info", "Use the lasso or box-select tool to display papers"))
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
    cite_cols    <- egm_definition$paper_citation_columns
    cite_display <- egm_definition$paper_citation_columns_display
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
        title <- tags$h4(title_text)

        # -- 2. Citation block -------------------------------------------------
        # Build inline field elements then join with middot separators.
        cite_parts <- Filter(Negate(is.null), lapply(seq_along(cite_cols), function(j) {
            col <- cite_cols[[j]]
            lbl <- cite_display[[j]]
            if (!(col %in% names(row)) || is_blank(row[[col]])) return(NULL)
            val <- as.character(row[[col]])
            if (nchar(lbl) == 0) {
                span(class = "cite-value", val)
            } else {
                tagList(span(class = "cite-label", lbl), " ", span(class = "cite-value", val))
            }
        }))

        citation <- if (length(cite_parts) > 0) {
            separated <- vector("list", length(cite_parts) * 2 - 1)
            for (k in seq_along(cite_parts)) {
                separated[[k * 2 - 1]] <- cite_parts[[k]]
                if (k < length(cite_parts))
                    separated[[k * 2]] <- span(class = "cite-sep", ", ")
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

        # -- 4. Meta rows (italic label: value, one per line) -----------------
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

        div(class = "paper-card",
            div(class = "paper-card-contents",
                title, citation, meta_section, egm_tags))
    })

    div(class = "paper-list", cards)
}


# =============================================================================
# Shiny module
# =============================================================================

mod_click_plot_header_ui <- function(id) {
    ns <- NS(id)
    uiOutput(ns("table_header"))
}

mod_click_plot_content_ui <- function(id) {
    ns <- NS(id)
    uiOutput(ns("table_content"))
}

mod_click_server <- function(id, egm_data, reset_egm_trigger, plot_source_name, x_col, y_col) {
    moduleServer(id, function(input, output, session) {

        # Current selection: list of point-info lists, or NULL when nothing is selected
        clicked_info <- reactiveVal(NULL)

        # Lasso / box-select: observe event_data() directly.
        # plotly_deselect (double-click) and filter resets both cause this to
        # become NULL, so re-selecting the same points always triggers a change.
        observeEvent(event_data("plotly_selected", source = plot_source_name), {
            info <- create_plotly_selected_info(
                event_data("plotly_selected", source = plot_source_name)
            )
            if (!is.null(info)) clicked_info(info)
        }, ignoreNULL = TRUE)

        # Dataframe of papers matching the current selection
        clicked_df <- reactive({
            create_plotly_click_df(egm_data(), clicked_info(), x_col, y_col)
        })

        # Double-click fires plotly_deselect (handled in plot_interactions.js),
        # which clears plotly's selection visual.  Mirror that by clearing the table.
        observeEvent(input$plotly_deselect_trigger, {
            clicked_info(NULL)
        })

        # Filter changes increment reset_egm_trigger and trigger a full plot
        # re-render, which naturally clears selections.  Clear the table too.
        observeEvent(reset_egm_trigger(), {
            clicked_info(NULL)
        }, ignoreInit = TRUE)

        output$table_header <- renderUI({
            create_table_header_html(clicked_info(), clicked_df())
        })

        output$table_content <- renderUI({
            create_table_cards_html(clicked_df())
        })
    })
}