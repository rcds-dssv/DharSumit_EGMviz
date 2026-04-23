# CLAUDE.md — EGM Shiny App

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
│   ├── AAHHC_Scoping_2026_AMGclean.csv   # active dataset (referenced in user_config.R)
│   └── README.md          # data cleaning notes and papers with broken DOIs
├── R/
│   ├── mod_egm_plot.R     # plotly EGM figure builder + mod_plot_ui/server
│   ├── mod_filter.R       # filter dropdowns + reset; updates egm_data reactive
│   ├── mod_toggles.R      # heatmap / dot layer toggle switches; uses plotlyProxy
│   ├── mod_papers.R       # plot click/lasso selection → paper cards table
│   ├── mod_comparison_plots.R  # Count / Year / Meta comparison charts
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
| `y_column` / `y_column_display` | Grid y-axis column name + display label |
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
            ├── writes www/styles_runtime.css
            └── writes www/config.js

server():
    egm_data (reactiveVal) ←── mod_filter_server  (re-filters df_all on dropdown change)
         │
         ├── mod_plot_server      → renderPlotly (full re-render on data change)
         ├── mod_toggles_server   → plotlyProxy restyle (layer visibility, no re-render)
         ├── mod_click_server     → paper cards table; returns clicked_df, clicked_info
         ├── mod_export_server    ← clicked_df, clicked_info
         └── mod_comparison_plots_server ← clicked_info, egm_data
```

`reset_egm_trigger` is an integer `reactiveVal` incremented on every filter change; modules that need to clear state observe it.

## Key design patterns

- **`egm_metadata`** (built in `app_config.R`): a named list keyed by `"all"`, `"high"`, `"medium"`, `"low"`, `"in_progress"`. Each entry has `color`, `index` (0-based plotly trace index), `offset_x/y`, and `display_text`. Trace index order is: 0 = heatmap, 1 = all, then confidence (if enabled), then in_progress (if enabled). Any code that touches specific traces must use these indices.

- **`initial_egm_data`** (global): the unfiltered dataset. Marker sizes and axis levels always reference this so the plot grid stays stable when filters are applied.

- **Toggle vs. re-render**: filter changes trigger a full `renderPlotly` re-render; toggle changes use `plotlyProxy` / `restyle` to avoid re-rendering. `create_egm_figure()` reads toggle states via `isolate()` so a filter-triggered re-render restores the last toggle state.

- **`customdata` on plotly markers**: each dot carries a `list(x_label, y_label, trace_id)` triplet, set in `add_to_counts_df_for_plotly()`. `plot_interactions.js` reads this on click/lasso and passes it to R via `input$plotly_accumulated_selection`.

- **Runtime-generated file**: `www/styles_runtime.css` is written fresh each time `app_config.R` runs. Do not edit it manually; its content comes from `user_config.R`. The default theme is injected as an inline `<script>` in `app.R` (rather than a separate file) so `layout.js` can read it before CSS is parsed.

- **`bib_col_name()`**: defined once in `app_config.R`. It maps a BibTeX field key (e.g. `"author"`) to the CSV column name via `egm_definition$paper_citation_bibtex_field_map`.

## Dependencies

R packages: `shiny`, `dplyr`, `readr`, `tidyr`, `forcats`, `plotly`, `stringr`, `shinyWidgets`, `writexl`, `jsonlite`, `scales`, `viridisLite`

## Data notes

- NA values in the x/y axis columns are replaced with `"Other"` at load time.
- NA values in filter columns are replaced with `"Other"` at load time.
- `"Other"` and `"None Given"` categories are always sorted to the end of axes (`fct_relevel` in `create_counts()`).
