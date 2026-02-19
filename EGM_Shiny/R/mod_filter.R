mod_filter_ui <- function(id) {
    ns <- NS(id)
    div(
        class = "filters-item",
        tags$label("Gender Reported"),
        selectInput(ns("GenderReported"), label = NULL, choices = c("Any", "Yes", "No"))
    )
}

mod_filter_server <- function(id, egm_data, reset_egm_trigger) {
    moduleServer(id, function(input, output, session) {

        # Currently only handles one filter, but I will make this more general later
        observeEvent(input$GenderReported, {

            # default behavior (if all filters are Any)
            df_filter <- df_all

            # apply the filter(s)
            if (input$GenderReported != "Any") {
                df_filter <- df_filter %>% filter(GenderReported == input$GenderReported)
            } 

            
            # update the database
            new_egm_data <- create_egm_data(df_filter)
            egm_data(new_egm_data)

            # reset the table
            reset_egm_trigger(reset_egm_trigger() + 1)


        }, ignoreInit = TRUE)
    })
}