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


            // add the tooltip
            var tooltip = document.getElementById('clicked_point_marker');
            var wrapper = tooltip.parentElement;

            // Convert page coordinates to container-relative
            var wrapperBbox = wrapper.getBoundingClientRect();
            var tooltipBbox = tooltip.getBoundingClientRect()
            
            tooltip.classList.remove("hidden");
            tooltip.style.left = (eventData.event.pageX - wrapperBbox.left - window.scrollX) + 'px';
            tooltip.style.top = (eventData.event.pageY - wrapperBbox.top - window.scrollY - tooltipBbox.height/2.) + 'px';



        }
    } 
}
handlePlotBackgroundClick =  function(event) {
    if (!pointClicked) {
        // remove the tooltip
        const tooltip = document.getElementById('clicked_point_marker');
        tooltip.classList.add("hidden");
        // reset the plot colors and table
        Shiny.setInputValue("egm-reset_plot", Math.random(), {priority: "event"});
    }
}

// attach a click listener to plot when shiny finishes with the plot
function attachPlotlyClickHandler() {
    var plot = document.getElementById("egm-egm_plot");
    
    if (plot){
        if (typeof plot.on === "function") {
            // attach the click handler
            plot.on("plotly_click", handlePlotlyClicks);
            console.log("Plotly handler attached");

            // create a hidden div for the tooltip to mark clicks
            const el = document.createElement("div");
            el.id = "clicked_point_marker";
            el.classList.add("hidden");
            // document.body.appendChild(el);
            plot.querySelector(".svg-container").appendChild(el);

            return;
        } 
    }

    // Plotly not ready yet, retry
    console.log('waiting for plotly to load')
    setTimeout(attachPlotlyClickHandler, 500);
}
attachPlotlyClickHandler();

document.addEventListener("DOMContentLoaded", function() {
    // attach the off-click listener
    document.getElementById("plot_wrapper").addEventListener("click", handlePlotBackgroundClick);    
})
