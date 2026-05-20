# CLAUDE.md — EGM Shiny App

## Maintenance reminder

**Keep `../README.md` in sync.** Whenever a feature is added, a new `user_config.R` key is introduced, or a significant architectural change is made, update the top-level `README.md` (one directory above `EGM_Shiny/`) to reflect it — specifically the Features list, the repository layout, the Configuration table, and the Architecture notes as applicable.  Minor changes that are not important for understanding the code do not need to be included in the `README.md` file.  We want this file to be lean but useful.

## What this is

An interactive R Shiny dashboard for exploring hearing-related research literature as an **Evidence Gap Map (EGM)**. Papers are displayed as bubbles on a 2D grid (Work Type × Theme). Users can filter, select, and export papers, and see comparison charts for selected cells.

## Running the app

```r
shiny::runApp("EGM_Shiny")   # from the repo root
# or from within EGM_Shiny/:
source("app.R")
```

The working directory must be `EGM_Shiny/` because data and `www/` paths are relative.

## File structure

```
EGM_Shiny/
├── app.R                  # UI layout + server wiring; thin — delegates to modules
├── app_config.R           # sourced by app.R: loads libraries, user_config.R, data,
│                          #   builds egm_metadata, helper functions, writes runtime CSS/JS
├── user_config.R          # ALL user-facing configuration lives here (see below)
├── data/
│   ├── AAHHC_Scoping_2026_AMGclean_JS.csv  # active dataset (referenced in user_config.R)
│   └── README.md          # data cleaning notes and papers with broken DOIs
├── R/
│   ├── mod_egm_plot.R     # plotly EGM figure builder + mod_plot_ui/server;
│   │                      #   also defines wrap_for_plotly() (shared with
│   │                      #   mod_comparison_plots.R) and build_heatmap_z()
│   ├── mod_filter.R       # filter dropdowns + reset; updates egm_data reactive
│   ├── mod_toggles.R      # heatmap / dot layer toggle switches; uses plotlyProxy
│   ├── mod_papers.R       # plot click/lasso selection → paper cards table
│   ├── mod_search.R       # full-text search; drives orange dot layer via plotlyProxy
│   ├── mod_comparison_plots.R  # Count / Year / Meta comparison charts;
│   │                      #   defines compute_cp_min_height() for dynamic plot sizing
│   ├── mod_export.R       # CSV / Excel / JSON / APA / AMA / Chicago / BibTeX / RIS export
│   └── mod_help_modal.R   # static help modal (client-side open/close only)
└── www/
    ├── styles.css         # main stylesheet
    ├── styles_runtime.css # generated at startup by app_config.R (colors, plot width, comparison panel height)
    ├── layout.js          # panel drag-resize, collapse, theme toggle
    └── plot_interactions.js  # plotly click/lasso accumulation, deselect handling
```

## Configuration — `user_config.R`

This is the **only file that normally needs editing** to adapt the app to a new dataset. It defines a single list `egm_definition` with:

| Key | Purpose |
|-----|---------|
| `datafile_path` | Relative path to the CSV |
| `app_title` | Title shown in the header bar |
| `app_description` | Short description shown in the header and help modal welcome |
| `app_acknowledgements` | Credits text shown in the help modal |
| `comparison_panel_default_height_px` | Initial height (px) of the comparison plots panel |
| `x_column` / `x_column_display` | Grid x-axis column name + display label |
| `x_column_descriptions` | Optional named character vector mapping x-axis category values → descriptions; shown in help modal under "Reading the Map". `NULL` to omit. |
| `y_column` / `y_column_display` | Grid y-axis column name + display label |
| `y_column_descriptions` | Optional named character vector mapping y-axis category values → descriptions; shown in help modal under "Reading the Map" in the order defined here. `NULL` to omit. |
| `filter_dropdown_list` / `_display` | Columns for filter dropdowns |
| `confidence_column_name` | Optional: numeric column (1/2/3); set `NA` to disable |
| `in_progress_column_name` | Optional: binary column; set `NA` to disable |
| `paper_title_column` | Column for the paper card heading |
| `paper_doi_column` | Column for DOI links; `NA` to disable |
| `paper_citation_columns` / `_display` / `_bold` | Inline citation fields |
| `paper_meta_columns` / `_display` | Badge pill metadata fields |
| `paper_sort_columns` / `_display` | Sort dropdown options |
| `paper_citation_bibtex_field_map` | Maps CSV column names → BibTeX field names |
| `plot_colors` | Data visualization colors (theme-invariant) |
| `web_dark_colors` / `web_light_colors` | UI colors; written to `styles_runtime.css` |
| `default_theme` | `"dark"` or `"light"` |

