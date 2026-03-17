mod_export_citations_ui <- function(id) {
    ns <- NS(id)
    actionButton(ns("export_citations"), class = "reset-btn",  "Export")
}

mod_export_citations_server <- function(id) {
    moduleServer(id, function(input, output, session) {
        observeEvent(input$export_citations, {
            print("export clicked")
            # add actual export            
        })
    })

}
