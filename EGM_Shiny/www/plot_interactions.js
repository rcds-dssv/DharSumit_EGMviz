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

        // With dragmode:"select", clicking a point fires BOTH plotly_click AND
        // plotly_selected.  We use plotly_click as the authoritative handler for
        // single-point clicks and guard plotly_selected against re-processing it.
        var clickHandled = false;

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

// Clear selectedpoints visual and reset JS selection state.
// Called by R on "Deselect all", filter reset, and reset trigger.
Shiny.addCustomMessageHandler("clearPlotlySelection", function(msg) {
    currentSelection = [];
    var plot = document.getElementById(msg.plotId);
    if (!plot) return;
    Plotly.restyle(plot, { selectedpoints: null });
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
