
handlePlotlyClicks =  function(eventData) {
    // eventData.points is an array of points clicked
    if ("points" in eventData){
        // user clicked a point
        // add a persistent tooltip
        var point = eventData.points[0];

        // Data coordinates
        var x_data = point.x;
        var y_data = point.y;

        // Optional: page coordinates of the mouse
        var pageX = eventData.event.pageX;
        var pageY = eventData.event.pageY;

        console.log(pageX, pageY)
    } else {
        // user did not click a point
        // reset the figure and remove the tooltip

        console.log('user did not click a point')
    }

    // Send to Shiny
    // Shiny.setInputValue('plot_click_info', {
    //     x_data: x_data,
    //     y_data: y_data,
    //     pageX: pageX,
    //     pageY: pageY,
    //     nonce: Math.random()  // ensures Shiny detects changes even if same coords
    // });
}

// attach a click listener to plot when shiny connects
// Wait a bit for plot to render
setTimeout(function() {
    var plot = document.getElementById("egm-egm_plot");
    console.log('Plot element:', plot);
    
    if (plot) {
        plot.on('plotly_click', handlePlotlyClicks);
        console.log('Listener attached');
    }
}, 500);
document.addEventListener("DOMContentLoaded", function() {
    document.getElementById("plot_wrapper").addEventListener("click", handlePlotlyClicks);
})
console.log('loaded')