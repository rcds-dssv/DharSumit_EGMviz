# =============================================================================
# mod_filter — demographic filter controls
#
# Reads filter_dropdown_list and filter_dropdown_list_display from
# egm_definition (user_config.R) to programmatically generate one dropdown per
# filter column.  Choices are "All" plus every unique value in that column
# (NA values have already been replaced with "Other" in app_config.R).
#
# Choice ordering rules (applied by order_filter_choices):
#   - Yes/No columns (case-insensitive): Yes, No, <other values alpha>, Other
#   - All other columns: <values alpha>, Other
#
# Conditional filters (filter_conditional in user_config.R):
#   A child filter is hidden until its parent filter has a value in show_when.
#   When hidden, the child resets to "All" and is skipped during data filtering.
#   The child's choices are drawn only from rows where the parent is in show_when.
#
# When any filter changes the module re-filters df_all, rebuilds egm_data,
# and increments reset_egm_trigger to clear the table.
# =============================================================================

# Returns vals sorted per the ordering rules described above.
order_filter_choices <- function(vals) {
    vals_lower <- tolower(vals)
    other_vals <- vals[vals_lower == "other"]
    if ("yes" %in% vals_lower && "no" %in% vals_lower) {
        yes_vals <- vals[vals_lower == "yes"]
        no_vals  <- vals[vals_lower == "no"]
        rest     <- sort(vals[!vals_lower %in% c("yes", "no", "other")])
        c(yes_vals, no_vals, rest, other_vals)
    } else {
        c(sort(vals[vals_lower != "other"]), other_vals)
    }
}

# Build a named list of conditional specs keyed by the dependent filter column.
# Returns an empty list when filter_conditional is NULL or absent.
build_cond_map <- function() {
    specs <- egm_definition$filter_conditional
    if (is.null(specs) || length(specs) == 0) return(list())
    setNames(specs, sapply(specs, `[[`, "filter"))
}


mod_filter_ui <- function(id) {
    ns <- NS(id)

    filter_cols    <- egm_definition$filter_dropdown_list
    filter_display <- egm_definition$filter_dropdown_list_display
    cond_map       <- build_cond_map()

    filter_items <- lapply(seq_along(filter_cols), function(i) {
        col     <- filter_cols[[i]]
        display <- filter_display[[i]]

        if (col %in% names(cond_map)) {
            # Conditional filter: choices only from rows where parent matches;
            # wrapped in a toggleable div that starts hidden.
            parent_col <- cond_map[[col]]$parent
            show_when  <- cond_map[[col]]$show_when
            df_cond    <- df_all[df_all[[parent_col]] %in% show_when, ]
            choices    <- c("All", order_filter_choices(unique(df_cond[[col]])))
            div(id = ns(paste0(col, "_wrapper")), style = "display:none",
                div(class = "filters-item",
                    tags$label(display),
                    selectInput(ns(col), label = NULL, choices = choices)
                )
            )
        } else {
            choices <- c("All", order_filter_choices(unique(df_all[[col]])))
            div(class = "filters-item",
                tags$label(display),
                selectInput(ns(col), label = NULL, choices = choices)
            )
        }
    })

    filter_reset_button <- div(class = "filters-reset-row",
        actionButton(ns("reset_filters"), "Reset all filters", class = "reset-btn filters-reset-btn",
                     title = "Clear all filter selections")
    )

    div(class = "toolbar-filters",
        tags$span(class = "toolbar-section-label", "Filters"),
        div(class = "filters-grid", filter_items, filter_reset_button)
    )
}


mod_filter_server <- function(id, egm_data, reset_egm_trigger) {
    moduleServer(id, function(input, output, session) {

        filter_cols <- egm_definition$filter_dropdown_list
        cond_map    <- build_cond_map()

        # Collect all filter input values into a single reactive so a single
        # observeEvent can watch all of them without listing each by name.
        filter_values <- reactive({
            lapply(setNames(filter_cols, filter_cols), function(col) input[[col]])
        })

        # For each conditional spec: show/hide the child filter whenever its
        # parent changes.  When showing, rebuild choices from only the rows
        # that match the specific parent value just selected.
        for (spec in egm_definition$filter_conditional) {
            local({
                filter_col <- spec$filter
                parent_col <- spec$parent
                show_when  <- spec$show_when
                observeEvent(input[[parent_col]], {
                    parent_val  <- input[[parent_col]]
                    show_filter <- !is.null(parent_val) && parent_val %in% show_when
                    if (show_filter) {
                        df_cond     <- df_all[df_all[[parent_col]] == parent_val, ]
                        new_choices <- c("All", order_filter_choices(unique(df_cond[[filter_col]])))
                        updateSelectInput(session, filter_col,
                                          choices = new_choices, selected = "All")
                    } else {
                        updateSelectInput(session, filter_col, selected = "All")
                    }
                    session$sendCustomMessage("setFilterVisibility", list(
                        id   = session$ns(paste0(filter_col, "_wrapper")),
                        show = show_filter
                    ))
                }, ignoreInit = TRUE)
            })
        }

        observeEvent(input$reset_filters, {
            for (col in filter_cols) {
                updateSelectInput(session, col, selected = "All")
            }
        })

        # Re-run whenever any filter dropdown changes.
        # ignoreInit = TRUE prevents a spurious reset when the app first loads.
        observeEvent(filter_values(), {
            df_filter <- df_all

            for (col in filter_cols) {
                val <- input[[col]]

                # Skip a conditional child filter when its parent is not showing it.
                if (col %in% names(cond_map)) {
                    parent_col <- cond_map[[col]]$parent
                    show_when  <- cond_map[[col]]$show_when
                    if (is.null(input[[parent_col]]) || !input[[parent_col]] %in% show_when) next
                }

                if (!is.null(val) && val != "All") {
                    df_filter <- df_filter %>% filter(.data[[col]] == val)
                }
            }

            egm_data(create_egm_data(df_filter))
            reset_egm_trigger(reset_egm_trigger() + 1)
        }, ignoreInit = TRUE)
    })
}
