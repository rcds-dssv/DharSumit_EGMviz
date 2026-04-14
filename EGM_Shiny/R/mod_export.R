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
#   2. Server validates papers and, for citation formats, fetches all citations
#      from the API before triggering the download.
#   3. If any papers could not be exported (missing DOI or API failure),
#      show_export_modal() is called.  If nothing was exported the download
#      is aborted; otherwise it proceeds alongside the modal.
#   4. downloadHandler writes the pre-fetched content (citations) or formats
#      the local data (CSV / Excel / JSON) and serves the file.
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
    apa       = list(label = "APA Format (.txt)",      ext = "_apa.txt",
                     accept = "text/bibliography; style=apa; locale=en-US"),
    vancouver = list(label = "Vancouver Format (.txt)", ext = "_vancouver.txt",
                     accept = "text/bibliography; style=vancouver; locale=en-US"),
    ama       = list(label = "AMA Format (.txt)",       ext = "_ama.txt",
                     accept = "text/bibliography; style=american-medical-association; locale=en-US"),
    chicago   = list(label = "Chicago Format (.txt)",   ext = "_chicago.txt",
                     accept = "text/bibliography; style=chicago-author-date; locale=en-US"),
    bib       = list(label = "BibTeX (.bib)",           ext = ".bib",
                     accept = "application/x-bibtex"),
    ris       = list(label = "RIS (.ris)",              ext = ".ris",
                     accept = "application/x-research-info-systems")
)

# Numbered citation styles: the API always returns "1." when fetching one DOI
# at a time.  Entries for these formats are renumbered after fetching.
NUMBERED_FORMATS <- c("vancouver", "ama")


# =============================================================================
# Data helpers
# =============================================================================

# Returns df limited to the columns relevant for data exports.
filter_export_cols <- function(df) {
    keep <- unique(c(
        egm_definition$paper_citation_columns,
        egm_definition$x_column,
        egm_definition$y_column,
        egm_definition$paper_meta_columns
    ))
    df[, intersect(keep, names(df)), drop = FALSE]
}

# Formats a single-row df as a plain-text citation line for use in modals.
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


# =============================================================================
# API fetch helpers
# =============================================================================

# Fetches a formatted citation for a single DOI via Crossref content negotiation.
# Returns list(content = <string>, error = NULL) on success, or
#         list(content = NULL,    error = <string>) on any failure.
fetch_doi_citation <- function(doi, accept_type) {
    if (is.null(doi) || is.na(doi) || nchar(trimws(doi)) == 0) {
        return(list(content = NULL, error = "empty DOI"))
    }
    url <- paste0("https://doi.org/", trimws(doi))
    tryCatch({
        resp   <- httr::GET(url, httr::add_headers(Accept = accept_type), httr::timeout(8))
        status <- httr::status_code(resp)
        if (status != 200) {
            return(list(content = NULL, error = sprintf("HTTP %d", status)))
        }
        ct <- httr::headers(resp)[["content-type"]]
        if (!is.null(ct) && grepl("text/html", ct, fixed = TRUE)) {
            return(list(content = NULL, error = "API returned HTML (DOI may not support content negotiation)"))
        }
        content <- httr::content(resp, as = "text", encoding = "UTF-8")
        if (nchar(trimws(content)) == 0) {
            return(list(content = NULL, error = "API returned an empty response"))
        }
        list(content = content, error = NULL)
    }, error = function(e) {
        list(content = NULL, error = conditionMessage(e))
    })
}

