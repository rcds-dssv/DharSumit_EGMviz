# =============================================================================
# mod_export — citation and data export
#
# Provides a dropdown panel (shown only when papers are selected) that lets
# the user choose an export format and download the selected papers.
#
# Data formats (CSV / Excel / JSON) use local data.
# Citation formats (APA / Vancouver / AMA / Chicago / Harvard / BibTeX / RIS)
# are fetched from the Crossref DOI content-negotiation API:
#   https://doi.org/{doi}  Accept: <format-mime-type>
#
# Flow:
#   1. User picks format, clicks "Download" (an actionButton).
#   2. Server filters out papers with no DOI (for citation formats), stores the
#      exportable subset in download_df, then sends a JS message that
#      programmatically clicks the hidden downloadButton.
#   3. If any papers were dropped, a modal listing them appears alongside the
#      download (the user closes it with OK).
#   4. downloadHandler fetches or formats the data and serves the file.
#
# Public interface:
#   mod_export_citations_ui(id)
#   mod_export_citations_server(id, clicked_df, clicked_info)
# =============================================================================


# =============================================================================
# Citation format configuration
# Maps format keys → (label shown in selectInput, file extension, HTTP Accept)
# =============================================================================

CITATION_FORMATS <- list(
    apa       = list(label = "APA Text (.txt)",      ext = "_apa.txt",
                     accept = "text/bibliography; style=apa; locale=en-US"),
    vancouver = list(label = "Vancouver Text (.txt)", ext = "_vancouver.txt",
                     accept = "text/bibliography; style=vancouver; locale=en-US"),
    ama       = list(label = "AMA Text (.txt)",       ext = "_ama.txt",
                     accept = "text/bibliography; style=american-medical-association; locale=en-US"),
    chicago   = list(label = "Chicago Text (.txt)",   ext = "_chicago.txt",
                     accept = "text/bibliography; style=chicago-author-date; locale=en-US"),
    harvard   = list(label = "Harvard Text (.txt)",   ext = "_harvard.txt",
                     accept = "text/bibliography; style=harvard1; locale=en-US"),
    bib       = list(label = "BibTeX (.bib)",         ext = ".bib",
                     accept = "application/x-bibtex"),
    ris       = list(label = "RIS (.ris)",            ext = ".ris",
                     accept = "application/x-research-info-systems")
)


# =============================================================================
# Helpers
# =============================================================================

# Returns df limited to the columns relevant for data exports.
filter_export_cols <- function(df) {
    keep <- unique(c(
        egm_definition$x_column,
        egm_definition$y_column,
        egm_definition$paper_citation_columns,
        egm_definition$paper_meta_columns
    ))
    df[, intersect(keep, names(df)), drop = FALSE]
}

# Formats a single-row df as a plain-text citation line for the missing-DOI
# modal, using the same citation columns and display labels as the paper card.
format_modal_citation <- function(row) {
    title_col    <- egm_definition$paper_title_column
    cite_cols    <- egm_definition$paper_citation_columns
    cite_display <- egm_definition$paper_citation_columns_display

    is_blank <- function(v) is.null(v) || is.na(v) || nchar(trimws(as.character(v))) == 0

    title <- if (!is.null(title_col) && title_col %in% names(row) && !is_blank(row[[title_col]]))
        as.character(row[[title_col]]) else NULL

    cite_parts <- Filter(Negate(is.null), lapply(seq_along(cite_cols), function(j) {
        col <- cite_cols[[j]]
        lbl <- cite_display[[j]]
        if (!(col %in% names(row)) || is_blank(row[[col]])) return(NULL)
        val <- as.character(row[[col]])
        if (nchar(lbl) == 0) val else paste(lbl, val)
    }))
    citation <- if (length(cite_parts) > 0) paste(cite_parts, collapse = ", ") else NULL

    paste(Filter(Negate(is.null), c(title, citation)), collapse = ". ")
}

# Fetches a formatted citation for a single DOI via Crossref content negotiation.
# Returns the response body as a character string, or NULL on any failure.
fetch_doi_citation <- function(doi, accept_type) {
    if (is.null(doi) || is.na(doi) || nchar(trimws(doi)) == 0) return(NULL)
    url <- paste0("https://doi.org/", trimws(doi))
    tryCatch({
        resp <- httr::GET(
            url,
            httr::add_headers(Accept = accept_type),
            httr::timeout(15)
        )
        if (httr::status_code(resp) != 200) return(NULL)
        # Discard HTML responses (e.g. journal landing pages that ignore Accept)
        ct <- httr::headers(resp)[["content-type"]]
        if (!is.null(ct) && grepl("text/html", ct, fixed = TRUE)) return(NULL)
        content <- httr::content(resp, as = "text", encoding = "UTF-8")
        if (nchar(trimws(content)) == 0) return(NULL)
        content
    }, error = function(e) NULL)
}

