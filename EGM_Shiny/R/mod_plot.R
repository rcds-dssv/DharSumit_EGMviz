
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
  x_label_boxes <- lapply(0:(n_x-1), function(i) {
    list(
      type = "rect",
      xref = "x", yref = "paper",
      x0 = i - 0.5, x1 = i + 0.5,
      y0 = 0.99, y1 = 1.05, #magic numbers
      line = list(color = "black", width = 1),
      fillcolor = "transparent"
    )
  })
  
  #  boxes around y-axis labels (left of the plot)
  y_label_boxes <- lapply(0:(n_y-1), function(i) {
    list(
      type = "rect",
      xref = "paper", yref = "y",
      x0 = -0.015, x1 = -0.45,  # magic numbers
      y0 = i - 0.5, y1 = i + 0.5,
      line = list(color = "black", width = 1),
      fillcolor = "transparent"
    )
  })
  
  # Combine all shapes
  all_shapes <- c(vlines, hlines, x_label_boxes, y_label_boxes)
  
}

###### modular ui and server functions
mod_plot_ui <- function(id) {
  ns <- NS(id)
  plotlyOutput(ns("egm_plot"),  height = "800px") # could use the same height as calculated in the server
}


mod_plot_server <- function(id, plot_source_name, x_col, y_col, n_col) {
    moduleServer(
        id,
        function(input, output, session) {
          
            # Get the number of unique levels for each axis
            n_x <- length(unique(batch3_egm_counts[[x_col]]))
            n_y <- length(unique(batch3_egm_counts[[y_col]]))
            
            # set the sizing to make square boxes, 
            # trial and error ... (there must be a better way)
            cell_px <- 60
            plot_width  <- n_x * cell_px + 260
            plot_height <- n_y * cell_px

            # clean the text for the title and tooltips
            clean_x_title <- str_replace_all(x_col,fixed(".")," ")
            clean_y_title <- str_replace_all(y_col,fixed(".")," ")
            
            # create the plotly figure
            egm_spec <- plot_ly(
                data = batch3_egm_counts,
                x = batch3_egm_counts[[x_col]],
                y = batch3_egm_counts[[y_col]],
                size = batch3_egm_counts[[n_col]],
                type = "scatter",
                mode = "markers",
                sizes = c(5, 100),   # controls min/max bubble size
                marker = list(
                  color = "#1f77b4",
                  opacity = 0.7
                ),
                text = ~paste(
                    clean_x_title,":", batch3_egm_counts[[x_col]],
                    "<br>",
                    clean_y_title,":", batch3_egm_counts[[y_col]],
                    "<br>Papers:", batch3_egm_counts[[n_col]]
                ),
                hoverinfo = "text",
                height = plot_height,
                width = plot_width,
                source = plot_source_name
            ) %>%
            layout(
                margin = list(t = 100),
                xaxis = list(
                  title = list(
                    text = clean_x_title, 
                    standoff = 10
                  ),
                  side = "top", 
                  tickangle = 0, 
                  showgrid = FALSE
                ),
                yaxis = list(
                  title = list(
                    text = clean_y_title,
                    standoff = 20  
                  ),
                  showgrid = FALSE
                ),
                shapes = shapes_for_plotly(n_x, n_y),
                showlegend = FALSE
            )

            # fix the axis labels
            emg_build <- plotly_build(egm_spec)
            xaxis <- emg_build$x$layout$xaxis
            yaxis <- emg_build$x$layout$yaxis
            if (!is.null(xaxis$categoryarray)) {
              labs <- xaxis$categoryarray
              emg_build$x$layout$xaxis$tickmode <- "array"
              emg_build$x$layout$xaxis$tickvals <- labs
              emg_build$x$layout$xaxis$ticktext <- wrap_for_plotly(labs, 5)
            } else if (!is.null(xaxis$ticktext)) {
              emg_build$x$layout$xaxis$ticktext <- wrap_for_plotly(xaxis$ticktext, 5)
            }
            if (!is.null(yaxis$categoryarray)) {
              labs <- yaxis$categoryarray
              emg_build$x$layout$yaxis$tickmode <- "array"
              emg_build$x$layout$yaxis$tickvals <- labs
              emg_build$x$layout$yaxis$ticktext <- wrap_for_plotly(labs, 24, 2)
            } else if (!is.null(yaxis$ticktext)) {
              emg_build$x$layout$yaxis$ticktext <- wrap_for_plotly(yaxis$ticktext, 24, 2)
            }
            
            output$egm_plot <- renderPlotly(emg_build)
            
            

        }
    )
}