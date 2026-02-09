message("global.R has been sourced")

library(shiny)
library(tidyverse)
library(plotly)
library(stringr)
library(DT)

# Read data and do initial cleaning
df_all <- read_csv("data/batch3_resolved_amgedit.csv") %>%
    distinct(Phase, Assignment, Directory, .keep_all = TRUE) %>% #!!! THIS NEEDS TO BE UPDATED
    mutate(internal_id = row_number()) %>%
    mutate(
      WorkType = replace_na(WorkType, "None Given"),
      Theme.Assignment = replace_na(Theme.Assignment, "None Given"),
    )
df_high <- df_all %>% filter(review_confidence == 3)
df_medium <- df_all %>% filter(review_confidence == 2)
df_low <- df_all %>% filter(review_confidence == 1)
df_ongoing <- df_all %>% filter(in_progress == 1)

# !!!!!
# I will also need to ensure that each doc is only included once with the correct values
# currently I'm just taking the first entry
# !!!

# create new dataframes that can be used for the egm plot
create_counts <- function(df){
    df %>%
        count(WorkType, Theme.Assignment) %>%
        mutate(
            WorkType = fct_relevel(factor(WorkType), "Other", "None Given", after = Inf),
            Theme.Assignment = fct_relevel(factor(Theme.Assignment),  "None Given", "Other")
        )
}

# create a list of lists to map the dataframes and values to the trace ids
egm_data <- list(
    all = list(df = df_all, counts = create_counts(df_all), color = "#1f77b4", index = 0, offset_x = 0, offset_y = 0),
    high = list(df = df_high, counts = create_counts(df_high), color = "#46A040", index = 1, offset_x = 0.35, offset_y = 0.35),
    medium = list(df = df_medium, counts = create_counts(df_medium), color = "#FDB915", index = 2, offset_x = 0, offset_y = 0.35),
    low = list(df = df_low, counts = create_counts(df_low), color = "#CC3D3D", index = 3, offset_x = -0.35, offset_y = 0.35),
    ongoing = list(df = df_ongoing, counts = create_counts(df_ongoing), color = "#FFC0CB", index = 4, offset_x = -0.17, offset_y = -0.35)
)
