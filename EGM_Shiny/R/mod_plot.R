
##### helper functions

wrap_for_plotly <- function(x, width = 20, padding = 0) {
    # wrap long lines (using width) and add padding to each line (if padding > 0)
    wrapped <- str_wrap(x, width = width)
    lines <- str_split(wrapped, "\n")
    padded_lines <- lapply(lines, function(line_vec) {
        str_pad(line_vec, width = nchar(line_vec) + padding, side = "right")
    })
    sapply(padded_lines, paste, collapse = "<br>")
}

shapes_for_plotly <- function(n_x, n_y){
    # create a grid for the plotly figure to define the boxes and outline the labels

    # within the plot
    # Create vertical lines
    vlines <- lapply(0:(n_x), function(i) {
        list(
            type = "line",
            x0 = i - 0.5, x1 = i - 0.5,
            y0 = -0.5, y1 = n_y - 0.5,
            line = list(color = "lightgray", width = 1)
        )
    })
  
    # Create horizontal lines
    hlines <- lapply(0:(n_y), function(i) {
        list(
            type = "line",
            x0 = -0.5, x1 = n_x - 0.5,
            y0 = i - 0.5, y1 = i - 0.5,
            line = list(color = "lightgray", width = 1)
        )
    })
  
    # boxes around x-axis labels (above the plot)
    # x_label_boxes <- lapply(0:(n_x-1), function(i) {
    #     list(
    #         type = "rect",
    #         xref = "x", yref = "paper",
    #         x0 = i - 0.5, x1 = i + 0.5,
    #         y0 = 1.01, y1 = 1.072, #magic numbers
    #         line = list(color = "black", width = 1),
    #         fillcolor = "transparent"
    #     )
    # })
  
    # # boxes around y-axis labels (left of the plot)
    # y_label_boxes <- lapply(0:(n_y-1), function(i) {
    #     list(
    #         type = "rect",
    #         xref = "paper", yref = "y",
    #         x0 = -0.015, x1 = -0.45,  # magic numbers
    #         y0 = i - 0.5, y1 = i + 0.5,
    #         line = list(color = "black", width = 1),
    #         fillcolor = "transparent"
    #     )
    # })
  
    # Combine all shapes
    # all_shapes <- c(vlines, hlines, x_label_boxes, y_label_boxes)
    all_shapes <- c(vlines, hlines)
  
}

add_to_counts_df_for_plotly <- function(count_df, x_col, y_col, x_levels, y_levels, label, x_offset, y_offset){
    # add numeric values and customdata for handling clicks to the counts datafram

    count_df$x_num <- match(count_df[[x_col]], x_levels) - 1 + x_offset
    count_df$y_num <- match(count_df[[y_col]], y_levels) - 1 + y_offset
    count_df <- count_df %>%
        mutate(
            customdata = Map(list, .[[x_col]], .[[y_col]], label)
        )
}

add_trace_to_plotly_spec <- function(spec, df, x_col, y_col, n_col, clean_x_title, clean_y_title, color){
    spec <- spec %>% add_trace(
        # scatter plot
        data = df,
        x = ~x_num,
        y = ~y_num,
        size = ~.data[[n_col]],
        customdata = ~customdata,
        type = "scatter",
        mode = "markers",
        sizes = c(5, 125),   # controls min/max point size
        marker = list(
            color = color,
            opacity = 1,
            line = list(
                color = color,
                width = 1
            )
        ),
        # tooltips
        text = ~paste0(
            paste0("<b>",clean_x_title,":</b><br>"),
            wrap_for_plotly(df[[x_col]], 20),
            paste0("<br><br><b>",clean_y_title,":</b><br>"),
            wrap_for_plotly(df[[y_col]], 20),
            "<br><br><b>N Papers:</b><br>", df[[n_col]]
        ),
        hoverinfo = "text"
    )
}

