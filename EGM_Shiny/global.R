message("global.R has been sourced")

library(shiny)
library(tidyverse)
library(plotly)
library(stringr)
library(DT)

# Read data and do initial cleaning
batch3_df <- read_csv("data/batch3_resolved.csv") %>%
    distinct(Phase, Assignment, Directory, .keep_all = TRUE) %>% #!!! THIS NEEDS TO BE UPDATED
    mutate(internal_id = row_number()) %>%
    mutate(
      WorkType = replace_na(WorkType, "None Given"),
      Theme.Assignment = replace_na(Theme.Assignment, "None Given"),
    )

# !!!!!
# I will also need to ensure that each doc is only included once with the correct values
# currently I'm just taking the first entry
# !!!

# create a new dataframe that can be used for the egm plot
batch3_egm_counts <- batch3_df %>%
  count(WorkType, Theme.Assignment) %>%
  mutate(
    WorkType = fct_relevel(factor(WorkType), "Other", "None Given", after = Inf),
    Theme.Assignment = fct_relevel(factor(Theme.Assignment),  "None Given", "Other")
  )
