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


mod_filter_ui <- function(id) {
    ns <- NS(id)

    filter_cols    <- egm_definition$filter_dropdown_list
    filter_display <- egm_definition$filter_dropdown_list_display

    filter_items <- lapply(seq_along(filter_cols), function(i) {
        col     <- filter_cols[[i]]
        display <- filter_display[[i]]
        choices <- c("All", order_filter_choices(unique(df_all[[col]])))
        div(class = "filters-item",
            tags$label(display),
            selectInput(ns(col), label = NULL, choices = choices)
        )
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

        # Collect all filter input values into a single reactive so a single
        # observeEvent can watch all of them without listing each by name.
        filter_values <- reactive({
            lapply(setNames(filter_cols, filter_cols), function(col) input[[col]])
        })

        # Re-run whenever any filter dropdown changes.
        # ignoreInit = TRUE prevents a spurious reset when the app first loads.
        observeEvent(input$reset_filters, {
            for (col in filter_cols) {
                updateSelectInput(session, col, selected = "All")
            }
        })

        observeEvent(filter_values(), {
            df_filter <- df_all

            for (col in filter_cols) {
                val <- input[[col]]
                if (!is.null(val) && val != "All") {
                    df_filter <- df_filter %>% filter(.data[[col]] == val)
                }
            }

            egm_data(create_egm_data(df_filter))
            reset_egm_trigger(reset_egm_trigger() + 1)
        }, ignoreInit = TRUE)
    })
}