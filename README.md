# Hearing Literature Evidence Gap Map

An interactive R Shiny dashboard for exploring hearing-related research literature as an **Evidence Gap Map (EGM)**. Papers are plotted as bubbles on a 2D grid — Work Type × Theme — where bubble size reflects the number of papers at each intersection. Users can filter the dataset, select bubbles to inspect individual papers, and export citations in multiple formats.

**Live app:** [shinyapps.io](http://j1c7eu-sumitdharnu.shinyapps.io/egm_shiny)

---

## Features

- **Interactive EGM plot** — click or lasso-select bubbles to surface matching papers
- **Full-text search** — keyword search across title, authors, journal, and configurable metadata fields; results appear as orange dots on the map and drive the paper panel and comparison plots
- **Filters** — narrow the map by study origin, research type, setting, and more
- **Paper cards** — scrollable list of selected papers with full citation and metadata; DOI links open in a new tab
- **Comparison plots** — Count, Year, and Meta breakdown charts for the current selection (Year chart supports Stacked Bar and Line views)
- **Export** — download selected papers as CSV, Excel, JSON, APA, AMA, Chicago, BibTeX, or RIS
- **Light / dark theme** — toggled in the UI; preference saved in `localStorage`
- **Collapsible / resizable panels** — drag handles between the plot and paper panels; header sections collapse with arrow buttons

---

## Repository layout

```
DharSumit_EGMviz/
├── EGM_Shiny/              # Shiny application root
│   ├── app.R               # UI layout + server wiring
│   ├── app_config.R        # Startup: loads libraries, data, builds globals, writes runtime CSS/JS
│   ├── user_config.R       # ← all user-facing configuration (see below)
│   ├── data/
│   │   ├── AAHHC_Scoping_2026_final.csv   # active dataset (not included on GitHub)
│   ├── R/
│   │   ├── mod_egm_plot.R          # plotly EGM figure builder
│   │   ├── mod_filter.R            # filter dropdowns
│   │   ├── mod_toggles.R           # heatmap / dot layer toggles
│   │   ├── mod_papers.R            # selection state + paper cards table
│   │   ├── mod_search.R            # full-text search; orange dot layer on EGM plot
│   │   ├── mod_comparison_plots.R  # Count / Year / Meta comparison charts
│   │   ├── mod_export.R            # citation and data export
│   │   └── mod_help_modal.R        # help / instructions modal
│   └── www/
│       ├── styles.css              # main stylesheet
│       ├── styles_runtime.css      # generated at startup (colors, layout dimensions)
│       ├── layout.js               # panel resize, collapse, theme toggle
│       └── plot_interactions.js    # plotly click/lasso selection handlers
└── README.md
```

---

## Running the app

**Include the data file:**

The data file is not included on GitHub.  You will need to put the file
in the `data` directory.  The current code expects a data file named : `AAHHC_Scoping_2026_final.csv`.  This can be changed in the `EGM_Shiny/user_config.R` file (see description below).

**Prerequisites:** R ≥ 4.1 and the following packages:

```r
install.packages(c(
    "shiny", "dplyr", "tidyr", "forcats",
    "plotly", "stringr", "shinyWidgets", "writexl",
    "jsonlite", "scales", "viridisLite"
))
```

**Launch:**

```r
shiny::runApp("EGM_Shiny")   # from the repo root
```

The working directory must be `EGM_Shiny/` when calling `runApp()` because data and `www/` paths are relative to it.


This app was deployed on shinyapps.io using the following command from the GitHub root directory:

```r
rsconnect::deployApp(appDir = "EGM_shiny", account = "<account-name>")
```

(and replace `<account-name>` with the actual name.)

---

## Configuration

Nearly everything a developer would need to change when adapting this app to a new dataset lives in **`EGM_Shiny/user_config.R`** — no other files should need editing for a typical adaptation.

| Key | Purpose |
|-----|---------|
| `datafile_path` | Relative path to the CSV |
| `app_title` | Title shown in the header bar |
| `app_description` | Short description in the header and help modal |
| `app_acknowledgements` | Credits text in the help modal |
| `comparison_panel_default_height_px` | Initial height of the comparison plots panel |
| `x_column` / `x_column_display` | Grid x-axis column name + display label |
| `x_column_descriptions` | Optional named character vector mapping x-axis category values → plain-text descriptions; shown as a bulleted list under "Reading the Map" in the help modal in the order defined. `NULL` to omit. |
| `y_column` / `y_column_display` | Grid y-axis column name + display label |
| `y_column_descriptions` | Optional named character vector mapping y-axis category values → plain-text descriptions; shown as a bulleted list under "Reading the Map" in the help modal in the order defined. `NULL` to omit. |
| `filter_dropdown_list` / `_display` | Columns used for filter dropdowns |
| `confidence_column_name` | Optional: numeric column (1/2/3); `NA` to disable |
| `in_progress_column_name` | Optional: binary column; `NA` to disable |
| `paper_title_column` | Column for the paper card heading |
| `paper_doi_column` | Column for DOI links; `NA` to disable |
| `paper_citation_columns` / `_display` / `_bold` | Inline citation fields on each card |
| `paper_meta_columns` / `_display` | Badge pill metadata fields |
| `paper_sort_columns` / `_display` | Sort dropdown options |
| `paper_citation_bibtex_field_map` | Maps CSV column names → BibTeX field names (used by export) |
| `search_columns` | Column names searched by the Search panel (case-insensitive substring match, OR across columns) |
| `plot_colors` | Data visualization colors (same for both themes); includes `search_points` for the orange search-result dot layer |
| `web_dark_colors` / `web_light_colors` | UI colors for dark and light mode |
| `default_theme` | `"dark"` or `"light"` |

### Runtime-generated files

At startup, `app_config.R` writes one file that must **not** be edited manually — it is regenerated from `user_config.R` every time the app launches:

- `www/styles_runtime.css` — CSS custom properties for colors and computed layout dimensions

The default theme is injected as an inline `<script>` tag by `app.R` so `layout.js` can read it before CSS is parsed (preventing a flash of the wrong theme).

---

## Architecture notes

- **Module structure** — each `R/mod_*.R` file is a self-contained Shiny module with a `_ui()` and `_server()` function. `app.R` wires them together and owns the two shared reactive values: `egm_data` (the filtered dataset) and `reset_egm_trigger` (incremented on every filter change to clear selection state).
- **Toggle vs. re-render** — filter changes trigger a full `renderPlotly` re-render of the EGM; toggle (layer visibility) changes use `plotlyProxy` / `restyle` so the figure is updated in place without a round-trip to R.
- **Selection flow** — `plot_interactions.js` handles Ctrl/Cmd+click accumulation and applies `selectedpoints` visual dimming synchronously in the browser, then sends the accumulated selection to R via a custom Shiny input (`plotly_accumulated_selection`). `mod_papers.R` consumes this to render the paper cards table.
- **Search flow** — `mod_search_server` filters `egm_data()$all$df` on every keystroke and updates an orange dot layer on the EGM via `plotlyProxy` (no re-render). `app.R` creates a `comparison_egm_data` reactive that substitutes search results into `egm_data$all$df` so the paper panel and comparison plots reflect only matched papers. Search and plot selection are mutually exclusive: activating one clears the other.
- **Stable axis / sizing** — marker sizes and axis levels always reference `initial_egm_data` (the unfiltered dataset loaded at startup) so the grid and dot proportions stay consistent as filters are applied.

---

## Data notes

The data file is not included on GitHub.  In order for the app to run, you must include a datafile (e.g., within the `EGM_Shiny/data/` directory which you may have to create).  Update the settings in `EGM_Shiny/user_config.R` as needed to accommodate your data file.     

The following actions are taken in the code:
- NA values in the x/y axis columns are replaced with `"Other"` at load time.
- NA values in filter columns are replaced with `"Other"` at load time.
- `"Other"` and `"None Given"` categories are sorted to the end of each axis.

---

## Development

This codebase was developed by [Aaron M. Geller](https://www.it.northwestern.edu/departments/it-services-support/research/staff/geller.html) with assistance from [Claude](https://claude.ai) (Anthropic).  The literature review was performed by [Sumit Dhar](https://www.northwestern.edu/provost/about/bios/sumitrajit-sumit-dhar.html), [Jasleen Singh](https://www.umass.edu/public-health-sciences/about/directory/jasleen-singh) and their colleagues