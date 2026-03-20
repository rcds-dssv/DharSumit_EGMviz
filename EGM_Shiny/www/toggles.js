// =============================================================================
// toggles.js — table panel toggle and Plotly resize handling
//
// The "Table" switchInput in mod_toggles_ui sends a "toggleTable" Shiny
// message when its value changes.  This file listens for that message and
// expands or collapses the table panel by toggling the CSS "grow" class on
// plot_section, then smoothly resizes the Plotly figure to match.
//
// Viewport-filling layout
// -----------------------
// The plot panel fills the available viewport height via CSS flexbox.  To keep
// grid cells approximately square, the plot panel width is set proportionally
// to its height using the ideal aspect ratio (740 / 900).  resizePlotToViewport()
// handles this and is called on initial load, window resize, and Shiny updates.
//
// =============================================================================


// ── Viewport-filling constants ────────────────────────────────────────────────

// Desired minimum pixel size for each grid cell.
// This is the only value you need to change to scale the base layout up or down.
var CELL_SIZE_PX = 60;

// CSS_W_OFFSET / CSS_H_OFFSET: padding + borders outside the plotly figure,
var CSS_W = 42, CSS_H = 42;

// ── Resize helpers ────────────────────────────────────────────────────────────

// Computes the plot's available pixel size from its container.
//
// The offsets account for padding, borders, and the
// plot header bar that sit inside plot_section but outside the plotlyOutput
// element.  Adjust these if the CSS layout changes.
function resizePlotlyFrame(plot_container, plot) {
    var new_width  = plot_container.clientWidth  - CSS_W;
    var new_height = plot_container.clientHeight - CSS_H;

    Plotly.relayout(plot, {
        width:  new_width,
        height: new_height
    });
}

// Repositions the "Total N" annotation (annotations[0]) after a resize.
//
// The annotation is placed in Plotly "paper" coordinates (0–1 range across the
// plot area).  After a resize the plot area changes size but the annotation's
// pixel width/height stays fixed, so we must recompute its paper coordinates.
//
// We access plot._fullLayout._plots.xy.plot[0][0] to get the bounding box of
// the actual data area (excluding axes and margins), which is a Plotly private
// API but the only reliable way to get these dimensions from JS.
function repositionPlotlyAnnotation0(plot) {
    var annotationEl = plot.querySelector(".annotation");
    if (!annotationEl) return;

    var annotation_bbox = annotationEl.getBoundingClientRect();
    var plotArea        = plot._fullLayout._plots.xy.plot[0][0];
    var bbox            = plotArea.getBoundingClientRect();

    // x: shift left by the annotation's full width so it appears to the left
    //    of the y-axis (negative paper coordinate)
    // y: shift above 1.0 (the top of the plot area) by the annotation's height
    //    plus a 4 px gap
    var annotation_x = -annotation_bbox.width  / bbox.width;
    var annotation_y =  1 + (annotation_bbox.height + 4) / bbox.height;

    Plotly.relayout(plot, {
        "annotations[0].x": annotation_x,
        "annotations[0].y": annotation_y
    });
}

// Smoothly resizes the plot every animation frame while the CSS transition runs,
// then does a final resize once the transition ends.
//
// requestAnimationFrame() schedules resizeLoop() to run before the next browser
// paint, giving a fluid animation.  The transitionend event stops the loop once
// the CSS animation is complete.  A setTimeout fallback fires 50 ms after the
// expected transition duration in case transitionend never fires (e.g. if the
// element is hidden).
function resizePlotlySmooth(plot_container, plot, duration) {
    duration = duration || 300;

    var rafId = null;
    var done  = false;

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

        plot_container.removeEventListener("transitionend", finish);
    }

    plot_container.addEventListener("transitionend", finish);
    resizeLoop();
    setTimeout(finish, duration + 50); // fallback
}


// ── Viewport-filling resize ───────────────────────────────────────────────────

