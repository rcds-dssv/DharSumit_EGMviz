// flag to track if a point was clicked (vs. background click)
var pointClicked = false;

handlePlotlyClicks =  function(eventData) {
    // eventData.points is an array of points clicked
    if ("points" in eventData){
        if (eventData.points.length > 0){
            pointClicked = true;
            // reset the flag after a brief delay
            setTimeout(function() { pointClicked = false; }, 50);

            // // Data coordinates
            // var point = eventData.points[0];
            // var x_data = point.x;
            // var y_data = point.y;

            console.log(eventData)

            // add the tooltip
            const tooltip = document.getElementById('clicked_point_marker');
            const bbox = tooltip.getBoundingClientRect()
            console.log(eventData.event.pageY, bbox.height)
            tooltip.style.top = eventData.event.pageY - bbox.height/2. + "px";
            tooltip.style.left = eventData.event.pageX + "px";
            tooltip.classList.remove("hidden");

            // Send to Shiny
            // Shiny.setInputValue('plot_click_info', {
            //     x_data: x_data,
            //     y_data: y_data,
            //     pageX: pageX,
            //     pageY: pageY,
            //     nonce: Math.random()  // ensures Shiny detects changes even if same coords
            // });
        }
    } 
}
handlePlotBackgroundClick =  function(event) {
    if (!pointClicked) {
        console.log('user did not click a point');
        // remove the tooltip
        const tooltip = document.getElementById('clicked_point_marker');
        tooltip.classList.add("hidden");
        // reset the plot colors
    }
}

// attach a click listener to plot when shiny finishes with the plot
function attachPlotlyClickHandler() {
    var plot = document.getElementById("egm-egm_plot");
    
    if (plot){
        if (typeof plot.on === "function") {
            plot.on("plotly_click", handlePlotlyClicks);
            console.log("Plotly handler attached");
            return;
        } 
    }

    // Plotly not ready yet, retry
    console.log('waiting for plotly to load')
    setTimeout(attachPlotlyClickHandler, 500);
}
attachPlotlyClickHandler();

document.addEventListener("DOMContentLoaded", function() {
    // create a hidden div for the tooltip
    const el = document.createElement("div");
    el.id = "clicked_point_marker";
    el.classList.add("hidden");
    document.body.appendChild(el);

    // attach the off-click listener
    wrapper.addEventListener("click", handlePlotBackgroundClick);    
})
