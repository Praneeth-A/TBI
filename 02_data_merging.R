library(tidyverse)
library(lubridate)

sink("Output2.txt")

# Load data
trader_data <- read.csv("historical_data.csv", stringsAsFactors = FALSE)
sentiment_data <- read.csv("fear_greed_index.csv", stringsAsFactors = FALSE)

# ===== USE IST TIMESTAMP COLUMN (THE CORRECT ONE) =====
trader_data$datetime_ist <- dmy_hm(trader_data$Timestamp.IST)
trader_data$date <- as.Date(trader_data$datetime_ist)

# Convert sentiment date
sentiment_data$date <- as.Date(sentiment_data$date)

# ===== DATE RANGE ANALYSIS =====
cat("=== DATE RANGES (USING IST TIMESTAMP) ===\n")
cat("Trader Data Range:", as.character(min(trader_data$date)), "to", 
    as.character(max(trader_data$date)), "\n")
cat("Sentiment Data Range:", as.character(min(sentiment_data$date)), "to", 
    as.character(max(sentiment_data$date)), "\n")

overlap_start <- max(min(trader_data$date), min(sentiment_data$date))
overlap_end <- min(max(trader_data$date), max(sentiment_data$date))

cat("\nOverlap Period:", as.character(overlap_start), "to", as.character(overlap_end), "\n")
cat("Overlap Days:", as.numeric(overlap_end - overlap_start) + 1, "\n")

# ===== MERGE DATA =====
sentiment_clean <- sentiment_data %>%
  select(date, value, classification)

merged_data <- trader_data %>%
  left_join(sentiment_clean, by = "date")

# Check merge results
cat("\n=== MERGE RESULTS ===\n")
cat("Total Trades:", nrow(merged_data), "\n")
cat("Trades with Sentiment Match:", sum(!is.na(merged_data$classification)), "\n")
cat("Trades without Sentiment:", sum(is.na(merged_data$classification)), "\n")
cat("Match Rate:", round(sum(!is.na(merged_data$classification))/nrow(merged_data)*100, 2), "%\n")

# ===== ANALYZE TRADING ACTIVITY BY DATE =====
trades_by_date <- trader_data %>%
  group_by(date) %>%
  summarise(
    num_trades = n(),
    unique_accounts = n_distinct(Account),
    unique_coins = n_distinct(Coin),
    total_volume_usd = sum(Size.USD, na.rm = TRUE),
    avg_trade_size = mean(Size.USD, na.rm = TRUE)
  ) %>%
  arrange(date)

cat("\n=== TRADING ACTIVITY SUMMARY ===\n")
cat("Total Unique Trading Days:", nrow(trades_by_date), "\n")
cat("Avg Trades per Day:", round(mean(trades_by_date$num_trades), 2), "\n")
cat("Median Trades per Day:", median(trades_by_date$num_trades), "\n")

cat("\n=== FIRST 15 TRADING DAYS ===\n")
print(head(trades_by_date, 15))

cat("\n=== LAST 15 TRADING DAYS ===\n")
print(tail(trades_by_date, 15))

# ===== SENTIMENT DISTRIBUTION =====
if(sum(!is.na(merged_data$classification)) > 0) {
  
  sentiment_dist <- merged_data %>%
    filter(!is.na(classification)) %>%
    group_by(classification) %>%
    summarise(
      num_trades = n(),
      total_volume = sum(Size.USD, na.rm = TRUE),
      avg_trade_size = mean(Size.USD, na.rm = TRUE),
      pct_trades = round(n()/sum(!is.na(merged_data$classification))*100, 2)
    ) %>%
    arrange(desc(num_trades))
  
  cat("\n=== SENTIMENT DISTRIBUTION IN TRADES ===\n")
  print(sentiment_dist)
  
  # ===== PNL ANALYSIS BY SENTIMENT =====
  cat("\n=== PNL STATS BY SENTIMENT ===\n")
  pnl_stats <- merged_data %>%
    filter(!is.na(classification)) %>%
    group_by(classification) %>%
    summarise(
      num_trades = n(),
      trades_with_pnl = sum(Closed.PnL != 0),
      avg_pnl = mean(Closed.PnL, na.rm = TRUE),
      median_pnl = median(Closed.PnL, na.rm = TRUE),
      total_pnl = sum(Closed.PnL, na.rm = TRUE),
      max_profit = max(Closed.PnL, na.rm = TRUE),
      max_loss = min(Closed.PnL, na.rm = TRUE),
      num_accounts = n_distinct(Account)
    ) %>%
    arrange(desc(avg_pnl))
  print(pnl_stats)
  
  # ===== DIRECTION ANALYSIS BY SENTIMENT =====
  cat("\n=== TRADING DIRECTION BY SENTIMENT ===\n")
  direction_sentiment <- merged_data %>%
    filter(!is.na(classification)) %>%
    group_by(classification, Direction) %>%
    summarise(
      num_trades = n(),
      .groups = 'drop'
    ) %>%
    pivot_wider(names_from = Direction, values_from = num_trades, values_fill = 0)
  print(direction_sentiment)
  
} else {
  cat("\n⚠ WARNING: No sentiment matches!\n")
}

# ===== SAVE MERGED DATA =====
write.csv(merged_data, "merged_trader_sentiment.csv", row.names = FALSE)
cat("\n✓ Merged data saved as 'merged_trader_sentiment.csv'\n")

cat("\n=== NEXT STEPS ===\n")
cat("We now have clean merged data. Ready for deeper analysis!\n")
sink()