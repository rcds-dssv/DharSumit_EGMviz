// =============================================================================
// plot_interactions.js — plotly deselect handler
//
// Shiny's plotly integration exposes event_data("plotly_selected") as a
// reactive, so R observes it directly.  The one event Shiny does not expose
// natively is plotly_deselect (double-click to clear), so we forward it here
// via a random trigger input so the R observer always fires.
//
// The handler must be re-attached after every plot re-render (e.g. a filter
// change rebuilds the figure from scratch).  R sends triggerAttachPlotlyClickHandler
// after each renderPlotly call to kick off the attach loop.
// =============================================================================


// Shiny module namespace, received from R via triggerAttachPlotlyClickHandler.
var plotlyNs = null;

// Fingerprint of the last plot we attached to, to avoid double-attaching.
var lastPlotFingerprint = null;


// ── Attach handler after Plotly renders ──────────────────────────────────────

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
        // Forward plotly_deselect (double-click) to Shiny so R can clear the table.
        plot.on("plotly_deselect", function() {
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

Shiny.addCustomMessageHandler("triggerAttachPlotlyClickHandler", function(msg) {
    plotlyNs = msg.ns;
    var plot = document.getElementById("egm-egm_plot");
    if (plot) plot._clickHandlerAttached = false;
    attachPlotlyClickHandler();
});

// Show or hide the table section + resize handle based on whether points are selected.
// Clears any inline grid style set by the resize-handle JS so CSS defaults apply when hiding.
Shiny.addCustomMessageHandler("toggleTableSection", function(msg) {
    var mainArea = document.getElementById("main_area");
    if (!mainArea) return;
    mainArea.classList.toggle("has-selection", msg.visible);
    if (!msg.visible) mainArea.style.gridTemplateColumns = "";
});

// ── Export processing overlay ─────────────────────────────────────────────────

// Show or hide the citation-fetch processing overlay.
// The overlay is opened client-side on button click (before R even receives
// the event) so the user gets immediate feedback.  It is closed when R sends
// either triggerDownload (success) or setButtonDisabled(false) (all exit paths).
function setExportProcessingOverlay(visible) {
    var overlay = document.querySelector(".export-processing-overlay");
    if (!overlay) return;
    if (visible) overlay.classList.add("open");
    else         overlay.classList.remove("open");
}

// When the Download actionButton is clicked, show the overlay immediately if
// a citation format (not csv/xlsx/json) is currently selected.
// Uses event delegation so the dynamically rendered button is always found.
document.addEventListener("click", function(e) {
    var btn = e.target.closest("button[id$='-check_download']");
    if (!btn) return;
    var ns    = btn.id.replace(/-check_download$/, "");
    var fmtEl = document.getElementById(ns + "-export_format");
    if (!fmtEl) return;
    if (["csv", "xlsx", "json"].indexOf(fmtEl.value) === -1) {
        setExportProcessingOverlay(true);
    }
});

// Programmatically click a hidden downloadButton by its namespaced id.
// Used by mod_export.R to trigger the file download after DOI validation.
// Also closes the processing overlay (success path).
Shiny.addCustomMessageHandler("triggerDownload", function(id) {
    setExportProcessingOverlay(false);
    var btn = document.getElementById(id);
    if (btn) btn.click();
});

// Enable or disable a button by its namespaced id.
// Used by mod_export.R to prevent duplicate API fetches from rapid re-clicks.
// Re-enabling also closes the processing overlay (covers all exit paths,
// including errors and the all-papers-failed case).
Shiny.addCustomMessageHandler("setButtonDisabled", function(msg) {
    var btn = document.getElementById(msg.id);
    if (!btn) return;
    btn.disabled      = msg.disabled;
    btn.style.opacity = msg.disabled ? "0.5"        : "";
    btn.style.cursor  = msg.disabled ? "not-allowed" : "";
    if (!msg.disabled) setExportProcessingOverlay(false);
});