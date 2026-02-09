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
egm_counts_all <- create_counts(df_all)
egm_counts_high <- create_counts(df_high)
egm_counts_medium <- create_counts(df_medium)
egm_counts_low <- create_counts(df_low)
egm_counts_ongoing <- create_counts(df_ongoing)

# map the trace id (defined in my plot module) to these dataframes
df_list <- list(
    all = df_all,
    high = df_high,
    medium = df_medium,
    low = df_low,
    ongoing = df_ongoing
)
egm_counts_list <- list(
    all = egm_counts_all,
    high = egm_counts_high,
    medium = egm_counts_medium,
    low = egm_counts_low,
    ongoing = egm_counts_ongoing
)
egm_colors_list <-list(
    all = "#1f77b4",
    high = "#46A040",
    medium = "#FDB915",
    low = "#CC3D3D",
    ongoing = "#FFC0CB"
)

egm_index_list <- list(
    all = 0,
    high = 1,
    medium = 2,
    low = 3,
    ongoing = 4
)