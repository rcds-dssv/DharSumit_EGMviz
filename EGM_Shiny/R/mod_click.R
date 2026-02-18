update_plotly_colors_opacities <- function(session, info){
    # Create the original color vectors but replace the clicked point (if not null)

    if (is.null(info)){
        #for plot reset
        opacity <- 1.
    } else {
        # for emphasizing the clicked point (which will have opacity = 1)
        opacity <- 0.4
    }

    for (name in names(egm_data)) {
        trace_idx <- egm_data[[name]]$index
        colors <- rep(egm_data[[name]]$color, nrow(egm_data[[name]]$counts))
        line_colors <- rep(egm_data[[name]]$color, nrow(egm_data[[name]]$counts))
        opacities <- rep(opacity, nrow(egm_data[[name]]$counts))
        line_opacities <- rep(opacity, nrow(egm_data[[name]]$counts))
        # if there is click information then mark the clicked point
        # otherwise this will be used to reset the plot colors 
        if (!is.null(info)){
            if ("trace_index" %in% names(info) && "pointNumber" %in% names(info)){
                if (trace_idx == info$trace_index) {
                    line_colors[info$pointNumber + 1] <- "white"
                    opacities[info$pointNumber + 1] <- 1;
                    line_opacities[info$pointNumber + 1] <- 1;
                }
            }
        }

        # Update the plot without re-rendering
        plotlyProxy("egm_plot", session) %>%
            plotlyProxyInvoke("restyle", list(
                marker.color = list(colors),
                marker.opacity = list(opacities),
                marker.line.color = list(line_colors),
                marker.line.opacity = list(line_opacities)
            ),
            list(trace_idx)
        )
    }
}

# create_plotly_click_info = function(event_data, plot_source_name){
#     if (is.null(event_data)) return(NULL)
#     click_data <- event_data("plotly_click", source = plot_source_name)
create_plotly_click_info = function(click_data){
    if (is.null(click_data)) return(NULL)

    clicked_x <- click_data$customdata[[1]][1]
    clicked_y <- click_data$customdata[[1]][2]
    trace_id  <- click_data$customdata[[1]][3]
    trace_index <- egm_data[[trace_id]]$index

    list(
        clicked_x = clicked_x,
        clicked_y = clicked_y,
        trace_id = trace_id,
        trace_index = trace_index,
        pointNumber = click_data$pointNumber
    )
}

create_plotly_click_df = function(info, x_col, y_col){
    if (is.null(info)) return(NULL)
    egm_data[[info$trace_id]]$df %>%
        dplyr::filter(
            .[[x_col]] == info$clicked_x,
            .[[y_col]] == info$clicked_y
        )
}

create_table_header_html <- function(info, df){
    # generate the table header (number of papers and any tags from the click)

    # Placeholder before first click
    if (is.null(info) || is.null(df) || nrow(df) == 0) {
        return(tags$p(class="info", "Click on a point to display the papers"))
    }

    # Now info and df exist
    n <- nrow(df)
    display_text <- egm_data[[info$trace_id]]$display_text
    return(
        tagList(
            tags$p(paste("Number of papers:", n)),
            tags$div(class = "paper-tags",
                tags$p("Selection attributes:"),
                tags$span(class = "tag", info$clicked_x),
                tags$span(class = "tag", info$clicked_y),
                if (!is.null(display_text)) tags$span(class = paste("tag", info$trace_id), display_text)
            )
        )
    )
}

create_table_cards_html = function(df){
    # generate the cards (1 for each paper in the dataframe)

    if (is.null(df) || nrow(df) == 0) {
        # if the dataframe is empty, return an empty div
        return(div(class = "paper-list"))
    }
    # there may be a more elegant way to handle these special values
    special <- c("WorkType", "Theme.Assignment", "review_confidence", "in_progress")
    conf <- c("Low", "Medium", "High")

    cards <- lapply(seq_len(nrow(df)), function(i) {
        row <- df[i, , drop = FALSE]

        title <- tags$h4(paste("Paper Title Placeholder"))

        meta <- lapply(names(row), function(col) {
            if (!is.na(row[[col]]) && !(col %in% special)) {
                div(class = "paper-meta",
                    span(class = "paper-card-label", paste0(trimws(gsub("([A-Z])", " \\1", col)), ":")),
                    span(class = "paper-card-value", as.character(row[[col]]))
                )
            }
        })
        special_tags <- tags$div(class = "paper-tags",
            tags$span(class = "tag", row$WorkType),
            tags$span(class = "tag", row$Theme.Assignment),
            tags$span(class=paste("tag", tolower(conf[row$review_confidence])), paste(conf[row$review_confidence], "Confidence")),
            if (row$in_progress > 0) tags$span(class = "tag ongoing", "In Progress")
        )

        div(class = "paper-card", 
            div(class = "paper-card-contents",
                title,
                meta,
                special_tags
            )
        )
    })

    return(div(class = "paper-list", cards))
}

###### modular ui and server functions
mod_click_plot_ui <- function(id, header_only = FALSE) {
    ns <- NS(id)
    if (header_only) {
        uiOutput(ns("table_header"))
    } else {
        uiOutput(ns("table_content"))
    }
}
mod_click_reset_ui <- function(id, header_only = FALSE) {
    ns <- NS(id)
    actionButton(ns("reset_plot"), "Reset", class = "reset-btn")
}

mod_click_server <- function(id, plot_source_name, x_col, y_col) {
    moduleServer(id, function(input, output, session) {

        # Holds the current click info; NULL means "no selection"
        clicked_info <- reactiveVal(NULL)

        # Update on plot click
        observeEvent(event_data("plotly_click", source = plot_source_name), {
            clicked_info(
                create_plotly_click_info(event_data("plotly_click", source = plot_source_name))
            )
        })

        # create a dataframe with the papers in the clicked point
        clicked_df <- reactive({
            create_plotly_click_df(clicked_info(), x_col, y_col)
        })

        observeEvent(input$reset_plot, {
            clicked_info(NULL)
            session$sendCustomMessage("hideArrow", list())
        })

        # update the plot colors and opacities
        observe({
            update_plotly_colors_opacities(session, clicked_info())
        })

        # table header (N papers, tags)
        output$table_header <- renderUI({
            create_table_header_html(clicked_info(), clicked_df())
        })

        # table content (paper cards)
        output$table_content <- renderUI({
            create_table_cards_html(clicked_df())
        })

    })
}