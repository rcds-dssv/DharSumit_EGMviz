# =============================================================================
# mod_search — full-text search over the filtered paper dataset
#
# Searches egm_data()$all$df (respects active filters) across the columns
# listed in egm_definition$search_columns using a case-insensitive substring
# match.  A paper matches if ANY search column contains the query string.
#
# When a query is active:
#   • The EGM plot gains an orange search-result dot layer (one dot per cell,
#     sized by match count) updated via plotlyProxy — no full re-render.
#   • The papers panel and comparison plots are driven by search results instead
#     of the plotly selection.  Mutual exclusivity is handled by the caller:
#     mod_search_server clears the plotly selection on activation; app.R
#     passes a clear_search_trigger that fires when the user makes a plot
#     selection.
#
# Public interface:
#   mod_search_ui(id)
#   mod_search_server(id, egm_data, clear_search_trigger)
#     → list(active, df, clicked_info, render_count)
# =============================================================================


mod_search_ui <- function(id) {
    ns <- NS(id)
    tagList(
        tags$span(class = "toolbar-section-label", "Search"),
        div(
            class = "search-input-row",
            tags$span(class = "material-symbols-outlined search-icon", "search"),
            div(
                class = "search-input-wrap",
                textInput(ns("query"), label = NULL,
                          placeholder = "Search papers (title, authors, journal, …)")
            ),
            uiOutput(ns("clear_btn")),
            uiOutput(ns("status_line"))
        )
    )
}


mod_search_server <- function(id, egm_data, clear_search_trigger = NULL) {
    moduleServer(id, function(input, output, session) {

        search_active <- reactive({
            !is.null(input$query) && nchar(trimws(input$query)) > 0
        })

        search_df <- reactive({
            if (!search_active()) return(NULL)
            query     <- trimws(input$query)
            cols      <- egm_definition$search_columns
            df        <- egm_data()$all$df
            valid_cols <- intersect(cols, names(df))
            if (length(valid_cols) == 0) return(NULL)

            # OR across columns: paper matches if ANY configured column contains query
            matches <- Reduce(`|`, lapply(valid_cols, function(col) {
                stringr::str_detect(
                    tolower(as.character(df[[col]])),
                    stringr::fixed(tolower(query))
                )
            }))
            df[!is.na(matches) & matches, , drop = FALSE]
        })

        # One clicked_info entry per unique (x, y) cell in the search results,
        # using trace_id = "all".  build_labeled_data() in mod_comparison_plots.R
        # will filter the (search-replaced) egm_data df to each cell, giving
        # comparison plots that cover only the matched papers.
        search_clicked_info <- reactive({
            df <- search_df()
            if (is.null(df) || nrow(df) == 0) return(NULL)
            x_col <- egm_definition$x_column
            y_col <- egm_definition$y_column
            cells <- df %>%
                dplyr::select(dplyr::all_of(c(x_col, y_col))) %>%
                dplyr::distinct() %>%
                dplyr::arrange(.data[[x_col]], .data[[y_col]])
            lapply(seq_len(nrow(cells)), function(i) {
                list(clicked_x = cells[[x_col]][i],
                     clicked_y = cells[[y_col]][i],
                     trace_id  = "all")
            })
        })

        # ── Clear / status UI ─────────────────────────────────────────────────

        output$clear_btn <- renderUI({
            if (!search_active()) return(NULL)
            actionButton(session$ns("clear"), "✕ Clear", class = "reset-btn filters-reset-btn search-clear-btn")
        })

        observeEvent(input$clear, {
            updateTextInput(session, "query", value = "")
        })

        output$status_line <- renderUI({
            if (!search_active()) return(NULL)
            df <- search_df()
            n  <- if (is.null(df)) 0L else nrow(df)
            msg <- if (n == 0L) "No papers matched"
                   else paste0(n, " paper", if (n == 1L) "" else "s", " matched")
            tags$span(class = "search-status", msg)
        })

        # ── Mutual exclusivity: clear plotly selection when search activates ──

        observeEvent(search_active(), {
            if (search_active()) {
                session$sendCustomMessage("clearPlotlySelection",
                    list(plotId = NS("egm")("egm_plot"), notifyR = TRUE))
            }
        }, ignoreInit = TRUE)

        # ── External clear: plot selection made while search is active ────────

        if (!is.null(clear_search_trigger)) {
            observeEvent(clear_search_trigger(), {
                updateTextInput(session, "query", value = "")
            }, ignoreInit = TRUE)
        }

        # ── EGM plot search dot layer (updated via plotlyProxy) ───────────────

        # Sends a restyle proxy call to show/hide/update the search trace.
        # Fires when search_df changes (query change) OR when egm_data changes
        # (filter change recomputes search results over the new filtered data).
        observeEvent(list(search_df(), search_active()), {
            search_idx <- egm_metadata$search$index

            if (!search_active()) {
                plotlyProxy("egm_plot", session) %>%
                    plotlyProxyInvoke("restyle", list(visible = FALSE),
                                      list(search_idx))
                return()
            }

            df <- search_df()
            if (is.null(df) || nrow(df) == 0) {
                plotlyProxy("egm_plot", session) %>%
                    plotlyProxyInvoke("restyle", list(visible = FALSE),
                                      list(search_idx))
                return()
            }

            x_col    <- egm_definition$x_column
            y_col    <- egm_definition$y_column
            x_levels <- levels(factor(initial_egm_data$all$counts[[x_col]]))
            y_levels <- levels(factor(initial_egm_data$all$counts[[y_col]]))

            cell_counts <- df %>%
                dplyr::count(.data[[x_col]], .data[[y_col]])

            offset_x <- egm_metadata$search$offset_x
            offset_y <- egm_metadata$search$offset_y
            x_num    <- match(cell_counts[[x_col]], x_levels) - 1 + offset_x
            y_num    <- match(cell_counts[[y_col]], y_levels) - 1 + offset_y

            # unname(): quantile() returns a named value ("99%"); for a
            # single-cell result that name propagates to `sizes`, which plotly
            # then serialises as a JSON object instead of an array (breaking the
            # marker size so no dot renders).
            size_cap <- unname(quantile(initial_egm_data$all$counts$n, 0.99, na.rm = TRUE))
            sizes    <- unname(scales::rescale(
                sqrt(pmin(cell_counts$n, size_cap)),
                to   = c(egm_definition$plot_points_desired_min_px,
                         egm_definition$plot_points_desired_max_px),
                from = c(0, sqrt(size_cap))
            ))

            hover <- paste0(
                "<b>Search result</b><br>",
                egm_definition$x_column_display, ": ", cell_counts[[x_col]], "<br>",
                egm_definition$y_column_display, ": ", cell_counts[[y_col]], "<br>",
                "N matched: ", cell_counts$n
            )

            # as.list() forces each per-point attribute to serialise as a JSON
            # array even when a single cell matched — otherwise a length-1 vector
            # auto-unboxes to a scalar and the scatter trace renders no point.
            plotlyProxy("egm_plot", session) %>%
                plotlyProxyInvoke("restyle",
                    list(x             = list(as.list(x_num)),
                         y             = list(as.list(y_num)),
                         text          = list(as.list(hover)),
                         "marker.size" = list(as.list(sizes)),
                         visible       = TRUE),
                    list(search_idx)
                )
        }, ignoreInit = TRUE)

        list(
            active       = search_active,
            df           = search_df,
            clicked_info = search_clicked_info
        )
    })
}
