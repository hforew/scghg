
#############################
## GIVE OUTPUT ANALYSIS  ##
############################

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# 0). Preliminary -----
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

# Clean up workspace and load or install necessary packages if necessary
rm(list=ls())
want <- c("readxl","ggplot2","reshape2","restriktor"
          ,"usmap","RColorBrewer","mapproj", "maps","here")
need <- want[!(want %in% installed.packages()[,"Package"])]
if (length(need)) install.packages(need)
lapply(want, function(i) require(i, character.only=TRUE))
rm(want, need)

#----------------------
# 1) IMPORT DATA
#----------------------

here() # current project directory
gsub("GIVE_analysis_r/", "", here("GIVE") ) ## GIVE folder path 1 up from directory

path_save_n10k_CO2 <- gsub("GIVE_analysis_r/", "", here("GIVE/output/save_list/CO2-give-2020-n10000/results/model_1") ) ## GIVE folder path 1 up from directory
path_save_n10k_CO2

## PATH NOT WORKING
death_CO2_10k <- read.csv("path_save_n10k_CO2/CromarMortality_excess_deaths.csv", header = TRUE)


## FILE TOO BIG TO READ
death_CO2_10k <- read.csv("/Users/henrywilliams/Documents/GitHub/scghg/GIVE/output/save_list/CO2-give-2020-n10000/results/model_1/CromarMortality_excess_death_rate.csv", header = TRUE)

head(death_CO2_10k)
dim(death_CO2_10k)



