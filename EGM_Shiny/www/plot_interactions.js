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
var lastPlotFingerprint = null;

// Plot source name and Shiny module namespace, received from R via the
// triggerAttachPlotlyClickHandler message.
var plotlySource = null;
var plotlyNs     = null;

// The scatter points from the most recent click or lasso selection.
// Kept so the arrow can be redrawn after zoom/pan.
var lastSelectedPts = null;

// Arrow base position (SVG pixels) computed at the last drawArrowsForEventData
// call.  During pan, the mousemove handler shifts the arrow by the mouse delta
// from this base rather than recomputing via l2p() (which only updates after
// the pan completes).
var arrowBaseX = null;
var arrowBaseY = null;

// Pan-drag tracking.
var panDragging     = false;
var panStartClientX = null;
var panStartClientY = null;
var arrowRafPending = false;


// ── Arrow helpers ─────────────────────────────────────────────────────────────

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
        svg.insertBefore(group, svg.querySelector(".infolayer"));
    }
    return group;
}

function clearArrows() {
    var group = ensureArrowGroup();
    if (group) group.innerHTML = "";
}

// Draws a single arrow for the current selection and records its base position.
//
// Arrow position:
//   x — rightmost selected point
//   y — vertical average of all selected points
function drawArrowsForEventData(eventData) {
    if (!eventData || !eventData.points || eventData.points.length === 0) return;

    var plot = document.getElementById("egm-egm_plot");
    if (!plot) return;

    var group = ensureArrowGroup();
    if (!group) return;

    group.innerHTML = "";

    var xaxis   = plot._fullLayout.xaxis;
    var yaxis   = plot._fullLayout.yaxis;
    var xOffset = xaxis._mainAxis._offset;
    var yOffset = yaxis._mainAxis._offset;

    var points = eventData.points;
    var max_x  = points.reduce(function(m, p) { return Math.max(m, p.x); }, -Infinity);
    var avg_y  = points.reduce(function(s, p) { return s + p.y; }, 0) / points.length;

    var x_px = xaxis.l2p(max_x) + xOffset;
    var y_px = yaxis.l2p(avg_y) + yOffset;

    // Record the base position so the pan handler can shift it by mouse delta.
    arrowBaseX = x_px;
    arrowBaseY = y_px;

    var arrow = document.createElementNS("http://www.w3.org/2000/svg", "path");
    arrow.setAttribute("d", ARROW_PATH_D);
    arrow.setAttribute("transform",
        "translate(" + (x_px + 4) + ", " + (y_px - ARROW_HEIGHT / 2) + ")"
    );
    group.appendChild(arrow);
}

// Moves the existing arrow by (dx, dy) pixels without recomputing from data.
// Used during pan where l2p() has not yet updated.
function shiftArrow(dx, dy) {
    var group = ensureArrowGroup();
    if (!group || arrowBaseX === null) return;
    var arrow = group.querySelector("path");
    if (!arrow) return;
    arrow.setAttribute("transform",
        "translate(" + (arrowBaseX + dx + 4) + ", " + (arrowBaseY + dy - ARROW_HEIGHT / 2) + ")"
    );
}


// ── Plotly event handlers ─────────────────────────────────────────────────────

// Returns only scatter-trace points (those with our 3-element customdata).
// Heatmap cells and background clicks have no customdata.
function scatterPointsOnly(eventData) {
    if (!eventData || !("points" in eventData)) return [];
    return eventData.points.filter(function(p) {
        return Array.isArray(p.customdata) && p.customdata.length >= 3;
    });
}

handlePlotlyClicks = function(eventData) {
    var pts = scatterPointsOnly(eventData);
    if (pts.length === 0) return;

    lastSelectedPts = pts;
    drawArrowsForEventData({ points: pts });

    // Trigger the R click observer with a random number so that clicking the
    // same point after a reset always fires the observer (value always changes).
    if (plotlyNs) {
        Shiny.setInputValue(
            plotlyNs + "plotly_click_trigger",
            Math.random(),
            { priority: "event" }
        );
    }
};

handlePlotlySelected = function(eventData) {
    var pts = scatterPointsOnly(eventData);
    if (pts.length === 0) return;

    lastSelectedPts = pts;
    drawArrowsForEventData({ points: pts });

    if (plotlyNs) {
        Shiny.setInputValue(
            plotlyNs + "plotly_selected_trigger",
            Math.random(),
            { priority: "event" }
        );
    }
};


// ── Attach handlers after Plotly renders ──────────────────────────────────────

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
        plot.on("plotly_click",    handlePlotlyClicks);
        plot.on("plotly_selected", handlePlotlySelected);

        // After zoom or completed pan, l2p() reflects the new range — redraw.
        plot.on("plotly_relayout", function() {
            if (lastSelectedPts) {
                drawArrowsForEventData({ points: lastSelectedPts });
            }
        });

        // Start pan tracking when the user presses on the drag layer.
        var dragLayer = plot.querySelector(".nsewdrag");
        if (dragLayer) {
            dragLayer.addEventListener("mousedown", function(e) {
                if (arrowBaseX === null) return;
                panDragging     = true;
                panStartClientX = e.clientX;
                panStartClientY = e.clientY;
            });
        }

        plot._clickHandlerAttached = true;
        lastPlotFingerprint = plot._fullData[0].uid;

        ensureArrowGroup();
    }
}


// ── Document-level pan handlers ───────────────────────────────────────────────

// During pan, Plotly moves the data layer visually but l2p() doesn't update
// until the pan completes.  We track the mouse delta from pan-start and shift
// the arrow by the same amount each frame.  Plotly pans 1:1 with mouse pixels,
// so clientX/Y delta equals SVG pixel delta exactly.
document.addEventListener("mousemove", function(e) {
    if (!panDragging || arrowBaseX === null || arrowRafPending) return;
    var dx = e.clientX - panStartClientX;
    var dy = e.clientY - panStartClientY;
    arrowRafPending = true;
    requestAnimationFrame(function() {
        shiftArrow(dx, dy);
        arrowRafPending = false;
    });
});

// On mouse-up, the pan is complete and l2p() now reflects the new axis range.
// Redraw from data coordinates to get the exact final position.
document.addEventListener("mouseup", function() {
    if (panDragging && lastSelectedPts) {
        drawArrowsForEventData({ points: lastSelectedPts });
    }
    panDragging     = false;
    panStartClientX = null;
    panStartClientY = null;
});


// ── Shiny message handlers ────────────────────────────────────────────────────

Shiny.addCustomMessageHandler("hideArrow", function(_) {
    lastSelectedPts = null;
    arrowBaseX      = null;
    arrowBaseY      = null;
    clearArrows();
});

Shiny.addCustomMessageHandler("triggerAttachPlotlyClickHandler", function(msg) {
    plotlySource = msg.source;
    plotlyNs     = msg.ns;
    var plot = document.getElementById("egm-egm_plot");
    if (plot) {
        plot._clickHandlerAttached = false;
        var existing = plot.querySelector("#arrow_markers");
        if (existing) existing.remove();
    }
    attachPlotlyClickHandler();
});