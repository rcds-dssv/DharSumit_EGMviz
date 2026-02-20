mod_filter_ui <- function(id) {
    ns <- NS(id)
    div(
        class = "filters-group",
        div(
            class = "filters-item",
            tags$label("Gender Reported"),
            selectInput(ns("GenderReported"), label = NULL, choices = c("Any", "Yes", "No"))
        ),
        div(
            class = "filters-item",
            tags$label("Ethnicity Reported"),
            selectInput(ns("EthnicityReported"), label = NULL, choices = c("Any", "Yes", "No"))
        ),
        div(
            class = "filters-item",
            tags$label("Race Reported"),
            selectInput(ns("RaceReported"), label = NULL, choices = c("Any", "Yes", "No"))
        ),
        div(
            class = "filters-item",
            tags$label("US Origin"),
            selectInput(ns("USOrigin"), label = NULL, choices = c("Any", "Yes", "No"))
        )
    )

    
}

mod_filter_server <- function(id, egm_data, reset_egm_trigger) {
    moduleServer(id, function(input, output, session) {

        observeEvent(c(input$GenderReported, input$EthnicityReported, input$RaceReported, input$USOrigin), {

            # default behavior (if all filters are Any)
            df_filter <- df_all

            # apply the filter(s)
            if (input$GenderReported != "Any") {
                df_filter <- df_filter %>% filter(GenderReported == input$GenderReported)
            } 
            if (input$EthnicityReported != "Any") {
                df_filter <- df_filter %>% filter(EthnicityReported == input$EthnicityReported)
            } 
            if (input$RaceReported != "Any") {
                df_filter <- df_filter %>% filter(RaceReported == input$RaceReported)
            } 
            if (input$USOrigin != "Any") {
                df_filter <- df_filter %>% filter(USOrigin == input$USOrigin)
            } 
            
            # update the database
            new_egm_data <- create_egm_data(df_filter)
            egm_data(new_egm_data)

            # reset the table
            reset_egm_trigger(reset_egm_trigger() + 1)


        }, ignoreInit = TRUE)
    })
}