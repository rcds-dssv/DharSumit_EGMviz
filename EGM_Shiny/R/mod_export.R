# =============================================================================
# mod_export — citation and data export
#
# Provides a dropdown panel (shown only when papers are selected) that lets
# the user choose an export format and download the selected papers.
#
# Data formats (CSV / Excel / JSON) use local data directly.
# Citation formats (APA / AMA / Chicago / BibTeX / RIS) are
# generated locally from the columns defined in egm_definition — no API calls.
# Missing fields are silently omitted; DOI is optional throughout.
#
# Public interface:
#   mod_export_citations_ui(id)
#   mod_export_citations_server(id, clicked_df, clicked_info)
# =============================================================================


# =============================================================================
# Citation format configuration
# =============================================================================

CITATION_FORMATS <- list(
    apa       = list(label = "APA Format (.txt)",        ext = "_apa.txt"),
    ama       = list(label = "AMA Format (.txt)",        ext = "_ama.txt"),
    chicago   = list(label = "Chicago Format (.txt)",    ext = "_chicago.txt"),
    bib       = list(label = "BibTeX (.bib)",            ext = ".bib"),
    ris       = list(label = "RIS (.ris)",               ext = ".ris")
)

# Formats that prepend sequential numbers (1., 2., ...) to each entry.
NUMBERED_FORMATS <- c("ama")


# =============================================================================
# Data helpers
# =============================================================================

filter_export_cols <- function(df) {
    keep <- unique(c(
        egm_definition$paper_citation_columns,
        egm_definition$x_column,
        egm_definition$y_column,
        egm_definition$paper_meta_columns
    ))
    df[, intersect(keep, names(df)), drop = FALSE]
}


# =============================================================================
# Citation field helpers
# =============================================================================

# Safely extract a field from a single-row data frame by BibTeX key name.
# Returns `default` when the column is absent, NA, or whitespace-only.
cite_val <- function(row, bib_key, default = "") {
    col <- bib_col_name(bib_key)
    if (is.na(col) || !(col %in% names(row))) return(default)
    v <- row[[col]]
    if (is.null(v) || length(v) == 0 || is.na(v) ||
        nchar(trimws(as.character(v))) == 0) return(default)
    trimws(as.character(v))
}

# Strip any leading URL prefix from a DOI value so only the raw DOI remains.
clean_doi <- function(doi) {
    sub("^https?://(dx\\.)?doi\\.org/", "", doi, ignore.case = TRUE)
}


# =============================================================================
# Per-format citation functions
# Each takes a single-row data frame and returns a character string.
# =============================================================================

format_apa <- function(row) {
    authors <- cite_val(row, "author", "[Unknown Author]")
    year    <- cite_val(row, "year",   "n.d.")
    title   <- cite_val(row, "title",  "[Untitled]")
    journal <- cite_val(row, "journal")
    volume  <- cite_val(row, "volume")
    number  <- cite_val(row, "number")
    pages   <- cite_val(row, "pages")
    doi     <- clean_doi(cite_val(row, "doi"))

    vol_str  <- if (nchar(volume) > 0 && nchar(number) > 0) paste0(volume, "(", number, ")")
                else volume
    location <- paste(Filter(nchar, c(journal, vol_str, pages)), collapse = ", ")
    doi_str  <- if (nchar(doi) > 0) paste0("https://doi.org/", doi) else ""

    parts <- Filter(nchar, c(
        paste0(authors, " (", year, "). ", title, "."),
        if (nchar(location) > 0) paste0(location, "."),
        doi_str
    ))
    paste(parts, collapse = " ")
}

