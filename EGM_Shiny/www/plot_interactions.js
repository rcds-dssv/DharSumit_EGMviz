// =============================================================================
// plot_interactions.js — plotly click / selection arrows
//
// Draws a right-pointing arrow SVG next to the selected dot(s) after the user
// clicks or lasso-selects points in the EGM scatter plot.
//
// Why JavaScript?
//   Plotly.js does not provide a built-in "marker annotation" that moves with
//   the data point.  We must read Plotly's internal layout object (_fullLayout)
//   to convert data coordinates to pixel coordinates, and then inject an SVG
//   <path> element directly into the plot's DOM.  This cannot be done from R.
//
// Coordinate system note:
//   Plotly stores each axis in _fullLayout.xaxis / .yaxis.  The helper
//   axis.l2p(value) converts a data-space value to a pixel offset relative to
//   the plot area.  Adding axis._mainAxis._offset gives the pixel position
//   relative to the SVG element itself, which is what we need for `translate`.
// =============================================================================


// ── Constants ─────────────────────────────────────────────────────────────────

// SVG path that draws a right-pointing arrow (width ≈ 40 px, height = 20 px)
var ARROW_PATH_D = "M 0 10 L 16 0 L 16 6 L 40 6 L 40 14 L 16 14 L 16 20 Z";
var ARROW_HEIGHT = 20;

// Fingerprint of the last plot we attached handlers to.
// Used to detect when Shiny has fully re-rendered the plot after a filter change
// so we can re-attach handlers to the new DOM element.
var lastPlotFingerprint = null;


// ── Arrow helpers ─────────────────────────────────────────────────────────────

// Returns (and lazily creates) the <g id="arrow_markers"> SVG group that holds
// all arrow elements.  Plotly renders several stacked SVG elements; the second
// one (.main-svg index 1) sits on top of the plot area and is the right layer
// for overlay annotations.
function ensureArrowGroup() {
    var plot = document.getElementById("egm-egm_plot");
    if (!plot) return null;

    var svgs = plot.querySelectorAll(".main-svg");
    if (svgs.length < 2) return null;

    var svg = svgs[1];
    var group = svg.querySelector("#arrow_markers");
    if (!group) {
        group = document.createElementNS("http://www.w3.org/2000/svg", "g");
        group.setAttribute("id", "arrow_markers");
        // Insert before .infolayer so arrows appear below plotly's own overlays
        svg.insertBefore(group, svg.querySelector(".infolayer"));
    }
    return group;
}

// Removes all arrows from the overlay group.
function clearArrows() {
    var group = ensureArrowGroup();
    if (group) group.innerHTML = "";
}

// Draws a single arrow for the current selection.
//
// Arrow position:
//   x — rightmost selected point (so the arrow points away from the selection)
//   y — vertical average of all selected points
//
// For a single-point click this reduces to the position of that one point,
// which matches the original per-point behaviour.
function drawArrowsForEventData(eventData) {
    if (!eventData || !eventData.points || eventData.points.length === 0) return;

    var plot = document.getElementById("egm-egm_plot");
    if (!plot) return;

    var group = ensureArrowGroup();
    if (!group) return;

    group.innerHTML = ""; // replace any previous arrow

    // Read Plotly's internal axis objects for coordinate conversion
    var xaxis   = plot._fullLayout.xaxis;
    var yaxis   = plot._fullLayout.yaxis;
    var xOffset = xaxis._mainAxis._offset; // pixels from SVG left edge to plot area left
    var yOffset = yaxis._mainAxis._offset; // pixels from SVG top  edge to plot area top

    var points = eventData.points;

    var max_x = points.reduce(function(m, p) { return Math.max(m, p.x); }, -Infinity);
    var avg_y = points.reduce(function(s, p) { return s + p.y; }, 0) / points.length;

    // l2p() converts a data value to a pixel offset within the plot area;
    // adding _offset gives the absolute pixel position within the SVG.
    var x_px = xaxis.l2p(max_x) + xOffset;
    var y_px = yaxis.l2p(avg_y) + yOffset;

    var arrow = document.createElementNS("http://www.w3.org/2000/svg", "path");
    arrow.setAttribute("d", ARROW_PATH_D);
    arrow.setAttribute("transform",
        "translate(" + (x_px + 4) + ", " + (y_px - ARROW_HEIGHT / 2) + ")"
    );
    group.appendChild(arrow);
}


// ── Deselect handler ──────────────────────────────────────────────────────────

// Called when the user double-clicks the plot or triggers plotly_deselect.
// Clears the arrow overlay and notifies Shiny to run the full reset path
// (opacity reset, table clear, etc.) — the same path as the Reset button.
function handleDeselect() {
    clearArrows();
    Shiny.setInputValue("egm-reset_plot", Math.random(), { priority: "event" });
}


// ── Plotly event handlers ─────────────────────────────────────────────────────

handlePlotlyClicks = function(eventData) {
    if ("points" in eventData && eventData.points.length > 0) {
        drawArrowsForEventData(eventData);
    }
};

handlePlotlySelected = function(eventData) {
    if (eventData && "points" in eventData && eventData.points.length > 0) {
        drawArrowsForEventData(eventData);
    }
};


// ── Attach handlers after Plotly renders ──────────────────────────────────────

// Polls every 100 ms until the Plotly element is ready, then attaches the
// click/selection/deselect handlers.
//
// The fingerprint check (plot._fullData[0].uid) prevents double-attaching
// when `triggerAttachPlotlyClickHandler` is called: after a filter change
// Shiny re-renders the plot with a new uid, so the fingerprint changes and we
// know the plot is fresh and handlers need to be re-attached.
function attachPlotlyClickHandler() {
    var plot = document.getElementById("egm-egm_plot");
    var notReady = !plot
        || typeof plot.on !== "function"
        || !plot._fullLayout
        || !plot._fullData;
    var alreadyAttached = plot
        && plot._fullData
        && plot._fullData[0].uid === lastPlotFingerprint;

    if (notReady || alreadyAttached) {
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

        // Pre-create the arrow group so it's available immediately on first click
        ensureArrowGroup();
    }
}


// ── Shiny message handlers ────────────────────────────────────────────────────

// Sent by mod_selection.R when the "Reset Plot Selection" button is clicked.
Shiny.addCustomMessageHandler("hideArrow", function(_) {
    clearArrows();
});

// Sent by mod_plot.R after the plot is fully re-rendered (e.g. after a filter
// change).  Resets the handler-attached flag and the DOM group so that
// attachPlotlyClickHandler() will re-attach to the new element.
Shiny.addCustomMessageHandler("triggerAttachPlotlyClickHandler", function(_) {
    var plot = document.getElementById("egm-egm_plot");
    if (plot) {
        plot._clickHandlerAttached = false;
        var existing = plot.querySelector("#arrow_markers");
        if (existing) existing.remove();
    }
    attachPlotlyClickHandler();
});