# Fetches citations for all rows in df.
# Returns list(
#   entries   = character vector of successfully fetched citation strings
#              (trimmed, one element per paper),
#   failed_df = data frame of rows that could not be fetched (with $api_error
#              column), or NULL if all succeeded
# )
fetch_all_citations <- function(df, accept_type) {
    doi_col        <- egm_definition$paper_doi_column
    entries        <- character(0)
    failed_indices <- integer(0)
    failed_errors  <- character(0)

    for (i in seq_len(nrow(df))) {
        # Polite rate limit: brief pause every 10 requests.
        if (i > 1 && (i - 1) %% 10 == 0) Sys.sleep(0.5)

        result <- fetch_doi_citation(df[[doi_col]][i], accept_type)
        if (!is.null(result$content)) {
            entries <- c(entries, trimws(result$content))
        } else {
            failed_indices <- c(failed_indices, i)
            failed_errors  <- c(failed_errors,
                                if (!is.null(result$error)) result$error else "unknown error")
        }
    }

    failed_df <- if (length(failed_indices) > 0) {
        fd            <- df[failed_indices, , drop = FALSE]
        fd$api_error  <- failed_errors
        fd
    } else NULL

    list(entries = entries, failed_df = failed_df)
}


# =============================================================================
# Export modal
# =============================================================================

# Shows a summary modal whenever any papers could not be exported.
#   n_exported  — number of papers that were successfully exported
#   failed_df   — data frame of papers that could not be exported (any reason)
#   api_errors  — character vector of unique API error strings (may be empty)
# Title reflects total failure vs partial success.
show_export_modal <- function(n_exported, failed_df, api_errors = character(0)) {
    n_failed     <- nrow(failed_df)
    failed_items <- lapply(seq_len(n_failed), function(i) {
        tags$li(format_modal_citation(failed_df[i, , drop = FALSE]))
    })

    showModal(modalDialog(
        title = if (n_exported == 0) "Export Failed" else "Export Warning",
        tagList(
            tags$p(sprintf("Number of papers exported = %d",              n_exported)),
            tags$p(sprintf("Number of papers that could not be exported = %d", n_failed)),
            tags$ul(failed_items),
            if (length(api_errors) > 0) tagList(
                tags$p("API errors encountered:"),
                tags$ul(lapply(api_errors, tags$li))
            )
        ),
        footer    = modalButton("OK"),
        easyClose = TRUE
    ))
}


# =============================================================================
# Shiny module
# =============================================================================

mod_export_citations_ui <- function(id) {
    ns <- NS(id)
    tagList(
        # Visible panel: rendered only when papers are selected.
        uiOutput(ns("export_panel")),

        # The actual download endpoint must live OUTSIDE renderUI and must NOT
        # use display:none.  Shiny suspends output-binding updates for
        # display:none elements (jQuery's :visible check), so the
        # shiny-download-link binding never receives its href and clicking it
        # navigates to the current page instead of serving a file.
        # position:fixed off-screen keeps it invisible without hiding it from
        # Shiny's binding machinery.
        tags$div(
            style = "position:fixed; top:-200px; left:-200px; width:0; height:0; overflow:hidden; pointer-events:none;",
            downloadButton(ns("download"), "")
        ),

        # Processing overlay: shown immediately by a JS click handler when a
        # citation-format download starts.  Closed by the triggerDownload or
        # setButtonDisabled(false) JS handlers once R finishes.
        # The progress bar is an indeterminate CSS animation — R's WebSocket
        # messages are batched until the observer returns, so real-time
        # percentage updates are not possible in synchronous Shiny.
        tags$div(
            class = "modal-overlay export-processing-overlay",
            tags$div(
                class = "modal-content export-processing-content",
                div(
                    class = "modal-body export-processing-body",
                    tags$p(class = "export-processing-title",
                           "Fetching citations\u2026"),
                    div(class = "export-progress-track",
                        div(class = "export-progress-bar")),
                    tags$p(class = "export-processing-note",
                           "Please wait. The app is gathering your citations.  This box will close automatically when the download begins.")                )
            )
        )
    )
}


