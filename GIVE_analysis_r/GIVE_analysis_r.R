
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

nrel <- read.csv(here("data/NREL/wtk_site_metadata.csv"), header = TRUE)
head(nrel)
dim(nrel)
