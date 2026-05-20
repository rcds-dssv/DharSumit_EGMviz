// =============================================================================
// layout.js — panel drag-resize and UI interaction
//
// The .plot-wrapper scrolls horizontally / vertically when the figure is larger
// than the panel, and the resize handle lets the user widen the plot panel.
// This script also handles open/close of various modals and divs in the UI.
// =============================================================================


// ── Initial theme setup ───────────────────────────────────────────────────────
// This IIFE runs synchronously (before CSS is parsed) to set data-theme on
// <html>, preventing a flash of the wrong theme.  The default theme comes from
// window.EGM_DEFAULT_THEME, written to config.js by app_config.R at startup.
// localStorage overrides the default on subsequent visits.
(function () {
    var s = null;
    try { s = localStorage.getItem("egm-theme"); } catch (e) {}
    document.documentElement.setAttribute(
        "data-theme", s || window.EGM_DEFAULT_THEME || "dark"
    );
})();


// ── Constants ─────────────────────────────────────────────────────────────────

// Hard minimum sizes for draggable panels.
// Values are read from the --min-panel-w / --min-panel-h CSS custom properties
// defined in styles.css (:root), which is the single source of truth.
// Declared here at module scope so they are accessible to all event handlers;
// assigned inside DOMContentLoaded once computed styles are available.
var MIN_TABLE_W, MIN_PLOT_W, MIN_PAPERS_H, MIN_COMPARISON_H;

// When a panel shrinks below this size the panel contents are hidden and a
// label strip is shown instead.  The user can still drag further down to the
// hard minimum above.
var COLLAPSE_W = 100;
var COLLAPSE_H = 100;


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
    // Read minimum panel sizes from CSS custom properties (styles.css :root).
    var _root   = getComputedStyle(document.documentElement);
    var _minW   = parseInt(_root.getPropertyValue("--min-panel-w")) || 20;
    var _minH   = parseInt(_root.getPropertyValue("--min-panel-h")) || 20;
    MIN_TABLE_W = MIN_PLOT_W       = _minW;
    MIN_PAPERS_H = MIN_COMPARISON_H = _minH;

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

            // Toggle collapsed strip when panels shrink below the threshold.
            compPanel.classList.toggle("panel-collapsed", newH < COLLAPSE_H);
            var papersPanel = document.getElementById("papers_subpanel");
            if (papersPanel) {
                var papersH = tableSection.offsetHeight - 6 - newH;
                papersPanel.classList.toggle("panel-collapsed", papersH < COLLAPSE_H);
            }
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

    // Toggle collapsed strip when panels shrink below the threshold.
    plotSection.classList.toggle("panel-collapsed", newW < COLLAPSE_W);
    var tableSection = document.getElementById("table_section");
    if (tableSection && mainArea) {
        var tableW = mainArea.offsetWidth - 6 - newW;
        tableSection.classList.toggle("panel-collapsed", tableW < COLLAPSE_W);
    }
});

document.addEventListener("mouseup", function() {
    if (_vResizeDragging) {
        _vResizeDragging = false;
        var vHandle = document.getElementById("v_resize_handle");
        if (vHandle) vHandle.classList.remove("dragging");
        document.body.style.cursor     = "";
        document.body.style.userSelect = "";
        resizeComparisonPlot();
    }
    if (!_resizeDragging) return;
    _resizeDragging = false;
    var handle = document.getElementById("resize_handle");
    if (handle) handle.classList.remove("dragging");
    document.body.style.cursor     = "";
    document.body.style.userSelect = "";
    resizeComparisonPlot();
});


// ── Comparison plot resize ────────────────────────────────────────────────────

// Tells plotly to re-fit the comparison plot to its current container size.
// Called after either drag handle is released and after window resize.
// Debounced so rapid calls (e.g. window resize events) only fire once settled.
var _windowResizeTimer = null;
function resizeComparisonPlot() {
    if (!window.Plotly) return;
    var gd = document.querySelector("#comparison_subpanel .js-plotly-plot");
    if (gd) {
        clearTimeout(_windowResizeTimer);
        _windowResizeTimer = setTimeout(function() {
            Plotly.relayout(gd, { width: gd.offsetWidth });
        }, 150);
    }
}

// Debounced window resize so we only fire once the user stops dragging the
// browser edge (not on every pixel of movement).
window.addEventListener("resize", resizeComparisonPlot);


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

Shiny.addCustomMessageHandler("setFilterVisibility", function(msg) {
    var el = document.getElementById(msg.id);
    if (!el) return;
    el.style.display = msg.show ? "" : "none";
});


// ── Section collapse (header-instructions / controls-toolbar / search-toolbar) ─