mod_export_citations_server <- function(id, clicked_df, clicked_info) {
    moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Holds the subset of selected papers that will actually be downloaded.
        download_df <- reactiveVal(NULL)

        # Holds pre-fetched citation text for citation formats (NULL for data formats).
        # Set in check_download observer; read in downloadHandler.
        download_content <- reactiveVal(NULL)

        # Holds the chosen format key at the moment Download was clicked.
        # downloadHandler reads this instead of input$export_format because
        # dynamic inputs created inside renderUI can be NULL when the download
        # HTTP request fires, causing req() to fail and Shiny to serve the app
        # HTML page as the downloaded file.
        download_fmt <- reactiveVal(NULL)

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
                            label    = NULL,
                            choices  = fmt_choices,
                            selected = "csv"
                        ),
                        # Visible button: validates, fetches (citation formats), triggers download.
                        actionButton(ns("check_download"), "Download",
                                     class = "reset-btn export-download-btn")
                    )
                )
            )
        })

        # When the user clicks "Download":
        #   - Data formats: prepare the df and trigger the download immediately.
        #   - Citation formats:
        #       1. Split papers into those with DOIs and those without.
        #       2. Fetch citations from the API for papers that have DOIs.
        #       3. Combine all failures (missing DOI + API failures).
        #       4. Show the summary modal if anything failed.
        #       5. Abort if nothing was exported; otherwise trigger the download.
        observeEvent(input$check_download, {
            req(clicked_df(), input$export_format)

            # Disable the button for the duration of this handler so rapid
            # re-clicks don't queue duplicate API fetches.  on.exit() ensures
            # the button is always re-enabled, even on req() failure or error.
            session$sendCustomMessage("setButtonDisabled",
                                      list(id = ns("check_download"), disabled = TRUE))
            on.exit(session$sendCustomMessage("setButtonDisabled",
                                              list(id = ns("check_download"), disabled = FALSE)),
                    add = TRUE)

            df  <- clicked_df()
            fmt <- input$export_format
            download_fmt(fmt)

            if (!(fmt %in% names(CITATION_FORMATS))) {
                download_df(filter_export_cols(df))
                download_content(NULL)
            } else {
                doi_col   <- egm_definition$paper_doi_column
                has_doi   <- !is.na(df[[doi_col]]) &
                             nchar(trimws(as.character(df[[doi_col]]))) > 0
                ok_df     <- df[has_doi,  , drop = FALSE]
                no_doi_df <- df[!has_doi, , drop = FALSE]

                # Fetch citations for papers that have DOIs.
                fetch_result <- list(entries = character(0), failed_df = NULL)
                if (nrow(ok_df) > 0) {
                    fetch_result <- fetch_all_citations(ok_df, CITATION_FORMATS[[fmt]]$accept)
                }

                entries    <- fetch_result$entries
                n_exported <- length(entries)

                # Numbered styles (Vancouver, AMA) always return "1." when
                # fetching one DOI at a time.  Renumber sequentially here.
                if (fmt %in% NUMBERED_FORMATS && n_exported > 0) {
                    entries <- vapply(seq_along(entries), function(i) {
                        sub("^\\d+\\.\\s*", paste0(i, ". "), entries[[i]])
                    }, character(1))
                }

                # Combine all papers that could not be exported.
                failed_df  <- dplyr::bind_rows(no_doi_df, fetch_result$failed_df)
                api_errors <- if (!is.null(fetch_result$failed_df))
                                  unique(fetch_result$failed_df$api_error)
                              else character(0)

                if (nrow(failed_df) > 0) {
                    show_export_modal(n_exported, failed_df, api_errors)
                }

                if (n_exported == 0) return()

                download_df(ok_df)
                download_content(paste(entries, collapse = "\n\n"))
            }

            # Trigger the hidden downloadButton.
            session$sendCustomMessage("triggerDownload", ns("download"))
        })

        output$download <- downloadHandler(
            filename = function() {
                fmt <- isolate(download_fmt())
                req(fmt)
                ext <- if (fmt %in% names(CITATION_FORMATS)) {
                    CITATION_FORMATS[[fmt]]$ext
                } else {
                    switch(fmt, csv = ".csv", xlsx = ".xlsx", json = ".json")
                }
                paste0("selected_papers", ext)
            },
            content = function(file) {
                fmt <- isolate(download_fmt())
                req(fmt)

                if (fmt %in% names(CITATION_FORMATS)) {
                    req(download_content())
                    writeLines(download_content(), file)
                } else {
                    req(download_df(), nrow(download_df()) > 0)
                    df <- download_df()
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