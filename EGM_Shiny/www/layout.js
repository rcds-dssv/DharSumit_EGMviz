// =============================================================================
// layout.js — panel drag-resize and UI interaction
//
// The EGM plot is sized entirely in R (create_egm_figure in mod_plot.R) using
// egm_definition$plot_cell_size_px.  No client-side resizing is performed.
// The .plot-wrapper scrolls horizontally / vertically when the figure is larger
// than the panel, and the resize handle lets the user widen the plot panel.
// =============================================================================


// ── Constants ─────────────────────────────────────────────────────────────────

// Minimum table panel width — matches the CSS minmax() floor on the grid column.
var MIN_TABLE_W = 100;
var MIN_PLOT_W = 100;


// ── Draggable resize handle ───────────────────────────────────────────────────

var _resizeDragging = false;
var _resizeStartX   = 0;
var _resizeStartW   = 0;

document.addEventListener("DOMContentLoaded", function() {
    var handle = document.getElementById("resize_handle");
    if (!handle) return;
    handle.addEventListener("mousedown", function(e) {
        var plotSection = document.getElementById("plot_section");
        if (!plotSection) return;
        _resizeDragging = true;
        _resizeStartX   = e.clientX;
        _resizeStartW   = plotSection.offsetWidth;
        handle.classList.add("dragging");
        document.body.style.cursor     = "col-resize";
        document.body.style.userSelect = "none";
        e.preventDefault();
    });
});

document.addEventListener("mousemove", function(e) {
    if (!_resizeDragging) return;
    var plotSection = document.getElementById("plot_section");
    var mainArea    = document.getElementById("main_area");
    if (!plotSection) return;

    // set the panel min and max size based on the MIN_TABLE_W and MIN_PLOT_W above
    var maxPanelW = mainArea ? (mainArea.offsetWidth - 6 - MIN_TABLE_W) : Infinity;
    var newW      = Math.min(maxPanelW, Math.max(MIN_PLOT_W, _resizeStartW + (e.clientX - _resizeStartX)));

    plotSection.style.width = newW + "px";
    // The plot figure size is fixed — the wrapper scrolls if the panel is narrower.
});

document.addEventListener("mouseup", function() {
    if (!_resizeDragging) return;
    _resizeDragging = false;
    var handle = document.getElementById("resize_handle");
    if (handle) handle.classList.remove("dragging");
    document.body.style.cursor     = "";
    document.body.style.userSelect = "";
});


// ── Close <details> dropdowns on outside click ────────────────────────────────

document.addEventListener("click", function(e) {
    document.querySelectorAll(".plot-config-details, .export-details").forEach(function(d) {
        if (d.open && !d.contains(e.target)) d.open = false;
    });
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