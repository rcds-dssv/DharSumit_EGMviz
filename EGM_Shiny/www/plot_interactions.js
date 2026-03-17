// save the plot data uid (first trace) so that I can check if a new plot has been created
var lastPlotFingerprint = null;

var ARROW_PATH_D = "M 0 10 L 16 0 L 16 6 L 40 6 L 40 14 L 16 14 L 16 20 Z";
var ARROW_HEIGHT = 20;

// ─── Arrow helpers ──────────────────────────────────────────────────────────

function ensureArrowGroup() {
    // Get (or lazily create) the <g id="arrow_markers"> in the second main SVG layer.
    var plot = document.getElementById("egm-egm_plot");
    if (!plot) return null;
    const svgs = plot.querySelectorAll(".main-svg");
    if (svgs.length < 2) return null;
    const svg = svgs[1];
    var group = svg.querySelector("#arrow_markers");
    if (!group) {
        group = document.createElementNS("http://www.w3.org/2000/svg", "g");
        group.setAttribute("id", "arrow_markers");
        svg.insertBefore(group, svg.querySelector(".infolayer"));
        console.log("created arrow_markers group on demand");
    }
    return group;
}

function clearArrows() {
    var group = ensureArrowGroup();
    if (group) group.innerHTML = "";
}

function drawArrowsForEventData(eventData) {
    if (!eventData || !eventData.points || eventData.points.length === 0) return;

    var plot = document.getElementById("egm-egm_plot");
    if (!plot) return;

    var group = ensureArrowGroup();
    if (!group) return;

    group.innerHTML = ""; // clear any previous arrows

    var xaxis   = plot._fullLayout.xaxis;
    var yaxis   = plot._fullLayout.yaxis;
    var xOffset = xaxis._mainAxis._offset;
    var yOffset = yaxis._mainAxis._offset;

    var points = eventData.points;

    // Single arrow at (max x, avg y) of all selected points.
    // For a single point this is identical to the previous per-point behaviour.
    var max_x = points.reduce(function(m, p) { return Math.max(m, p.x); }, -Infinity);
    var avg_y = points.reduce(function(s, p) { return s + p.y; }, 0) / points.length;

    var x_px = xaxis.l2p(max_x) + xOffset;
    var y_px = yaxis.l2p(avg_y) + yOffset;

    var arrow = document.createElementNS("http://www.w3.org/2000/svg", "path");
    arrow.setAttribute("d", ARROW_PATH_D);
    arrow.setAttribute("transform",
        "translate(" + (x_px + 4) + ", " + (y_px - ARROW_HEIGHT / 2) + ")"
    );
    group.appendChild(arrow);
}

// ─── Deselect handler ───────────────────────────────────────────────────────

function handleDeselect() {
    // Called from plotly_doubleclick and plotly_deselect events.
    // Clears arrows and notifies Shiny; R handles all proxy restyles.
    clearArrows();
    Shiny.setInputValue("egm-reset_plot", Math.random(), {priority: "event"});
}

// ─── Plotly event handlers ──────────────────────────────────────────────────

handlePlotlyClicks = function(eventData) {
    if ("points" in eventData && eventData.points.length > 0) {
        drawArrowsForEventData(eventData);
    }
}

handlePlotlySelected = function(eventData) {
    if (eventData && "points" in eventData && eventData.points.length > 0) {
        drawArrowsForEventData(eventData);
    }
}

// ─── Attach handlers after Plotly renders ───────────────────────────────────

function attachPlotlyClickHandler() {
    var plot = document.getElementById("egm-egm_plot");
    if (!plot || typeof plot.on !== "function" || !plot._fullLayout || !plot._fullData || plot._fullData[0].uid === lastPlotFingerprint) {
        // Plotly not ready yet, retry
        console.log("waiting for plotly to load");
        setTimeout(attachPlotlyClickHandler, 100);
        return;
    }

    if (!plot._clickHandlerAttached) {
        plot.on("plotly_click",       handlePlotlyClicks);
        plot.on("plotly_selected",    handlePlotlySelected);
        plot.on("plotly_doubleclick", handleDeselect);
        plot.on("plotly_deselect",    handleDeselect);
        plot._clickHandlerAttached = true;
        lastPlotFingerprint = plot._fullData[0].uid;

        // Ensure the arrow group exists from the start
        ensureArrowGroup();
        console.log("plotly handlers attached");
    }
}

// ─── Shiny message handlers ─────────────────────────────────────────────────

// For the "Reset Plot Selection" button
Shiny.addCustomMessageHandler("hideArrow", function(_) {
    console.log("=== received hideArrow message from Shiny");
    clearArrows();
});

// When the plot is fully recreated (e.g. after a filter changes)
Shiny.addCustomMessageHandler("triggerAttachPlotlyClickHandler", function(_) {
    console.log("=== received triggerAttachPlotlyClickHandler message from Shiny");
    var plot = document.getElementById("egm-egm_plot");
    if (plot) {
        plot._clickHandlerAttached = false;
        plot.querySelector("#arrow_markers")?.remove();
    }
    attachPlotlyClickHandler();
});
