// =============================================================================
// plot_interactions.js — plotly selection handler
//
// Forwards plotly_selected events to Shiny via a random trigger input so the
// R observer fires even when the same set of points is selected twice in a row.
//
// Why a trigger instead of observing event_data() directly?
//   Shiny only re-fires an observer when the input value changes.  If the user
//   resets the table and then re-selects the same points, event_data() returns
//   the same object and the observer would silently skip it.  Sending a new
//   Math.random() value on every selection decouples the "something changed"
//   signal from the payload, which R reads separately via event_data().
// =============================================================================


// Plotly source name and Shiny module namespace, received from R via the
// triggerAttachPlotlyClickHandler message.
var plotlySource = null;
var plotlyNs     = null;

// Fingerprint of the last plot we attached handlers to, used to avoid
// double-attaching when the message fires before the plot finishes re-rendering.
var lastPlotFingerprint = null;


// ── Helper ────────────────────────────────────────────────────────────────────

// Returns only scatter-trace points (those with our 3-element customdata).
// Heatmap cells can appear in lasso selection data but have no customdata.
function scatterPointsOnly(eventData) {
    if (!eventData || !("points" in eventData)) return [];
    return eventData.points.filter(function(p) {
        return Array.isArray(p.customdata) && p.customdata.length >= 3;
    });
}


// ── Plotly event handler ──────────────────────────────────────────────────────

handlePlotlySelected = function(eventData) {
    var pts = scatterPointsOnly(eventData);
    if (pts.length === 0) return;

    if (plotlyNs) {
        Shiny.setInputValue(
            plotlyNs + "plotly_selected_trigger",
            Math.random(),
            { priority: "event" }
        );
    }
};


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
        plot.on("plotly_selected", handlePlotlySelected);

        // When the user double-clicks, plotly fires plotly_deselect and clears
        // its own selection visual.  Tell Shiny to clear the paper table too.
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


// ── Shiny message handler ─────────────────────────────────────────────────────

Shiny.addCustomMessageHandler("triggerAttachPlotlyClickHandler", function(msg) {
    plotlySource = msg.source;
    plotlyNs     = msg.ns;
    var plot = document.getElementById("egm-egm_plot");
    if (plot) {
        plot._clickHandlerAttached = false;
    }
    attachPlotlyClickHandler();
});