// =============================================================================
// layout.js — panel drag-resize and UI interaction
//
// The .plot-wrapper scrolls horizontally / vertically when the figure is larger
// than the panel, and the resize handle lets the user widen the plot panel.
// This script also handles open/close of various modals and divs in the UI.
// =============================================================================


// ── Constants ─────────────────────────────────────────────────────────────────

// Minimum table panel width — matches the CSS minmax() floor on the grid column.
var MIN_TABLE_W = 150;
var MIN_PLOT_W = 150;

// Minimum heights for the papers and comparison sub-panels.
var MIN_PAPERS_H     = 150;
var MIN_COMPARISON_H = 150;


// ── Draggable resize handle ───────────────────────────────────────────────────

// ── Horizontal (plot / table) resize ─────────────────────────────────────────

var _resizeDragging = false;
var _resizeStartX   = 0;
var _resizeStartW   = 0;

// ── Vertical (papers / comparison) resize ────────────────────────────────────

var _vResizeDragging = false;
var _vResizeStartY   = 0;
var _vResizeStartH   = 0;

document.addEventListener("DOMContentLoaded", function() {
    // Horizontal handle
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

    // Vertical handle
    var vHandle = document.getElementById("v_resize_handle");
    if (vHandle) {
        vHandle.addEventListener("mousedown", function(e) {
            var compPanel = document.getElementById("comparison_subpanel");
            if (!compPanel) return;
            _vResizeDragging = true;
            _vResizeStartY   = e.clientY;
            _vResizeStartH   = compPanel.offsetHeight;
            vHandle.classList.add("dragging");
            document.body.style.cursor     = "row-resize";
            document.body.style.userSelect = "none";
            e.preventDefault();
        });
    }

    // One-time initialisation of comparison-subpanel flex-basis.
    // The CSS default is flex: 0 0 300px, which may exceed the available
    // space in a short viewport.  The drag handler already caps it correctly
    // (maxH = tableSection.offsetHeight - 6 - MIN_PAPERS_H), but that only
    // runs after the user drags.  Here we apply the same cap the first time
    // table-section becomes visible (gains a positive height), so the initial
    // render is already correct and no drag is needed to fix it.
    var tableSection = document.getElementById("table_section");
    if (tableSection && typeof ResizeObserver !== "undefined") {
        var _cpInitObserver = new ResizeObserver(function(entries) {
            var tsH = entries[0].contentRect.height;
            if (tsH <= 0) return;                            // still hidden — wait

            var compPanel = document.getElementById("comparison_subpanel");
            if (!compPanel || compPanel.dataset.flexInitialized) {
                _cpInitObserver.disconnect();
                return;
            }

            var maxH     = tsH - 6 - MIN_PAPERS_H;
            var currentH = compPanel.offsetHeight || 300;
            var h        = Math.max(MIN_COMPARISON_H, Math.min(currentH, maxH));
            compPanel.style.flex              = "0 0 " + h + "px";
            compPanel.dataset.flexInitialized = "1";
            _cpInitObserver.disconnect();
        });
        _cpInitObserver.observe(tableSection);
    }
});

document.addEventListener("mousemove", function(e) {
    // Vertical resize
    if (_vResizeDragging) {
        var compPanel    = document.getElementById("comparison_subpanel");
        var tableSection = document.getElementById("table_section");
        if (compPanel && tableSection) {
            // Dragging up (negative delta) increases the comparison panel height.
            var maxH = tableSection.offsetHeight - 6 - MIN_PAPERS_H;
            var newH = Math.min(maxH,
                       Math.max(MIN_COMPARISON_H,
                                _vResizeStartH - (e.clientY - _vResizeStartY)));
            compPanel.style.flex = "0 0 " + newH + "px";
        }
    }

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
    if (_vResizeDragging) {
        _vResizeDragging = false;
        var vHandle = document.getElementById("v_resize_handle");
        if (vHandle) vHandle.classList.remove("dragging");
        document.body.style.cursor     = "";
        document.body.style.userSelect = "";
    }
    if (!_resizeDragging) return;
    _resizeDragging = false;
    var handle = document.getElementById("resize_handle");
    if (handle) handle.classList.remove("dragging");
    document.body.style.cursor     = "";
    document.body.style.userSelect = "";
});


// ── Comparison plot minimum height ───────────────────────────────────────────
//
// R computes how many px are needed to prevent label/legend overlap and sends
// this value here.  Setting min-height (not height) on cp_inner means:
//   - when the panel is taller than min-height, the plot still fills the panel
//   - when the panel is shorter, cp_inner grows and the wrapper scrolls

Shiny.addCustomMessageHandler("setCompPlotHeight", function(msg) {
    var el = document.getElementById(msg.wrapperId);
    if (!el) return;
    el.style.minHeight = msg.height + "px";
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