## Data flow

```
user_config.R
    └─► app_config.R  (startup)
            ├── reads CSV → df_all (global)
            ├── create_egm_data(df_all) → initial_egm_data (global)
            └── writes www/styles_runtime.css

server():
    egm_data (reactiveVal) ←── mod_filter_server  (re-filters df_all on dropdown change)
         │
         ├── mod_plot_server      → renderPlotly (full re-render on data change)
         ├── mod_toggles_server   → plotlyProxy restyle (layer visibility, no re-render)
         ├── mod_search_server    → plotlyProxy restyle (orange search dot layer);
         │       returns: active, df, clicked_info
         ├── mod_click_server     → paper cards table; returns clicked_df, clicked_info
         │       (search_results and clear_search_trigger wired for mutual exclusivity)
         ├── mod_export_server    ← clicked_df, clicked_info
         └── mod_comparison_plots_server ← clicked_info, comparison_egm_data
                 (comparison_egm_data replaces egm_data$all$df with search_results$df()
                  when search is active, scoping comparison plots to matched papers)
```

`reset_egm_trigger` is an integer `reactiveVal` incremented on every filter change; modules that need to clear state observe it.

## Key design patterns

- **`egm_metadata`** (built in `app_config.R`): a named list keyed by `"all"`, `"high"`, `"medium"`, `"low"`, `"in_progress"`, and `"search"`. Each entry has `color`, `index` (0-based plotly trace index), `offset_x/y`, and `display_text` (search entry has `display_text = NULL`). Trace index order is: 0 = heatmap, 1 = all, then confidence (if enabled), then in_progress (if enabled), then search (always last). Any code that touches specific traces must use these indices — never hardcode them.

- **`initial_egm_data`** (global): the unfiltered dataset. Marker sizes and axis levels always reference this so the plot grid stays stable when filters are applied.

- **Toggle vs. re-render**: filter changes trigger a full `renderPlotly` re-render; toggle changes use `plotlyProxy` / `restyle` to avoid re-rendering. `create_egm_figure()` reads toggle states via `isolate()` so a filter-triggered re-render restores the last toggle state.

- **`customdata` on plotly markers**: each dot carries a `list(x_label, y_label, trace_id)` triplet, set in `add_to_counts_df_for_plotly()`. `plot_interactions.js` reads this on click/lasso and passes it to R via `input$plotly_accumulated_selection`.

- **Group chart icons in paper cards**: `create_table_cards_html()` in `mod_papers.R` adds a colored `insert_chart` icon (Material Symbols) to each card for every comparison group that card belongs to. The colors come from `make_group_info()` (viridis palette), so the icons visually link each paper back to its bubble in the comparison plots. This requires the Google Material Symbols stylesheet loaded in `app.R`.

- **Runtime-generated file**: `www/styles_runtime.css` is written fresh each time `app_config.R` runs. Do not edit it manually; its content comes from `user_config.R`. The default theme is injected as an inline `<script>` in `app.R` (rather than a separate file) so `layout.js` can read it before CSS is parsed.

- **`bib_col_name()`**: defined once in `app_config.R`. It maps a BibTeX field key (e.g. `"author"`) to the CSV column name via `egm_definition$paper_citation_bibtex_field_map`.

- **`outputOptions(suspendWhenHidden = FALSE)`**: applied to outputs inside collapsible panels (`table_header`, `table_content` in `mod_papers.R`; `type_switcher`, `plot` in `mod_comparison_plots.R`). Without this, Shiny suspends reactive bindings when a panel is `display:none`, so expanding a previously-collapsed panel after a new selection shows stale content. Any new hidden output that must stay live needs the same treatment.

