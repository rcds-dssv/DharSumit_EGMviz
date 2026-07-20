// =============================================================================
// plot_interactions.js — plotly selection handlers
//
// Selection state is managed here in JS so that Ctrl/Cmd+click accumulation
// and the selectedpoints visual can be applied synchronously, without a
// round-trip to R causing an opacity flash.
//
// Flow:
//   plotly_selected fires for every selection (single click, box, or lasso).
//   On Ctrl/Cmd+click the new point is toggled into/out of currentSelection;
//   otherwise currentSelection is replaced.  applySelectionVisual() writes
//   selectedpoints on all traces immediately.  sendSelectionToShiny() then
//   pushes the accumulated customdata list to R via a custom input so the
//   paper table can update.
//
// The handler must be re-attached after every plot re-render (e.g. a filter
// change rebuilds the figure from scratch).  R sends
// triggerAttachPlotlyClickHandler after each renderPlotly call.
// =============================================================================


// ── Module-level state ────────────────────────────────────────────────────────

// Shiny module namespace, received from R via triggerAttachPlotlyClickHandler.
var plotlyNs = null;

// Fingerprint of the last plot we attached to, to avoid double-attaching.
var lastPlotFingerprint = null;

// Accumulated selection: array of {traceIdx, pointIdx, customdata:[x,y,trace_id]}
var currentSelection = [];

// Ctrl/Cmd key state captured at mousedown, before plotly processes the event.
var ctrlKeyHeld = false;

// Guard flag: true while Plotly.restyle is writing selectedpoints visually.
// Prevents the spurious plotly_deselect that restyle can fire from clearing R state.
var applyingVisual = false;

// Touch tap state: distinguishes a tap (single-select) from a drag (box/lasso).
var _tapStartX = 0, _tapStartY = 0, _tapMoved = false;

// True briefly after a single click/tap so the plotly_selected handler (which
// may also fire) skips re-processing it.  Shared by mouse, touch, and plotly.
var clickHandled = false;


// ── Touch tap-to-select ───────────────────────────────────────────────────────
//
// plotly's own tap→click is unreliable on touch in "select" dragmode, so on a
// tap we find the nearest selectable marker ourselves and feed it into the same
// selection flow.  A drag is left to plotly (box/lasso multi-select).  There is
// no Ctrl on touch, so a tap always replaces the selection (accumulate stays
// desktop-only via Ctrl/Cmd+click).

// Returns {traceIdx, pointIdx, customdata} for the selectable marker nearest to
// client (cx, cy) within a finger-sized radius, or null.
function nearestSelectableMarker(plot, cx, cy) {
    if (!plot || !plot._fullData || !plot._fullLayout) return null;
    var drag = plot.querySelector(".nsewdrag");
    var xa = plot._fullLayout.xaxis, ya = plot._fullLayout.yaxis;
    if (!drag || !xa || !ya || typeof xa.l2p !== "function") return null;
    var r = drag.getBoundingClientRect();
    var best = null, bestD = 34 * 34;   // ~34px tap radius (forgiving of small dots)
    for (var i = 0; i < plot._fullData.length; i++) {
        var tr = plot._fullData[i];
        if (!tr || tr.type !== "scatter" || tr.visible !== true) continue;
        var cd = tr.customdata, xs = tr.x, ys = tr.y;
        if (!cd || !cd.length || !xs || !ys) continue;
        for (var j = 0; j < xs.length; j++) {
            if (!cd[j] || cd[j].length < 3) continue;
            var dx = (r.left + xa.l2p(xs[j])) - cx;
            var dy = (r.top  + ya.l2p(ys[j])) - cy;
            var d  = dx * dx + dy * dy;
            if (d < bestD) { bestD = d; best = { traceIdx: i, pointIdx: j, customdata: cd[j] }; }
        }
    }
    return best;
}

function onEgmTouchStart(e) {
    if (!e.touches || e.touches.length !== 1) { _tapMoved = true; return; }
    _tapStartX = e.touches[0].clientX;
    _tapStartY = e.touches[0].clientY;
    _tapMoved  = false;
}
function onEgmTouchMove(e) {
    if (_tapMoved) return;
    if (!e.touches || e.touches.length !== 1) { _tapMoved = true; return; }
    if (Math.abs(e.touches[0].clientX - _tapStartX) > 10 ||
        Math.abs(e.touches[0].clientY - _tapStartY) > 10) _tapMoved = true;
}
function onEgmTouchEnd(e) {
    if (_tapMoved || applyingVisual) return;         // a drag → plotly box/lasso handles it
    var plot = e.currentTarget;
    var hit  = nearestSelectableMarker(plot, _tapStartX, _tapStartY);
    if (!hit) return;                                 // tapped empty space → ignore
    clickHandled = true;                              // suppress a following plotly_selected
    setTimeout(function() { clickHandled = false; }, 200);
    currentSelection = [hit];
    applySelectionVisual(plot);
    sendSelectionToShiny();
}


