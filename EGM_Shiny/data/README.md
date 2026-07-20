This directory should be populated with the data file that is displayed in the app, currently set in `../user_config.R` as `AAHHC_Scoping_2026_final.csv`.  The data file is intentionally not included on GitHub.

Ideally any new data file will already be cleaned and follow the same format as the current version.

My previous cleaning followed these conventions.  To avoid duplication and follow the style of other entries, I replaced the following (quotes needed to ensure correct matching):
- "Diversity and Equity" with "Diversity and equity"
- "ScreeningAndAssessment" with "Screening and assessment"
- "Intervention Study" with "Intervention" 
- "Mixed methods" with "Mixed Methods"
- "survey" with "Survey"
- "clinic" with "Clinic"
- "clinic, community" with "Clinic, community"
- "community" with "Community"
- "online" with "Online"
- "lab" with "Lab"
- "Cross-sectional" with "Cross Sectional"
- "LongitudinalNA" with "Longitudinal"
- "Meta-Analysis" with "Meta Analysis"
- "Systematic Review" with "Systematic"

Now, the R Shiny code will convert all labels for plot axes and filters to title case to hopefully avoid duplication in future data updates.