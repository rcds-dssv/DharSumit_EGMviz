// flag to track if a point was clicked (vs. background click)
var pointClicked = false;

// save the plot data uid (first trace) so that I can check if a new plot has been created
var lastPlotFingerprint = null;

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
    if (!plot || typeof plot.on !== "function" || !plot._fullLayout || !plot._fullData || plot._fullData[0].uid === lastPlotFingerprint) {
        // Plotly not ready yet, retry
        console.log('waiting for plotly to load')
        setTimeout(attachPlotlyClickHandler, 100);
        return;
    }

    if (!plot._clickHandlerAttached) {
        plot.on("plotly_click", handlePlotlyClicks);
        plot._clickHandlerAttached = true;
        lastPlotFingerprint = plot._fullData[0].uid;

        // create an SVG for the arrow to mark clicks (hide at start)
        const svgs = plot.querySelectorAll(".main-svg");
        // const svg = svgs[svgs.length - 1];
        const svg = svgs[1];

        // check if the arrow already exists
        var check = svg.querySelector("#clicked_point_marker");
        if (check === null){

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
            console.log("created svg arrow marker")
        }

    }
}

document.addEventListener("DOMContentLoaded", function() {
    // attach the off-click listener
    document.getElementById("plot_wrapper").addEventListener("click", handlePlotBackgroundClick);    
})

// for the reset button
Shiny.addCustomMessageHandler("hideArrow", function(_) {
    console.log("=== received hideArrow message from Shiny");
    document.getElementById("clicked_point_marker")?.classList.add("hidden");
})

// when plot recreated
Shiny.addCustomMessageHandler("triggerAttachPlotlyClickHandler", function(_) {
    console.log("=== received triggerAttachPlotlyClickHandler message from Shiny");
    // cleanup before trying to attach the listener
    var plot = document.getElementById("egm-egm_plot")
    if (plot) {
        plot._clickHandlerAttached = false;
        plot.querySelector("#clicked_point_marker")?.remove()
    }
    attachPlotlyClickHandler();
})