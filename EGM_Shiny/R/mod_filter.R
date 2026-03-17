# =============================================================================
# mod_filter — demographic filter controls
#
# Provides four Yes / No / Any dropdowns (Gender, Ethnicity, Race, US Origin).
# When any filter changes, the module re-filters df_all (defined in global.R),
# rebuilds egm_data, and increments reset_egm_trigger to clear the table.
# =============================================================================


mod_filter_ui <- function(id) {
    ns <- NS(id)
    tags$details(
        class = "filters-details dropdown-details",
        tags$summary("Filters"),
        div(
            class = "filters-dropdown",
            div(class = "filters-item",
                tags$label("Gender Reported"),
                selectInput(ns("GenderReported"), label = NULL, choices = c("Any", "Yes", "No"))
            ),
            div(class = "filters-item",
                tags$label("Ethnicity Reported"),
                selectInput(ns("EthnicityReported"), label = NULL, choices = c("Any", "Yes", "No"))
            ),
            div(class = "filters-item",
                tags$label("Race Reported"),
                selectInput(ns("RaceReported"), label = NULL, choices = c("Any", "Yes", "No"))
            ),
            div(class = "filters-item",
                tags$label("US Origin"),
                selectInput(ns("USOrigin"), label = NULL, choices = c("Any", "Yes", "No"))
            )
        )
    )
}


mod_filter_server <- function(id, egm_data, reset_egm_trigger) {
    moduleServer(id, function(input, output, session) {

        # Re-run whenever any filter dropdown changes.
        # ignoreInit = TRUE prevents a spurious reset when the app first loads.
        observeEvent(
            c(input$GenderReported, input$EthnicityReported, input$RaceReported, input$USOrigin),
            {
                # Start with the full dataset (df_all is the global from global.R)
                df_filter <- df_all

                # Apply only the filters that are not set to "Any"
                if (input$GenderReported    != "Any") df_filter <- df_filter %>% filter(GenderReported    == input$GenderReported)
                if (input$EthnicityReported != "Any") df_filter <- df_filter %>% filter(EthnicityReported == input$EthnicityReported)
                if (input$RaceReported      != "Any") df_filter <- df_filter %>% filter(RaceReported      == input$RaceReported)
                if (input$USOrigin          != "Any") df_filter <- df_filter %>% filter(USOrigin          == input$USOrigin)

                egm_data(create_egm_data(df_filter))

                # Trigger a full plot + table reset so stale selections are cleared
                reset_egm_trigger(reset_egm_trigger() + 1)
            },
            ignoreInit = TRUE
        )
    })
}