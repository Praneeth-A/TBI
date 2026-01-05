# Load required libraries
library(tidyverse)
library(lubridate)

# Redirect output to a text file
sink("Output1.txt")

# Load datasets
trader_data <- read.csv("historical_data.csv", stringsAsFactors = FALSE)
sentiment_data <- read.csv("fear_greed_index.csv", stringsAsFactors = FALSE)

# Basic structure
cat("=== TRADER DATA STRUCTURE ===\n")
str(trader_data)
cat("\n=== TRADER DATA SUMMARY ===\n")
summary(trader_data)
cat("\n=== TRADER DATA HEAD ===\n")
print(head(trader_data, 10))
cat("\n=== TRADER DATA: Missing Values ===\n")
print(colSums(is.na(trader_data)))

cat("\n\n=== SENTIMENT DATA STRUCTURE ===\n")
str(sentiment_data)
cat("\n=== SENTIMENT DATA SUMMARY ===\n")
summary(sentiment_data)
cat("\n=== SENTIMENT DATA HEAD ===\n")
print(head(sentiment_data, 10))
cat("\n=== SENTIMENT DATA: Missing Values ===\n")
print(colSums(is.na(sentiment_data)))

# Unique values for categorical columns
cat("\n=== UNIQUE VALUES ===\n")
cat("Unique Coins:", length(unique(trader_data$Coin)), "\n")
cat("Unique Accounts:", length(unique(trader_data$Account)), "\n")
cat("Unique Sides:", paste(unique(trader_data$Side), collapse=", "), "\n")
cat("Unique Directions:", paste(unique(trader_data$Direction), collapse=", "), "\n")
cat("Unique Sentiments:", paste(unique(sentiment_data$classification), collapse=", "), "\n")

# Date ranges
cat("\n=== DATE RANGES ===\n")
cat("Trader Data Date Range: Check timestamp format\n")
cat("Sentiment Data Date Range:", min(sentiment_data$date), "to", max(sentiment_data$date), "\n")

# Data dimensions
cat("\n=== DATA DIMENSIONS ===\n")
cat("Trader Data Rows:", nrow(trader_data), "| Columns:", ncol(trader_data), "\n")
# cat("Sentiment Data Rows:", nrow(sentiment_data), "| Columns:", ncol(sentiment_data), "\n")
sink()