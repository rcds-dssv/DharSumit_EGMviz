// reize the figure if the table section is toggled
function resizePlotly(plot_container, plot){
    // Listen for the transition to finish
    plot_container.addEventListener('transitionend', function handler() {
        // Now get the final dimensions
        var new_width = plot_container.clientWidth - 120;
        var new_height = plot_container.clientHeight - 160

        Plotly.relayout(plot, {
            width: new_width,
            height: new_height,
        }).then(function() {
            // get the bounding box after Plotly has redrawn
            var plotArea = plot._fullLayout._plots.xy.plot[0][0];  // Main plot area
            var bbox = plotArea.getBoundingClientRect();
            var containerBbox = plot.getBoundingClientRect();
            var actualLeftOffset = bbox.left - containerBbox.left;

            // var leftMargin = plot.layout.margin.l || 0; //this is zero
            var topMargin = plot.layout.margin.t || 120;

            var pixelOffsetX = 380;  
            var pixelOffsetY = 170;   

            // Convert to paper coordinates
            // For x: start at left margin, add offset, divide by total width
            var annotation_x = (actualLeftOffset - pixelOffsetX) / new_width;

            // For y: start at 1 (top), subtract (top margin + offset) / total height
            var annotation_y = 1 - (topMargin - pixelOffsetY) / new_height;

            console.log(annotation_x, actualLeftOffset)

            // Update just the annotation
            Plotly.relayout(plot, {
                'annotations[0].x': annotation_x,
                'annotations[0].y': annotation_y
            });

            // Remove the listener so it doesn't fire repeatedly
            plot_container.removeEventListener('transitionend', handler);

        });

    }, { once: true });  // 'once: true' automatically removes the listener
}

// toggle the table container on/off (by changing the width)
function toggleTable(){
    // console.log("clicked", this);
    let plot_container = document.getElementById("plot_section");
    let plot = document.getElementById("egm-egm_plot");
    if (this.classList.contains("active")){
        this.classList.remove("active");
        plot_container.classList.add("grow");
        resizePlotly(plot_container, plot);
    } else {
        this.classList.add("active");
        plot_container.classList.remove("grow");
        resizePlotly(plot_container, plot);
    }
    
}

// attach listeners to the toggles when page loads
document.addEventListener("DOMContentLoaded", function() {
    // table toggle
    document.getElementById("toggle_table").addEventListener("click", toggleTable);
})

Shiny.addCustomMessageHandler('resizePlotly', function(message) {
    console.log('resizing plot', message)
    var plot = document.getElementById(message.plotId);


});