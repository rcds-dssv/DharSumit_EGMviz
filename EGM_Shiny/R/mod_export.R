# =============================================================================
# mod_export_citations — citation export (placeholder)
#
# TODO: implement actual export logic (e.g. download a .bib or .csv file).
# =============================================================================


mod_export_citations_ui <- function(id) {
    ns <- NS(id)
    actionButton(ns("export_citations"), "Export", class = "reset-btn")
}


mod_export_citations_server <- function(id) {
    moduleServer(id, function(input, output, session) {
        observeEvent(input$export_citations, {
            # TODO: add export logic here
        })
    })
}