# Note: AMA 11th ed. structure matches Vancouver; differences (journal abbreviations,
# author name format) depend on source data.
format_ama <- function(row) {
    authors <- cite_val(row, "author", "[Unknown Author]")
    year    <- cite_val(row, "year")
    title   <- cite_val(row, "title",  "[Untitled]")
    journal <- cite_val(row, "journal")
    volume  <- cite_val(row, "volume")
    number  <- cite_val(row, "number")
    pages   <- cite_val(row, "pages")
    doi     <- clean_doi(cite_val(row, "doi"))

    # Build journal location block: Year;Volume(Issue):Pages
    loc <- year
    if (nchar(volume) > 0) {
        loc <- paste0(loc, if (nchar(loc) > 0) ";" else "", volume)
        if (nchar(number) > 0) loc <- paste0(loc, "(", number, ")")
    }
    if (nchar(pages) > 0) loc <- paste0(loc, ":", pages)
    doi_str <- if (nchar(doi) > 0) paste0("doi:", doi) else ""

    parts <- Filter(nchar, c(
        paste0(authors, "."),
        paste0(title, "."),
        if (nchar(journal) > 0) paste0(journal, "."),
        if (nchar(loc)     > 0) paste0(loc, "."),
        doi_str
    ))
    paste(parts, collapse = " ")
}

format_chicago <- function(row) {
    authors <- cite_val(row, "author", "[Unknown Author]")
    year    <- cite_val(row, "year",   "n.d.")
    title   <- cite_val(row, "title",  "[Untitled]")
    journal <- cite_val(row, "journal")
    volume  <- cite_val(row, "volume")
    number  <- cite_val(row, "number")
    pages   <- cite_val(row, "pages")
    doi     <- clean_doi(cite_val(row, "doi"))

    vol_issue <- if (nchar(volume) > 0 && nchar(number) > 0) paste0(volume, " (", number, ")")
                 else volume
    location  <- paste(Filter(nchar, c(journal, vol_issue, pages)), collapse = ": ")
    doi_str   <- if (nchar(doi) > 0) paste0("https://doi.org/", doi) else ""

    parts <- Filter(nchar, c(
        paste0(authors, ". ", year, ". \"", title, ".\""),
        if (nchar(location) > 0) paste0(location, "."),
        doi_str
    ))
    paste(parts, collapse = " ")
}

format_bibtex <- function(row) {
    authors <- cite_val(row, "author")
    year    <- cite_val(row, "year")
    title   <- cite_val(row, "title")
    journal <- cite_val(row, "journal")
    volume  <- cite_val(row, "volume")
    number  <- cite_val(row, "number")
    pages   <- cite_val(row, "pages")
    doi     <- clean_doi(cite_val(row, "doi"))

    # Cite key: sanitized first token of authors + year
    key_base <- gsub("[^[:alnum:]]", "", sub("[^[:alnum:]].*", "", authors))
    if (nchar(key_base) == 0) key_base <- "unknown"
    key <- paste0(tolower(key_base), year)

    fields <- list(author = authors, title = title, journal = journal,
                   year = year, volume = volume, number = number,
                   pages = pages, doi = doi)
    field_lines <- Filter(nchar, vapply(names(fields), function(k) {
        v <- fields[[k]]
        if (nchar(v) == 0) "" else paste0("  ", k, " = {", v, "}")
    }, character(1)))

    paste0("@article{", key, ",\n", paste(field_lines, collapse = ",\n"), "\n}")
}

format_ris <- function(row) {
    authors <- cite_val(row, "author")
    year    <- cite_val(row, "year")
    title   <- cite_val(row, "title")
    journal <- cite_val(row, "journal")
    volume  <- cite_val(row, "volume")
    number  <- cite_val(row, "number")
    pages   <- cite_val(row, "pages")
    doi     <- clean_doi(cite_val(row, "doi"))

    # Split "123-145" into SP/EP; treat unsplit pages as SP only
    pages_split <- if (nchar(pages) > 0 && grepl("-", pages, fixed = TRUE))
                       strsplit(pages, "-", fixed = TRUE)[[1]]
                   else c(pages, "")
    sp <- trimws(pages_split[1])
    ep <- if (length(pages_split) >= 2) trimws(pages_split[2]) else ""

    lines <- "TY  - JOUR"
    if (nchar(authors) > 0) lines <- c(lines, paste0("AU  - ", authors))
    if (nchar(title)   > 0) lines <- c(lines, paste0("TI  - ", title))
    if (nchar(journal) > 0) lines <- c(lines, paste0("JO  - ", journal))
    if (nchar(year)    > 0) lines <- c(lines, paste0("PY  - ", year))
    if (nchar(volume)  > 0) lines <- c(lines, paste0("VL  - ", volume))
    if (nchar(number)  > 0) lines <- c(lines, paste0("IS  - ", number))
    if (nchar(sp)      > 0) lines <- c(lines, paste0("SP  - ", sp))
    if (nchar(ep)      > 0) lines <- c(lines, paste0("EP  - ", ep))
    if (nchar(doi)     > 0) lines <- c(lines, paste0("DO  - ", doi))
    lines <- c(lines, "ER  - ")
    paste(lines, collapse = "\n")
}


