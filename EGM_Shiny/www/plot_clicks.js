// flag to track if a point was clicked (vs. background click)
var pointClicked = false;

getPlotlyPositionOnPage = function(eventData){
    // from ChatGPT
    var point = eventData.points[0];
    var plot = document.getElementById("egm-egm_plot");

    // get plot layout + axes
    var xaxis = plot._fullLayout.xaxis;
    var yaxis = plot._fullLayout.yaxis;

    // data to plot pixels
    var x_px = xaxis.l2p(point.x);
    var y_px = yaxis.l2p(point.y);

    // account for plot margins
    var x = x_px + plot._fullLayout.xaxis._mainAxis._offset;
    var y = y_px +  plot._fullLayout.yaxis._mainAxis._offset;
    return {x:x, y:y}

}
handlePlotlyClicks =  function(eventData) {
    // eventData.points is an array of points clicked
    if ("points" in eventData){
        if (eventData.points.length > 0){
            pointClicked = true;
            // reset the flag after a brief delay
            setTimeout(function() { pointClicked = false; }, 50);

            // add the arrow
            var arrow = document.getElementById('clicked_point_marker');

            // Convert page coordinates to container-relative
            arrow.classList.remove("hidden");
            var arrowBbox = arrow.getBoundingClientRect()
            var pos = getPlotlyPositionOnPage(eventData)
            var x = pos.x + 4; 
            var y = pos.y - arrowBbox.height / 2;

            arrow.setAttribute("transform", `translate(${x}, ${y})`);



        }
    } 
}
handlePlotBackgroundClick =  function(event) {
    if (!pointClicked) {
        // remove the arrow
        const arrow = document.getElementById('clicked_point_marker');
        arrow.classList.add("hidden");
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

            // create a hidden div for the arrow to mark clicks
            // const el = document.createElement("div");
            // el.id = "clicked_point_marker";
            // el.classList.add("hidden");
            // // document.body.appendChild(el);
            // plot.querySelector(".svg-container").appendChild(el);

            const svgs = plot.querySelectorAll(".main-svg");
            // const svg = svgs[svgs.length - 1];
            const svg = svgs[1];
            var arrow = document.createElementNS("http://www.w3.org/2000/svg", "path");
            arrow.setAttribute("d",
                "M 0 10 " +   // tip
                "L 16 0 " +   // top-left of head
                "L 16 6 " +   // top of tail
                "L 40 6 " +   // top-right of tail
                "L 40 14 " +  // bottom-right of tail
                "L 16 14 " +  // bottom of tail
                "L 16 20 " +  // bottom-left of head
                "Z"
            );            
            arrow.setAttribute("id", "clicked_point_marker")
            arrow.classList.add("hidden");
            svg.insertBefore(arrow, svg.querySelector('.infolayer'));
            // svg.appendChild(arrow);
            // arrow.setAttribute("transform", `translate(${x}, ${y})`);

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