- **Dynamic comparison plot height** (`compute_cp_min_height` + `setCompPlotHeight`): `mod_comparison_plots.R` computes the minimum pixel height needed to prevent label/legend overlap (based on number of groups and bars drawn) and sends it to `layout.js` via `session$sendCustomMessage("setCompPlotHeight", list(wrapperId, height))`. The JS handler sets `min-height` on the `#cp_inner` div. `.comparison-plot-wrapper` has `overflow-y: auto`, so when the panel is shorter than `min-height` the wrapper scrolls rather than clipping the plot.

- **Heatmap 3-stop colorscale**: the heatmap trace uses stops at 0 (fully transparent), 0.0001 (`heatmap_min`), and 1.0 (`heatmap_max`). This keeps cells with 0 papers invisible while giving 1-paper cells the `heatmap_min` color. As a consequence, `heatmap_min` in `user_config.R` must **not** be fully transparent — use a low-opacity color (e.g. `rgba(31,118,180,0.2)`) so the visual ramp from 1 paper to max is meaningful.

- **`app_acknowledgements` is HTML**: the value in `user_config.R` is a raw HTML string (built with `paste0()`). It must be wrapped in `HTML()` when passed to a Shiny tag — e.g. `tags$p(HTML(egm_definition$app_acknowledgements))` — otherwise the markup is rendered as escaped text.

- **Programmatic plotly selection clearing** (`clearPlotlySelection` in `plot_interactions.js`): whenever code needs to clear the EGM plot's selection state (remove dimmed-dot opacity, remove the selection-box shape, and optionally notify R), it must send the `clearPlotlySelection` custom message — **never** call `Plotly.restyle` or `Plotly.relayout` directly for this purpose from R or other JS handlers. The correct internal order is: (1) `Plotly.relayout(plot, { selections: [] })` to clear the selection-box shape first, then (2) `applySelectionVisual(plot)` (with `currentSelection` already set to `[]`) to restore full marker opacity via `selectedpoints: null`. Doing the restyle before the relayout leaves residual opacity because Plotly's internal deselect logic (fired by the relayout) can interfere with a preceding restyle. The `applyingVisual` flag must be set to `true` around both calls to suppress the spurious `plotly_deselect` event that `Plotly.relayout` emits.

- **Sticky x-axis bar** (`#egm_sticky_xaxis`): when the user scrolls the EGM plot downward so the plotly x-axis header goes out of view, an overlay bar appears at the top of `.plot-wrapper` showing the same colored rectangle and column labels. The bar is a shell `<div>` emitted by `build_sticky_xaxis_html()` in `mod_egm_plot.R` (placed first inside `mod_plot_ui`'s `tagList`). All content is managed by JS:
  - **`syncStickyBar(el)`** in `layout.js` (inside the `plotly_afterplot` hook IIFE): after each plotly render, clones `svg.main-svg`, shifts it up by `45 * scale` px (skipping the empty space above the colored rectangle), and crops the bar container to `75 * scale` px tall (the colored-rect height). Constants: `margin_t = 120`, colored rect = 75 px tall starting at 45 px into the margin.
  - **Scroll handler** (separate IIFE in `layout.js`): shows/hides the bar when `scrollTop > 65` (threshold = wrapper padding 20 + empty space above colored rect 45). `left` is fixed at `paddingLeft` of `.plot-wrapper` (not tracking `scrollLeft`) so the clone stays horizontally aligned with the SVG at all scroll positions.
  - **CSS** (`styles.css`): three rules scoped to `#egm_sticky_xaxis` restore rendering of the clone (which sits outside `.plot-container.plotly` so main-plot rules don't apply): `svg { background: transparent }`, `.bg { fill: transparent }` (plotly's white fill rect), `text { fill: var(--color-egm-plot-text) }`.

## Dependencies

R packages: `shiny`, `dplyr`, `tidyr`, `forcats`, `plotly`, `stringr`, `shinyWidgets`, `writexl`, `jsonlite`, `scales`, `viridisLite`

## Data notes

- NA values in the x/y axis columns are replaced with `"Other"` at load time.
- NA values in filter columns are replaced with `"Other"` at load time.
- `"Other"` and `"None Given"` categories are always sorted to the end of axes (`fct_relevel` in `create_counts()`).
