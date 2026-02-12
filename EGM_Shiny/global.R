library(shiny)
library(tidyverse)
library(plotly)
library(stringr)

# define important colors and share with css
colors <- list(
    all_points = "#1f77b4",
    high_confidence = "#46A040",
    medium_confidence = "#FDB915",
    low_confidence = "#CC3D3D",
    in_progress = "#FFC0CB"
)
css <- paste0(
    ":root {",
    paste0("--color-", names(colors), ": ", unlist(colors), ";", collapse = ""),
    "}"
)
writeLines(css, "www/colors_runtime.css")

# Read data
# any data cleaning needed?
df_all <- read_csv("data/batch3_resolved_amgedit.csv") %>%
    mutate(
        WorkType = replace_na(WorkType, "None Given"),
        Theme.Assignment = replace_na(Theme.Assignment, "None Given")
    )
df_high <- df_all %>% filter(review_confidence == 3)
df_medium <- df_all %>% filter(review_confidence == 2)
df_low <- df_all %>% filter(review_confidence == 1)
df_ongoing <- df_all %>% filter(in_progress == 1)


# create new dataframes that can be used for the egm plot
create_counts <- function(df){
    df %>%
        count(WorkType, Theme.Assignment) %>%
        # re-order
        mutate(
            WorkType = fct_relevel(factor(WorkType), "Other", "None Given", after = Inf),
            Theme.Assignment = fct_relevel(factor(Theme.Assignment),  "None Given", "Other")
        )
}

# create a list of lists to map the dataframes and values to the trace ids
egm_data <- list(
    all = list(display_text = NULL, df = df_all, counts = create_counts(df_all), color = colors$all_points, index = 0, offset_x = 0, offset_y = 0),
    high = list(display_text = "High Confidence", df = df_high, counts = create_counts(df_high), color = colors$high_confidence, index = 1, offset_x = 0.35, offset_y = 0.35),
    medium = list(display_text = "Medium Confidence", df = df_medium, counts = create_counts(df_medium), color = colors$medium_confidence, index = 2, offset_x = 0, offset_y = 0.35),
    low = list(display_text = "Low Confidence", df = df_low, counts = create_counts(df_low), color = colors$low_confidence, index = 3, offset_x = -0.35, offset_y = 0.35),
    ongoing = list(display_text = "In Progress", df = df_ongoing, counts = create_counts(df_ongoing), color = colors$in_progress, index = 4, offset_x = -0.17, offset_y = -0.35)
)

message("global.R sourced successfully")
