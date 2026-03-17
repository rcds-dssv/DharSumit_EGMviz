// =============================================================================
// toggle_table.js — table panel toggle and Plotly resize handling
//
// Manages the "Table" toggle button in the controls bar.  When clicked, it
// expands the plot section to fill the full width (class "grow") or restores
// the split layout.  Because Plotly does not automatically resize when its
// container changes size, we must call Plotly.relayout() with explicit pixel
// dimensions after every CSS transition.
//
// Why JavaScript?
//   Plotly renders at a fixed pixel size and does not respond to CSS flexbox
//   changes.  We must explicitly read the container's new dimensions and call
//   Plotly.relayout() to trigger a re-render.  The smooth animation during the
//   CSS transition requires requestAnimationFrame() to keep calling relayout()
//   every frame while the container is animating.
// =============================================================================


// ── Resize helpers ────────────────────────────────────────────────────────────

// Computes the plot's available pixel size from its container.
//
// The offsets (-120 width, -160 height) account for padding, borders, and the
// plot header bar that sit inside plot_section but outside the plotlyOutput
// element.  Adjust these if the CSS layout changes.
function resizePlotlyFrame(plot_container, plot) {
    var new_width  = plot_container.clientWidth  - 120;
    var new_height = plot_container.clientHeight - 160;

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


// ── Toggle handler ────────────────────────────────────────────────────────────

// Expands or collapses the table panel.
//
// The "active" class on the button indicates that the table is currently shown.
// Removing "active" means the table is hidden, so the plot section should grow
// to fill the space (CSS class "grow" widens plot_section via a flex transition).
function toggleTable() {
    var plot_container = document.getElementById("plot_section");
    var plot           = document.getElementById("egm-egm_plot");

    if (this.classList.contains("active")) {
        // Table is currently visible — hide it and expand the plot
        this.classList.remove("active");
        plot_container.classList.add("grow");
    } else {
        // Table is currently hidden — restore the split layout
        this.classList.add("active");
        plot_container.classList.remove("grow");
    }

    resizePlotlySmooth(plot_container, plot);
}


// ── Initialisation ────────────────────────────────────────────────────────────

document.addEventListener("DOMContentLoaded", function() {
    document.getElementById("toggle_table").addEventListener("click", toggleTable);
});