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

// Pointer coordinate helpers: read from a mouse event or the first touch point
// so the same drag logic serves both mouse and touch (e.g. tablets).
function _dragClientX(e) {
    return (e.touches && e.touches.length) ? e.touches[0].clientX : e.clientX;
}
function _dragClientY(e) {
    return (e.touches && e.touches.length) ? e.touches[0].clientY : e.clientY;
}

document.addEventListener("DOMContentLoaded", function() {
    // Read minimum panel sizes from CSS custom properties (styles.css :root).
    var _root   = getComputedStyle(document.documentElement);
    var _minW   = parseInt(_root.getPropertyValue("--min-panel-w")) || 20;
    var _minH   = parseInt(_root.getPropertyValue("--min-panel-h")) || 20;
    MIN_TABLE_W = MIN_PLOT_W       = _minW;
    MIN_PAPERS_H = MIN_COMPARISON_H = _minH;

    // Horizontal handle (mouse + touch)
    var handle = document.getElementById("resize_handle");
    if (!handle) return;
    var _startHResize = function(e) {
        var plotSection = document.getElementById("plot_section");
        if (!plotSection) return;
        _resizeDragging = true;
        _resizeStartX   = _dragClientX(e);
        _resizeStartW   = plotSection.offsetWidth;
        handle.classList.add("dragging");
        document.body.style.cursor     = "col-resize";
        document.body.style.userSelect = "none";
        e.preventDefault();
    };
    handle.addEventListener("mousedown",  _startHResize);
    handle.addEventListener("touchstart", _startHResize, { passive: false });

    // Vertical handle (mouse + touch)
    var vHandle = document.getElementById("v_resize_handle");
    if (vHandle) {
        var _startVResize = function(e) {
            var compPanel = document.getElementById("comparison_subpanel");
            if (!compPanel) return;
            _vResizeDragging = true;
            _vResizeStartY   = _dragClientY(e);
            _vResizeStartH   = compPanel.offsetHeight;
            vHandle.classList.add("dragging");
            document.body.style.cursor     = "row-resize";
            document.body.style.userSelect = "none";
            e.preventDefault();
        };
        vHandle.addEventListener("mousedown",  _startVResize);
        vHandle.addEventListener("touchstart", _startVResize, { passive: false });
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

function _onDragMove(e) {
    if (!_resizeDragging && !_vResizeDragging) return;
    // Prevent the page from scrolling while a divider is being dragged by touch.
    if (e.cancelable) e.preventDefault();

    // Vertical resize
    if (_vResizeDragging) {
        var compPanel    = document.getElementById("comparison_subpanel");
        var tableSection = document.getElementById("table_section");
        if (compPanel && tableSection) {
            // Dragging up (negative delta) increases the comparison panel height.
            var maxH = tableSection.offsetHeight - 6 - MIN_PAPERS_H;
            var newH = Math.min(maxH,
                       Math.max(MIN_COMPARISON_H,
                                _vResizeStartH - (_dragClientY(e) - _vResizeStartY)));
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
    var newW      = Math.min(maxPanelW, Math.max(MIN_PLOT_W, _resizeStartW + (_dragClientX(e) - _resizeStartX)));

    plotSection.style.width = newW + "px";
    // The plot figure size is fixed — the wrapper scrolls if the panel is narrower.

    // Toggle collapsed strip when panels shrink below the threshold.
    plotSection.classList.toggle("panel-collapsed", newW < COLLAPSE_W);
    var tableSection = document.getElementById("table_section");
    if (tableSection && mainArea) {
        var tableW = mainArea.offsetWidth - 6 - newW;
        tableSection.classList.toggle("panel-collapsed", tableW < COLLAPSE_W);
    }
}
document.addEventListener("mousemove", _onDragMove);
document.addEventListener("touchmove", _onDragMove, { passive: false });

function _onDragEnd() {
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
}
document.addEventListener("mouseup",     _onDragEnd);
document.addEventListener("touchend",    _onDragEnd);
document.addEventListener("touchcancel", _onDragEnd);


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


// ── Report viewport width to Shiny ────────────────────────────────────────────
//
// mod_egm_plot.R uses this to size the EGM figure responsively (only below the
// 900px mobile breakpoint).  Sent on connect and on resize (debounced).
(function () {
    function sendViewportWidth() {
        if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue("egm_viewport_width", window.innerWidth,
                                { priority: "event" });
        }
    }
    var _vwTimer = null;
    window.addEventListener("resize", function () {
        clearTimeout(_vwTimer);
        _vwTimer = setTimeout(sendViewportWidth, 200);
    });
    // Shiny fires shiny:connected via jQuery, so a native addEventListener can
    // miss it — use the jQuery listener, plus timeout fallbacks in case the
    // event already fired before this ran.
    if (window.jQuery) jQuery(document).on("shiny:connected", sendViewportWidth);
    setTimeout(sendViewportWidth, 500);
    setTimeout(sendViewportWidth, 1500);
}());


// ── Busy overlay ──────────────────────────────────────────────────────────────
//
// A centered "Updating…" spinner shown whenever the R server is computing, so a
// slow recompute (e.g. a large EGM selection) never looks like a frozen app.
// It is revealed only after a short delay so quick updates don't flash it, and
// hidden as soon as the server goes idle.  Shiny fires shiny:busy / shiny:idle
// via jQuery, so the listeners are attached with jQuery (a native
// addEventListener would miss them).
(function () {
    var overlay = null, showTimer = null;
    var SHOW_DELAY_MS = 250;

    function buildOverlay() {
        overlay = document.createElement("div");
        overlay.id = "egm-busy-overlay";
        overlay.innerHTML =
            '<div class="egm-busy-card">' +
                '<div class="egm-busy-spinner"></div>' +
                '<div class="egm-busy-text">Updating…</div>' +
            '</div>';
        document.body.appendChild(overlay);
    }

    function onBusy() {
        if (!overlay) return;
        clearTimeout(showTimer);
        showTimer = setTimeout(function () { overlay.classList.add("visible"); },
                               SHOW_DELAY_MS);
    }

    function onIdle() {
        clearTimeout(showTimer);
        if (overlay) overlay.classList.remove("visible");
    }

    document.addEventListener("DOMContentLoaded", function () {
        buildOverlay();
        if (window.jQuery) {
            jQuery(document).on("shiny:busy", onBusy);
            jQuery(document).on("shiny:idle", onIdle);
        }
    });
}());


// ── Scroll-down hint (mobile) ─────────────────────────────────────────────────
//
// On a narrow (mobile) viewport the papers and comparison plots sit below the
// full-height plot panel, so a selection or search can produce results the user
// never sees.  When papers first appear, briefly show a hint to scroll down.
// A MutationObserver on the papers output covers both EGM selection and search
// (both populate the same container).  Shown once per page load; auto-fades and
// is dismissed early on tap or as soon as the user scrolls.  Skipped when the
// user is already scrolled toward the papers, and on desktop (>=900px), where
// the panels are already visible.
(function () {
    var hint = null, hideTimer = null, shownThisLoad = false;
    var VISIBLE_MS = 5000;

    function buildHint() {
        hint = document.createElement("div");
        hint.id = "egm-scroll-hint";
        hint.innerHTML =
            '<span class="egm-scroll-hint-arrow">&#8595;</span>' +
            '<span>Scroll down to see the selected papers &amp; comparison plots</span>';
        hint.addEventListener("click", hide);
        document.body.appendChild(hint);
    }

    function hide() {
        clearTimeout(hideTimer);
        if (hint) hint.classList.remove("visible");
    }

    function show() {
        if (shownThisLoad || !hint) return;
        if (window.innerWidth >= 900) return;   // desktop: panels already visible
        if (window.scrollY > 600) return;       // already heading toward the papers
        shownThisLoad = true;
        hint.classList.add("visible");
        hideTimer = setTimeout(hide, VISIBLE_MS);
        console.log("showing it")
    }

    document.addEventListener("DOMContentLoaded", function () {
        buildHint();
        var content = document.getElementById("egm-table_content");
        if (content) {
            var observer = new MutationObserver(function () {
                if (content.querySelector(".paper-card")) show();
            });
            observer.observe(content, { childList: true, subtree: true });
        }
        window.addEventListener("scroll", function () {
            if (hint && hint.classList.contains("visible")) hide();
        }, { passive: true });
    });
}());


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


// ── Paper card clicks: open DOI link unless the user is selecting text ────────
//
// Cards with a DOI store the URL in data-href.  A delegated click listener
// opens the link in a new tab, but only when no text is selected — so
// click-dragging to highlight text does not trigger navigation.

document.addEventListener("click", function (e) {
    var card = e.target.closest(".paper-card-link");
    if (!card) return;
    if (window.getSelection && window.getSelection().toString().length > 0) return;
    var url = card.dataset.href;
    if (url) window.open(url, "_blank", "noopener,noreferrer");
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

    // Shrink the figure to fit its scroll container on mobile when it is only
    // slightly too tall, so the whole plot is visible without an internal
    // scroll.  R sizes the figure from cell counts alone (with a 34px per-row
    // floor) and cannot know the device's available height, so the fit is done
    // here against the wrapper's real height.  Only shrinks (never stretches),
    // and only while each grid row stays legible — a genuinely tall figure
    // (many categories) keeps its natural height and scrolls.  Desktop
    // (>=900px) is untouched.
    //
    // The decision is cached per figure width (el._egmFit).  plotly_afterplot
    // also fires on selection redraws and on window resizes (mobile address-bar
    // show/hide) — none of which change the figure width — so those reuse the
    // cached target and never recompute against a transient container height.
    // Only a genuine responsive re-render (width change) measures afresh, which
    // is what keeps the plot from resizing on scroll or after a selection.
    function fitPlotHeight(el) {
        if (window.innerWidth >= 900) return;
        var fl = el._fullLayout;
        if (!fl || !fl.width || !fl._size || !fl.yaxis || !fl.yaxis.range) return;
        var w = fl.width;

        if (!el._egmFit || el._egmFit.w !== w) {
            var wrapper = document.getElementById("plot_wrapper");
            if (!wrapper) return;
            var cs     = getComputedStyle(wrapper);
            var availH = wrapper.clientHeight -
                         (parseFloat(cs.paddingTop)    || 0) -
                         (parseFloat(cs.paddingBottom) || 0);
            // Vertical margins (fixed top header + bottom) are height-independent.
            var margins = fl.height - fl._size.h;
            var nY      = fl.yaxis.range[1] - fl.yaxis.range[0];
            var target  = null;  // null => leave the figure at its natural height
            if (availH > 0 && nY > 0 &&
                fl.height - availH > 2 &&            // overflows its container
                (availH - margins) / nY >= 28) {     // rows stay legible when fitted
                target = availH - 2;
            }
            el._egmFit = { w: w, target: target };
        }

        var t = el._egmFit.target;
        if (t != null && Math.abs(fl.height - t) > 2) Plotly.relayout(el, { height: t });
    }

    // Pin the corner annotations (axis titles + Total N) just inside the SVG's
    // left edge on mobile.  R positions them from an estimate of plotly's
    // y-label gutter, but the gutter is driven by measured SVG text width, which
    // differs between devices/browsers (a real phone vs. Chrome device mode), so
    // the estimate can push them off-screen.  Reading the actual rendered margin
    // (_fullLayout._size) here is device-independent.  Desktop (>=900px) keeps
    // R's layout untouched, so it is unchanged.
    function pinAnnotations(el) {
        if (window.innerWidth >= 900) return;
        var fl = el._fullLayout;
        if (!fl || !fl._size || !fl.annotations || !fl._size.w) return;
        var sz     = fl._size;                       // .l = actual left margin, .w = data width
        var paperX = (6 - sz.l) / sz.w;              // paper-x whose left anchor sits 6px from the SVG edge
        var anns   = fl.annotations;
        var update = {}, changed = false;
        for (var i = 0; i < anns.length; i++) {
            if (Math.abs((anns[i].x || 0) - paperX) > 0.001) {
                update["annotations[" + i + "].x"] = paperX;
                changed = true;
            }
        }
        if (changed) Plotly.relayout(el, update);
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
            fitPlotHeight(el);
            pinAnnotations(el);
            tagTotalN(el);
            syncStickyBar(el);
            el.on("plotly_afterplot", function () {
                fitPlotHeight(el);
                pinAnnotations(el);
                tagTotalN(el);
                syncStickyBar(el);
            });
        });
        observer.observe(wrapper, { childList: true, subtree: true });
    });
}());