create_egm_figure = function(plot_source_name, x_col, y_col, n_col){
    # main function to generate the evidence gap map figure

    # Get the number of unique levels for each axis
    n_x <- length(unique(egm_data$all$counts[[x_col]]))
    n_y <- length(unique(egm_data$all$counts[[y_col]]))
    
    # set the sizing to make square boxes, 
    # trial and error ... (there must be a better way)
    # for now, this is only used in a relative sense to draw the lines.  The actual plot size is responsive.
    cell_px <- 60
    plot_width  <- n_x * cell_px + 260
    plot_height <- n_y * cell_px

    # clean the text for the title and tooltips
    clean_x_title <- str_replace_all(x_col,fixed(".")," ")
    clean_y_title <- str_replace_all(y_col,fixed(".")," ")
    
    # count the total number of entries
    n_total <- sum(egm_data$all$counts$n)

    # plot using numerical values
    x_levels <- levels(factor(egm_data$all$counts[[x_col]]))
    y_levels <- levels(factor(egm_data$all$counts[[y_col]]))
    # this needs to be in the same order as the egm_data list for the re-coloring to work
    for (name in names(egm_data)) {
        egm_data[[name]]$counts <- add_to_counts_df_for_plotly(
            egm_data[[name]]$counts, 
            x_col, 
            y_col, 
            x_levels, 
            y_levels, 
            name, 
            egm_data[[name]]$offset_x, 
            egm_data[[name]]$offset_y
        )
    }

    # create the plotly figure
    egm_spec <- plot_ly(
        # global settings
        # height = plot_height,
        # width = plot_width,
        source = plot_source_name,
    ) %>% 
        config(
            responsive = TRUE,
            displayModeBar = TRUE,
            modeBarButtonsToRemove = c(
                "select2d",
                "lasso2d",
                "zoomIn2d",
                "zoomOut2d",
                "autoScale2d",
                "hoverClosestCartesian",
                "hoverCompareCartesian",
                "toggleSpikelines"
            )
        )

    # add all the traces
    for (name in names(egm_data)) {
        egm_spec <- add_trace_to_plotly_spec(egm_spec, egm_data[[name]]$counts, x_col, y_col, n_col, clean_x_title, clean_y_title, egm_data[[name]]$color)
    }

    # configure the plot layout
    egm_spec <- egm_spec %>% layout(
        # spacing, axis titles, legend
        margin = list(t = 120, b = 0, l = 0, r = 0, pad = 10),
        autosize = TRUE,
        showlegend = FALSE,
        xaxis = list(
            # restore the labels
            type = "linear",
            tickmode = "array",
            tickvals = seq(0, length(x_levels) - 1),
            ticktext = x_levels,
            range = c(-0.5, length(x_levels) - 0.5),
            title = list(
                text = clean_x_title, 
                standoff = 10
            ),
            side = "top", 
            tickangle = 0, 
            showgrid = FALSE,
            zeroline = FALSE
            # silly fix to move the labels up
            # ticklen = 7,
            # tickcolor = "rgba(0,0,0,0)"
        ),
        yaxis = list(
            # restore the labels
            type = "linear",
            tickmode = "array",
            tickvals = seq(0, length(y_levels) - 1),
            ticktext = y_levels,
            range = c(-0.5, length(y_levels) - 0.5),
            title = list(
                text = clean_y_title,
                standoff = 20  
            ),
            showgrid = FALSE,
            zeroline = FALSE
        ),
        # my grid (defined above)
        shapes = shapes_for_plotly(n_x, n_y),
        # count of included papers in upper-left of figure
        annotations = list(
            list(
                x = -0.262,
                y = 1.072,
                xref = "paper",
                yref = "paper",
                text = paste0("<b>Total N:</b> ", n_total),
                showarrow = FALSE,
                xanchor = "left",
                yanchor = "top",
                align = "left",
                bgcolor = "rgba(0,0,0,0)",
                bordercolor = "black",
                borderwidth = 1,
                borderpad = 10,
                font = list(size = 12)
            )
        )
    )

    # fix (wrap) the axis labels
    egm_build <- plotly_build(egm_spec)
    xaxis <- egm_build$x$layout$xaxis
    yaxis <- egm_build$x$layout$yaxis
    if (!is.null(xaxis$categoryarray)) {
        labs <- xaxis$categoryarray
        egm_build$x$layout$xaxis$tickmode <- "array"
        egm_build$x$layout$xaxis$tickvals <- labs
        egm_build$x$layout$xaxis$ticktext <- wrap_for_plotly(labs, 5)
    } else if (!is.null(xaxis$ticktext)) {
        egm_build$x$layout$xaxis$ticktext <- wrap_for_plotly(xaxis$ticktext, 5)
    }
    if (!is.null(yaxis$categoryarray)) {
        labs <- yaxis$categoryarray
        egm_build$x$layout$yaxis$tickmode <- "array"
        egm_build$x$layout$yaxis$tickvals <- labs
        egm_build$x$layout$yaxis$ticktext <- wrap_for_plotly(labs, 24, 2)
    } else if (!is.null(yaxis$ticktext)) {
        egm_build$x$layout$yaxis$ticktext <- wrap_for_plotly(yaxis$ticktext, 24, 2)
    }

    return(egm_build)
}

###### modular ui and server functions
mod_plot_ui <- function(id) {
    ns <- NS(id)
    plotlyOutput(ns("egm_plot"),  height = "100%", width = "100%") 
}


mod_plot_server <- function(id, plot_source_name, x_col, y_col, n_col) {
    moduleServer(id, function(input, output, session) {  
        egm_build <- create_egm_figure(plot_source_name, x_col, y_col, n_col)
        output$egm_plot <- renderPlotly(egm_build)
    })
}