// Computes exact plot-section width that makes every grid cell square, given
// the current CSS-determined height.  Cell squareness is derived from the live
// plotly layout (axis category counts and actual rendered margins), so it
// adapts automatically if the data or axis labels change.
//
// Guard: requires plot._fullLayout to be present, which means plotly must have
// completed at least one render.  Calling before that is a safe no-op.
function resizePlotToViewport() {
    var plotSection = document.getElementById("plot_section");
    var mainArea    = document.getElementById("main_area");
    var plot        = document.getElementById("egm-egm_plot");

    if (!plotSection || !mainArea || !plot || !plot._fullLayout) return;
    if (plotSection.classList.contains("grow")) return;

    var layout = plot._fullLayout;
    var nX = (layout.xaxis._categories || []).length;
    var nY = (layout.yaxis._categories || []).length;
    if (!nX || !nY) return;

    // Actual rendered margins (plotly may auto-expand l/r beyond the R values).
    var m  = layout.margin || {};
    var ml = m.l || 0,  mr = m.r || 0;
    var mt = m.t || 0,  mb = m.b || 0;

    // Minimum section dimensions that give at least CELL_SIZE_PX per cell.
    var minH = Math.round(nY * CELL_SIZE_PX + mt + mb + CSS_H);
    var minW = Math.round(nX * CELL_SIZE_PX + ml + mr + CSS_W);

    // Propagate minimum height to .main-area so the CSS fallback stays in sync.
    mainArea.style.minHeight = minH + "px";

    // For the current CSS-driven height, compute the width that makes cells square.
    var sectionH = Math.max(minH, plotSection.clientHeight);
    var cellPx   = (sectionH - CSS_H - mt - mb) / nY;
    var newW     = Math.max(minW, Math.round(nX * cellPx + ml + mr + CSS_W));

    plotSection.style.width = newW + "px";
    resizePlotlyFrame(plotSection, plot);
    repositionPlotlyAnnotation0(plot);
}

// Re-run on window resize (debounced to avoid thrashing).
var _vpResizeTimer = null;
window.addEventListener("resize", function() {
    clearTimeout(_vpResizeTimer);
    _vpResizeTimer = setTimeout(resizePlotToViewport, 100);
});

// Re-run after each Shiny idle cycle — covers the initial page load
// (when the plot is first rendered) and any filter-driven re-renders.
$(document).on("shiny:idle", resizePlotToViewport);


// ── Close dropdown on outside click ──────────────────────────────────────────

// The <details> element doesn't close itself when the user clicks elsewhere.
// This listener closes any open dropdown when a click lands outside it.
document.addEventListener("click", function(e) {
    document.querySelectorAll(".filters-details, .toggles-details").forEach(function(details) {
        if (details.open && !details.contains(e.target)) {
            details.open = false;
        }
    });
});


// ── Shiny message handler ─────────────────────────────────────────────────────

// Sent by mod_toggles_server when the "Table" switchInput changes value.
//   msg.show = true  → table is now ON  → remove "grow", restore split layout
//   msg.show = false → table is now OFF → add "grow", expand plot to full width
Shiny.addCustomMessageHandler("toggleTable", function(msg) {
    var plot_container = document.getElementById("plot_section");
    var main_area      = document.getElementById("main_area");
    var plot           = document.getElementById("egm-egm_plot");

    if (msg.show) {
        // Restore split layout: un-hide the table column and un-expand the plot.
        main_area.classList.remove("table-hidden");
        plot_container.classList.remove("grow");
        // Recompute the correct proportional width immediately so the smooth
        // resize transition starts from the right dimensions.
        resizePlotToViewport();
    } else {
        // Collapse the table column to zero and expand the plot to full width.
        main_area.classList.add("table-hidden");
        plot_container.classList.add("grow");
    }

    resizePlotlySmooth(plot_container, plot);
});


// ── Help modal dismiss: backdrop click or Escape key ─────────────────────────
document.addEventListener("click", function(e) {
    var modal = document.getElementById("egm-help-modal");
    if (modal && modal.classList.contains("open") && e.target === modal) {
        modal.classList.remove("open");
    }
});

document.addEventListener("keydown", function(e) {
    if (e.key === "Escape") {
        var modal = document.getElementById("egm-help-modal");
        if (modal) modal.classList.remove("open");
    }
});