// ── Selection visual helpers ──────────────────────────────────────────────────

// Applies selectedpoints to every trace based on currentSelection.
//   heatmap traces → null   (unaffected by selection dimming)
//   scatter traces with selected points → [pointIdx, ...]
//   scatter traces with no selected points → []  (all points dimmed)
function applySelectionVisual(plotEl) {
    if (!plotEl._fullData) return;

    applyingVisual = true;
    setTimeout(function() { applyingVisual = false; }, 100);

    if (currentSelection.length === 0) {
        Plotly.restyle(plotEl, { selectedpoints: null });
        return;
    }

    // Group selected point indices by trace index.
    var byTrace = {};
    currentSelection.forEach(function(pt) {
        if (!byTrace[pt.traceIdx]) byTrace[pt.traceIdx] = [];
        byTrace[pt.traceIdx].push(pt.pointIdx);
    });

    // Build one entry per trace: null for heatmap, [] or [indices] for scatter.
    var n  = plotEl._fullData.length;
    var sp = Array(n).fill(null);
    for (var i = 0; i < n; i++) {
        if (plotEl._fullData[i].type === "heatmap") continue;
        sp[i] = byTrace[i] || [];
    }
    Plotly.restyle(plotEl, { selectedpoints: sp });
}

// Sends the customdata list of currentSelection to Shiny as a custom input.
// R observes input$plotly_accumulated_selection to update the paper table.
function sendSelectionToShiny() {
    if (!plotlyNs) return;
    Shiny.setInputValue(
        plotlyNs + "plotly_accumulated_selection",
        currentSelection.map(function(p) { return p.customdata; }),
        { priority: "event" }
    );
}


// ── Handler attach loop ───────────────────────────────────────────────────────

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

        // Capture Ctrl/Cmd state at mousedown, before plotly processes the click.
        plot.addEventListener("mousedown", function(e) {
            ctrlKeyHeld = e.ctrlKey || e.metaKey;
        });

        // Touch tap-to-select (coexists with plotly's box/lasso drag).  Stable
        // function refs so re-attaching after a re-render does not duplicate them.
        plot.addEventListener("touchstart", onEgmTouchStart, { passive: true });
        plot.addEventListener("touchmove",  onEgmTouchMove,  { passive: true });
        plot.addEventListener("touchend",   onEgmTouchEnd);

        // With dragmode:"select", clicking a point fires BOTH plotly_click AND
        // plotly_selected.  We use plotly_click as the authoritative handler for
        // single-point clicks and guard plotly_selected against re-processing it.
        // (clickHandled is declared at module scope so the touch handler shares it.)

        // ── Single-point click (and Ctrl/Cmd+click) ───────────────────────────
        // plotly_click fires reliably for any point click regardless of dragmode.
        plot.on("plotly_click", function(eventData) {
            if (!eventData || !eventData.points || eventData.points.length === 0) return;

            var newPoints = eventData.points
                .filter(function(p) { return p.customdata && p.customdata.length >= 3; })
                .map(function(p) {
                    return { traceIdx: p.curveNumber, pointIdx: p.pointNumber, customdata: p.customdata };
                });

            if (newPoints.length === 0) return;

            // Flag so the plotly_selected handler (which may also fire) is skipped.
            clickHandled = true;
            setTimeout(function() { clickHandled = false; }, 200);

            if (ctrlKeyHeld && currentSelection.length > 0) {
                // Toggle: add if absent, remove if present.
                newPoints.forEach(function(np) {
                    var idx = -1;
                    for (var i = 0; i < currentSelection.length; i++) {
                        var cp = currentSelection[i];
                        if (cp.customdata[0] === np.customdata[0] &&
                            cp.customdata[1] === np.customdata[1] &&
                            cp.customdata[2] === np.customdata[2]) { idx = i; break; }
                    }
                    if (idx >= 0) currentSelection.splice(idx, 1);
                    else          currentSelection.push(np);
                });
            } else {
                currentSelection = newPoints;
            }

            applySelectionVisual(plot);
            sendSelectionToShiny();
        });

        // ── Box-select / lasso (multi-point) ─────────────────────────────────
        // Skip if this event was already handled as a single click above, or if
        // applySelectionVisual is mid-restyle (Plotly.restyle can re-fire this event).
        plot.on("plotly_selected", function(eventData) {
            if (clickHandled || applyingVisual) return;
            if (!eventData || !eventData.points || eventData.points.length === 0) return;

            var newPoints = eventData.points
                .filter(function(p) { return p.customdata && p.customdata.length >= 3; })
                .map(function(p) {
                    return { traceIdx: p.curveNumber, pointIdx: p.pointNumber, customdata: p.customdata };
                });

            if (newPoints.length === 0) return;

            if (ctrlKeyHeld && currentSelection.length > 0) {
                newPoints.forEach(function(np) {
                    var exists = currentSelection.some(function(cp) {
                        return cp.customdata[0] === np.customdata[0] &&
                               cp.customdata[1] === np.customdata[1] &&
                               cp.customdata[2] === np.customdata[2];
                    });
                    if (!exists) currentSelection.push(np);
                });
            } else {
                currentSelection = newPoints;
            }

            applySelectionVisual(plot);
            sendSelectionToShiny();
        });

        // plotly_deselect fires on double-click — forward to R to clear the table.
        // Guard against spurious deselect fired by Plotly.restyle inside applySelectionVisual.
        plot.on("plotly_deselect", function() {
            if (applyingVisual) return;
            if (plotlyNs) {
                Shiny.setInputValue(
                    plotlyNs + "plotly_deselect_trigger",
                    Math.random(),
                    { priority: "event" }
                );
            }
        });

        plot._clickHandlerAttached = true;
        lastPlotFingerprint = plot._fullData[0].uid;
    }
}