# =============================================================================
# Format dispatcher
# =============================================================================

format_all_citations <- function(df, fmt) {
    fn <- switch(fmt,
        apa       = format_apa,
        ama       = format_ama,
        chicago   = format_chicago,
        bib       = format_bibtex,
        ris       = format_ris,
        stop("Unknown citation format: ", fmt)
    )

    entries <- vapply(seq_len(nrow(df)), function(i) fn(df[i, , drop = FALSE]), character(1))

    if (fmt %in% NUMBERED_FORMATS) {
        entries <- paste0(seq_along(entries), ". ", entries)
    }

    sep <- if (fmt == "ris") "\n" else "\n\n"
    paste(entries, collapse = sep)
}


# =============================================================================
# Shiny module
# =============================================================================

mod_export_citations_ui <- function(id) {
    ns <- NS(id)
    tagList(
        uiOutput(ns("export_panel")),

        # The download endpoint must live OUTSIDE renderUI and must NOT use
        # display:none — Shiny suspends bindings for hidden elements, which
        # causes the download link to never receive its href.
        # position:fixed off-screen keeps it invisible without hiding it.
        tags$div(
            style = "position:fixed; top:-200px; left:-200px; width:0; height:0; overflow:hidden; pointer-events:none;",
            downloadButton(ns("download"), "")
        )
    )
}


mod_export_citations_server <- function(id, clicked_df, clicked_info) {
    moduleServer(id, function(input, output, session) {
        ns <- session$ns

        download_df      <- reactiveVal(NULL)
        download_content <- reactiveVal(NULL)
        # Snapshot of format key taken at click time; downloadHandler reads this
        # because dynamic inputs inside renderUI can be NULL when the HTTP
        # request fires, which causes req() to abort and Shiny to serve the
        # app HTML page as the downloaded file.
        download_fmt     <- reactiveVal(NULL)

        output$export_panel <- renderUI({
            if (is.null(clicked_info())) return(NULL)

            fmt_choices <- c(
                "CSV (.csv)"    = "csv",
                "Excel (.xlsx)" = "xlsx",
                "JSON (.json)"  = "json",
                setNames(names(CITATION_FORMATS),
                         vapply(CITATION_FORMATS, `[[`, character(1), "label"))
            )

            tagList(
                tags$details(
                    class = "export-details",
                    tags$summary("Export"),
                    div(class = "export-dropdown",
                        selectInput(ns("export_format"),
                            label    = NULL,
                            choices  = fmt_choices,
                            selected = "csv"
                        ),
                        actionButton(ns("check_download"), "Download",
                                     class = "reset-btn export-download-btn",
                                     title = "Download the selected papers in the chosen format")
                    )
                )
            )
        })

        observeEvent(input$check_download, {
            req(clicked_df(), input$export_format)

            df  <- clicked_df()
            fmt <- input$export_format
            download_fmt(fmt)

            if (!(fmt %in% names(CITATION_FORMATS))) {
                download_df(filter_export_cols(df))
                download_content(NULL)
            } else {
                download_content(format_all_citations(df, fmt))
                download_df(df)
            }

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
