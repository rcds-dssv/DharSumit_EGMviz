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

// Programmatically click a hidden downloadButton by its namespaced id.
// Used by mod_export.R to trigger the file download after DOI validation.
Shiny.addCustomMessageHandler("triggerDownload", function(id) {
    var btn = document.getElementById(id);
    if (btn) btn.click();
});

// Enable or disable a button by its namespaced id.
// Used by mod_export.R to prevent duplicate API fetches from rapid re-clicks.
Shiny.addCustomMessageHandler("setButtonDisabled", function(msg) {
    var btn = document.getElementById(msg.id);
    if (!btn) return;
    btn.disabled    = msg.disabled;
    btn.style.opacity = msg.disabled ? "0.5"        : "";
    btn.style.cursor  = msg.disabled ? "not-allowed" : "";
});