// ── Shiny message handlers ────────────────────────────────────────────────────

// Reset JS state and re-attach handlers after every plot re-render.
Shiny.addCustomMessageHandler("triggerAttachPlotlyClickHandler", function(msg) {
    plotlyNs = msg.ns;
    currentSelection = [];
    var plot = document.getElementById("egm-egm_plot");
    if (plot) plot._clickHandlerAttached = false;
    attachPlotlyClickHandler();
});

// Clear selectedpoints visual, remove the selection shape, and reset JS state.
// Called by R on "Deselect all", filter reset, and when all dot layers go hidden.
// msg.notifyR: if true, also fire plotly_deselect_trigger so mod_click_server
//   clears clicked_info (paper table) on the R side.
Shiny.addCustomMessageHandler("clearPlotlySelection", function(msg) {
    currentSelection = [];
    var plot = document.getElementById(msg.plotId);
    if (!plot) return;
    // Guard against the plotly_deselect event that Plotly.relayout may fire
    // when clearing the selection shape.
    applyingVisual = true;
    setTimeout(function() { applyingVisual = false; }, 100);
    // Clear the selection box first so Plotly's internal deselect logic (if any)
    // fires before we explicitly restore opacity via applySelectionVisual.
    Plotly.relayout(plot, { selections: [] });
    applySelectionVisual(plot);  // currentSelection=[] → restyle(selectedpoints: null)
    if (msg.notifyR && plotlyNs) {
        Shiny.setInputValue(
            plotlyNs + "plotly_deselect_trigger",
            Math.random(),
            { priority: "event" }
        );
    }
});

// Remembered plot-panel width from the last resize, restored when the table
// re-opens so the layout snaps back to where the user left it.
var _savedPlotWidth = null;

// Show or hide the table section + resize handle based on selection state.
// On hide: saves the resized plot-panel width (if any) then clears all inline
// sizing so CSS defaults restore full-width.  On show: restores the saved width.
Shiny.addCustomMessageHandler("toggleTableSection", function(msg) {
    var mainArea    = document.getElementById("main_area");
    var plotSection = document.getElementById("plot_section");
    if (!mainArea) return;

    if (msg.visible) {
        mainArea.classList.add("has-selection");
        if (_savedPlotWidth !== null && plotSection) {
            plotSection.style.width = _savedPlotWidth;
        }
    } else {
        if (plotSection && plotSection.style.width) {
            _savedPlotWidth = plotSection.style.width;
            plotSection.style.width = "";
        }
        mainArea.classList.remove("has-selection");
        mainArea.style.gridTemplateColumns = "";
    }
});


// Programmatically click a hidden downloadButton by its namespaced id.
// Used by mod_export.R to trigger the file download.
Shiny.addCustomMessageHandler("triggerDownload", function(id) {
    var btn = document.getElementById(id);
    if (btn) btn.click();
});