# Fetches citations for all rows in df via the API and writes them to file.
# Entries are separated by a blank line for readability across all formats.
export_via_api <- function(df, file, accept_type) {
    doi_col <- egm_definition$paper_doi_column
    entries <- lapply(seq_len(nrow(df)), function(i) {
        fetch_doi_citation(df[[doi_col]][i], accept_type)
    })
    entries <- Filter(Negate(is.null), entries)
    if (length(entries) == 0) {
        writeLines("No citations could be retrieved.", file)
    } else {
        writeLines(paste(trimws(entries), collapse = "\n\n"), file)
    }
}


# =============================================================================
# Shiny module
# =============================================================================

mod_export_citations_ui <- function(id) {
    ns <- NS(id)
    uiOutput(ns("export_panel"))
}


mod_export_citations_server <- function(id, clicked_df, clicked_info) {
    moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Holds the subset of selected papers that will actually be downloaded.
        # Set in check_download observer; read in downloadHandler.
        download_df <- reactiveVal(NULL)

        # Panel is rendered only when papers are selected.
        output$export_panel <- renderUI({
            if (is.null(clicked_info())) return(NULL)

            fmt_choices <- c(
                "CSV (.csv)"      = "csv",
                "Excel (.xlsx)"   = "xlsx",
                "JSON (.json)"    = "json",
                # Citation formats follow
                setNames(names(CITATION_FORMATS),
                         vapply(CITATION_FORMATS, `[[`, character(1), "label"))
            )

            tagList(
                tags$details(
                    class = "export-details dropdown-details",
                    tags$summary("Export"),
                    div(class = "export-dropdown",
                        selectInput(ns("export_format"),
                            label   = NULL,
                            choices = fmt_choices,
                            selected = "csv"
                        ),
                        # Visible button: validates DOIs and triggers the download.
                        actionButton(ns("check_download"), "Download",
                                     class = "reset-btn export-download-btn"),
                        # Hidden downloadButton: the actual file-serving endpoint.
                        tags$span(style = "display:none;",
                            downloadButton(ns("download"), ""))
                    )
                )
            )
        })

        # When the user clicks "Download":
        #   1. For citation formats, filter to papers with DOIs and store in download_df.
        #   2. Trigger the hidden downloadButton via a JS message.
        #   3. If papers were dropped, show the missing-DOI modal.
        observeEvent(input$check_download, {
            req(clicked_df(), input$export_format)
            df  <- clicked_df()
            fmt <- input$export_format

            is_citation <- fmt %in% names(CITATION_FORMATS)

            if (!is_citation) {
                download_df(filter_export_cols(df))
            } else {
                doi_col  <- egm_definition$paper_doi_column
                has_doi  <- !is.na(df[[doi_col]]) &
                            nchar(trimws(as.character(df[[doi_col]]))) > 0
                download_df(df[has_doi, , drop = FALSE])

                if (any(!has_doi)) {
                    missing_df <- df[!has_doi, , drop = FALSE]
                    n_missing  <- nrow(missing_df)
                    n_total    <- nrow(df)
                    n_ok       <- n_total - n_missing

                    missing_items <- lapply(seq_len(nrow(missing_df)), function(i) {
                        tags$li(format_modal_citation(missing_df[i, , drop = FALSE]))
                    })

                    showModal(modalDialog(
                        title = "Some papers could not be exported",
                        tags$p(sprintf(
                            "%d of %d selected paper%s %s no DOI and could not be exported:",
                            n_missing, n_total,
                            if (n_missing == 1) "" else "s",
                            if (n_missing == 1) "has" else "have"
                        )),
                        tags$ul(missing_items),
                        if (n_ok > 0)
                            tags$p(sprintf(
                                "The remaining %d paper%s %s exported.",
                                n_ok,
                                if (n_ok == 1) "" else "s",
                                if (n_ok == 1) "was" else "were"
                            )),
                        footer = modalButton("OK"),
                        easyClose = TRUE
                    ))
                }
            }

            # Trigger download only if there are papers to export.
            if (!is.null(download_df()) && nrow(download_df()) > 0) {
                session$sendCustomMessage("triggerDownload", ns("download"))
            }
        })

        output$download <- downloadHandler(
            filename = function() {
                req(input$export_format)
                fmt <- input$export_format
                ext <- if (fmt %in% names(CITATION_FORMATS)) {
                    CITATION_FORMATS[[fmt]]$ext
                } else {
                    switch(fmt, csv = ".csv", xlsx = ".xlsx", json = ".json")
                }
                paste0("selected_papers", ext)
            },
            content = function(file) {
                req(download_df(), nrow(download_df()) > 0, input$export_format)
                df  <- download_df()
                fmt <- input$export_format

                if (fmt %in% names(CITATION_FORMATS)) {
                    export_via_api(df, file, CITATION_FORMATS[[fmt]]$accept)
                } else {
                    switch(fmt,
                        csv  = write.csv(df, file, row.names = FALSE),
                        xlsx = writexl::write_xlsx(df, file),
                        json = writeLines(
                                   jsonlite::toJSON(df, pretty = TRUE, na = "null"),
                                   file
                               )
                    )
                }
            }
        )
    })
}