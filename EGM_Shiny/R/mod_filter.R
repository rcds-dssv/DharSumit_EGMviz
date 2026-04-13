# =============================================================================
# mod_filter — demographic filter controls
#
# Reads filter_dropdown_list and filter_dropdown_list_display from
# egm_definition (global.R) to programmatically generate one dropdown per
# filter column.  Choices are "Any" plus every unique value in that column
# (NA values have already been replaced with "None Given" in global.R).
#
# When any filter changes the module re-filters df_all, rebuilds egm_data,
# and increments reset_egm_trigger to clear the table.
# =============================================================================


mod_filter_ui <- function(id) {
    ns <- NS(id)

    filter_cols    <- egm_definition$filter_dropdown_list
    filter_display <- egm_definition$filter_dropdown_list_display

    filter_items <- lapply(seq_along(filter_cols), function(i) {
        col     <- filter_cols[[i]]
        display <- filter_display[[i]]
        choices <- c("Any", sort(unique(df_all[[col]])))
        div(class = "filters-item",
            tags$label(display),
            selectInput(ns(col), label = NULL, choices = choices)
        )
    })

    tags$details(
        class = "filters-details dropdown-details",
        tags$summary("Filters"),
        div(class = "filters-dropdown", filter_items)
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
        observeEvent(filter_values(), {
            df_filter <- df_all

            for (col in filter_cols) {
                val <- input[[col]]
                if (!is.null(val) && val != "Any") {
                    df_filter <- df_filter %>% filter(.data[[col]] == val)
                }
            }

            egm_data(create_egm_data(df_filter))
            reset_egm_trigger(reset_egm_trigger() + 1)
        }, ignoreInit = TRUE)
    })
}