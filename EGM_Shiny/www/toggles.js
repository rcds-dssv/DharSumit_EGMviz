// resize the figure if the table section is toggled
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
            var annotation_bbox = plot.querySelector(".annotation").getBoundingClientRect();
            var plotArea = plot._fullLayout._plots.xy.plot[0][0];  // Main plot area
            var bbox = plotArea.getBoundingClientRect();
 
            // Convert to paper coordinates
            var annotation_x = -annotation_bbox.width / bbox.width 
            var annotation_y = 1 + (annotation_bbox.height + 4) / bbox.height 

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

// resize the pltly
function resizePlotlyFrame(plot_container, plot) {
    const new_width  = plot_container.clientWidth  - 120;
    const new_height = plot_container.clientHeight - 160;

    Plotly.relayout(plot, {
        width: new_width,
        height: new_height
    });
}
function repositionPlotlyAnnotation0(plot){
    var annotation_bbox = plot.querySelector(".annotation").getBoundingClientRect();
    var plotArea = plot._fullLayout._plots.xy.plot[0][0];  // Main plot area
    var bbox = plotArea.getBoundingClientRect();

    // Convert to paper coordinates
    var annotation_x = -annotation_bbox.width / bbox.width 
    var annotation_y = 1 + (annotation_bbox.height + 4) / bbox.height 

    // Update just the annotation
    Plotly.relayout(plot, {
        'annotations[0].x': annotation_x,
        'annotations[0].y': annotation_y
    });
}

function resizePlotlySmooth(plot_container, plot, duration = 300) {
    let rafId = null;
    let done = false;

    function resizeLoop() {
        resizePlotlyFrame(plot_container, plot);
        repositionPlotlyAnnotation0(plot);
        rafId = requestAnimationFrame(resizeLoop);
    }

    function finish() {
        if (done) return;
        done = true;

        cancelAnimationFrame(rafId);
        resizePlotlyFrame(plot_container, plot);
        repositionPlotlyAnnotation0(plot);

        plot_container.removeEventListener('transitionend', finish);
    }

    plot_container.addEventListener('transitionend', finish);

    resizeLoop();

    // Fallback in case transitionend never fires
    setTimeout(finish, duration + 50);
}


// toggle the table container on/off (by changing the width)
function toggleTable(){
    // console.log("clicked", this);
    let plot_container = document.getElementById("plot_section");
    let plot = document.getElementById("egm-egm_plot");
    if (this.classList.contains("active")){
        this.classList.remove("active");
        plot_container.classList.add("grow");
        // resizePlotly(plot_container, plot);
        resizePlotlySmooth(plot_container, plot);
    } else {
        this.classList.add("active");
        plot_container.classList.remove("grow");
        // resizePlotly(plot_container, plot);
        resizePlotlySmooth(plot_container, plot);
    }
    
}

// attach listeners to the toggles when page loads
document.addEventListener("DOMContentLoaded", function() {
    // table toggle
    document.getElementById("toggle_table").addEventListener("click", toggleTable);
})