function toggleSectionCollapse(btn) {
    var section = btn.closest(".header-instructions, .controls-toolbar, .search-toolbar");
    if (!section) return;
    var collapsed = section.classList.toggle("section-collapsed");
    btn.innerHTML = collapsed ? "&#9662;" : "&#9652;";  // ▾ collapsed, ▴ expanded
}


// ── Light / dark theme toggle ─────────────────────────────────────────────────

// Switches the data-theme attribute on <html> between "dark" and "light" and
// persists the user's choice in localStorage.
// The icon on the toggle button is driven entirely by CSS (::before pseudo-element)
// so no JS manipulation of button content is needed here.
function toggleTheme() {
    var html     = document.documentElement;
    var isDark   = html.getAttribute("data-theme") !== "light";
    var newTheme = isDark ? "light" : "dark";
    html.setAttribute("data-theme", newTheme);
    try { localStorage.setItem("egm-theme", newTheme); } catch(e) {}
}


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


// ── Sticky x-axis bar ─────────────────────────────────────────────────────────
//
// When the user scrolls down inside .plot-wrapper far enough that the plotly
// x-axis colored rectangle is no longer visible, show an HTML overlay at the
// top of the visible plot area.
//
// left is fixed at the wrapper's paddingLeft so the clone stays aligned with
// the SVG at all horizontal scroll positions.  Only top tracks scrollTop.

(function () {
    document.addEventListener("DOMContentLoaded", function () {
        var w = document.getElementById("plot_wrapper");
        var b = document.getElementById("egm_sticky_xaxis");
        if (!w || !b) return;
        var thr  = parseInt(b.dataset.threshold) || 65;
        var padL = parseInt(getComputedStyle(w).paddingLeft) || 20;
        w.addEventListener("scroll", function () {
            var show = w.scrollTop > thr;
            b.style.display = show ? "block" : "none";
            if (show) {
                b.style.top  = w.scrollTop + "px";
                b.style.left = padL        + "px";
            }
        });
    });
}());


// ── EGM plot: post-render hooks (Total N tagging + sticky x-axis sync) ────────
//
// A MutationObserver waits for the plotly widget to appear in #plot_wrapper,
// then calls both hooks immediately and re-calls them after every
// plotly_afterplot event (fires after every responsive re-draw).
//
// tagTotalN: adds a CSS class to the Total N annotation so it can be coloured
//   theme-aware.  R's plotly schema strips unknown annotation properties
//   (including cssclass) before serialisation, so the class must be injected
//   here instead.
//
// syncStickyBar: clones the rendered <svg.main-svg> into #egm_sticky_xaxis and
//   crops the container to margin_t (120 logical px) so the bar shows only the
//   x-axis header.  Cloning the live SVG guarantees pixel-identical appearance
//   regardless of responsive scaling — no geometry needs to be recomputed in R.
(function () {
    function tagTotalN(el) {
        el.querySelectorAll(".annotation text").forEach(function (t) {
            if (t.textContent.indexOf("Total N") >= 0) {
                var ann = t.closest(".annotation");
                if (ann) ann.classList.add("total-n-label");
            }
        });
    }

    function syncStickyBar(el) {
        var bar = document.getElementById("egm_sticky_xaxis");
        if (!bar || !el) return;
        var svg = el.querySelector("svg.main-svg");
        if (!svg) return;
        var rect     = svg.getBoundingClientRect();
        var scale    = rect.height / (parseFloat(svg.getAttribute("height")) || rect.height);
        // The colored x-axis rectangle is 75 logical px tall and starts 45 logical px
        // into the top margin (margin_t=120, empty_space=45, colored_rect=75).
        // Crop the bar to just the colored rect and shift the clone up to remove
        // the empty space above it.
        var barH   = Math.round(75 * scale);
        var offset = Math.round(45 * scale);
        var clone  = svg.cloneNode(true);
        clone.style.position = "relative";
        clone.style.top      = -offset + "px";
        bar.style.width  = rect.width + "px";
        bar.style.height = barH       + "px";
        bar.innerHTML    = "";
        bar.appendChild(clone);
    }

    document.addEventListener("DOMContentLoaded", function () {
        var wrapper = document.getElementById("plot_wrapper");
        if (!wrapper) return;

        var observer = new MutationObserver(function () {
            var el = wrapper.querySelector(".js-plotly-plot");
            if (!el) return;
            observer.disconnect();
            tagTotalN(el);
            syncStickyBar(el);
            el.on("plotly_afterplot", function () {
                tagTotalN(el);
                syncStickyBar(el);
            });
        });
        observer.observe(wrapper, { childList: true, subtree: true });
    });
}());