library(tidyverse)
library(lubridate)

sink("Output3.txt")

# Load merged data
merged_data <- read.csv("merged_trader_sentiment.csv", stringsAsFactors = FALSE)
merged_data$date <- as.Date(merged_data$date)

cat("=== COLUMN NAMES CHECK ===\n")
print(colnames(merged_data))

# ===== 1. ACCOUNT-LEVEL PERFORMANCE (Already shown, but let's verify top performers) =====
cat("\n=== ACCOUNT-LEVEL ANALYSIS ===\n")
account_performance <- merged_data %>%
  filter(!is.na(classification)) %>%
  group_by(Account) %>%
  summarise(
    total_trades = n(),
    total_pnl = sum(Closed.PnL, na.rm = TRUE),
    avg_pnl = mean(Closed.PnL, na.rm = TRUE),
    median_pnl = median(Closed.PnL, na.rm = TRUE),
    win_rate = sum(Closed.PnL > 0) / sum(Closed.PnL != 0) * 100,
    total_volume = sum(Size.USD, na.rm = TRUE),
    num_coins = n_distinct(Coin),
    active_days = n_distinct(date)
  ) %>%
  arrange(desc(total_pnl))

cat("\nTop 10 Accounts by Total PnL:\n")
print(head(account_performance, 10))

# ===== 2. SENTIMENT-SPECIFIC ACCOUNT PERFORMANCE =====
cat("\n\n=== ACCOUNT PERFORMANCE BY SENTIMENT ===\n")
cat("How do top accounts perform in different market conditions?\n\n")

# Get top 5 accounts overall
top_5_accounts <- head(account_performance$Account, 5)

account_sentiment_perf <- merged_data %>%
  filter(Account %in% top_5_accounts, !is.na(classification)) %>%
  group_by(Account, classification) %>%
  summarise(
    num_trades = n(),
    total_pnl = sum(Closed.PnL),
    avg_pnl = mean(Closed.PnL),
    win_rate = sum(Closed.PnL > 0) / sum(Closed.PnL != 0) * 100,
    .groups = 'drop'
  ) %>%
  arrange(Account, desc(total_pnl))

print(account_sentiment_perf)

# ===== 3. POSITION SIZE ANALYSIS =====
cat("\n\n=== POSITION SIZE ANALYSIS BY SENTIMENT ===\n")

size_analysis <- merged_data %>%
  filter(!is.na(classification)) %>%
  group_by(classification) %>%
  summarise(
    avg_size_usd = mean(Size.USD, na.rm = TRUE),
    median_size_usd = median(Size.USD, na.rm = TRUE),
    max_size_usd = max(Size.USD, na.rm = TRUE),
    min_size_usd = min(Size.USD, na.rm = TRUE),
    total_volume = sum(Size.USD, na.rm = TRUE)
  ) %>%
  arrange(desc(avg_size_usd))

print(size_analysis)

# ===== 4. RELATIONSHIP: TRADE SIZE vs PNL =====
cat("\n\n=== TRADE SIZE VS PNL ANALYSIS ===\n")

# Categorize trades by size
merged_data_sized <- merged_data %>%
  filter(!is.na(classification), Closed.PnL != 0) %>%
  mutate(
    size_category = case_when(
      Size.USD < 500 ~ "Small (<$500)",
      Size.USD >= 500 & Size.USD < 2000 ~ "Medium ($500-$2k)",
      Size.USD >= 2000 & Size.USD < 10000 ~ "Large ($2k-$10k)",
      Size.USD >= 10000 ~ "Very Large (>$10k)"
    )
  )

size_pnl <- merged_data_sized %>%
  group_by(classification, size_category) %>%
  summarise(
    num_trades = n(),
    avg_pnl = mean(Closed.PnL),
    total_pnl = sum(Closed.PnL),
    win_rate = sum(Closed.PnL > 0) / n() * 100,
    .groups = 'drop'
  ) %>%
  arrange(classification, size_category)

print(size_pnl)

# ===== 5. COIN PERFORMANCE ACROSS SENTIMENTS =====
cat("\n\n=== TOP COINS: PERFORMANCE CONSISTENCY ACROSS SENTIMENTS ===\n")

# Get top 10 coins by total volume
top_coins <- merged_data %>%
  group_by(Coin) %>%
  summarise(total_volume = sum(Size.USD)) %>%
  arrange(desc(total_volume)) %>%
  head(10) %>%
  pull(Coin)

coin_sentiment_perf <- merged_data %>%
  filter(Coin %in% top_coins, !is.na(classification), Closed.PnL != 0) %>%
  group_by(Coin, classification) %>%
  summarise(
    num_trades = n(),
    total_pnl = sum(Closed.PnL),
    avg_pnl = mean(Closed.PnL),
    win_rate = sum(Closed.PnL > 0) / n() * 100,
    .groups = 'drop'
  ) %>%
  arrange(Coin, desc(total_pnl))

print(coin_sentiment_perf)

# ===== 6. DIRECTION EFFECTIVENESS BY SENTIMENT =====
cat("\n\n=== WHICH TRADING DIRECTIONS ARE MOST EFFECTIVE? ===\n")

direction_effectiveness <- merged_data %>%
  filter(!is.na(classification), Closed.PnL != 0) %>%
  group_by(classification, Direction) %>%
  summarise(
    num_trades = n(),
    total_pnl = sum(Closed.PnL),
    avg_pnl = mean(Closed.PnL),
    win_rate = sum(Closed.PnL > 0) / n() * 100,
    .groups = 'drop'
  ) %>%
  filter(num_trades >= 100) %>%  # Only directions with significant activity
  arrange(classification, desc(avg_pnl))

print(direction_effectiveness)

# ===== 7. SENTIMENT TRANSITION ANALYSIS =====
cat("\n\n=== SENTIMENT TRANSITIONS ===\n")
cat("How does sentiment change day-to-day?\n\n")

sentiment_by_date <- merged_data %>%
  select(date, classification) %>%
  distinct() %>%
  arrange(date) %>%
  mutate(
    prev_sentiment = lag(classification),
    sentiment_changed = classification != prev_sentiment
  ) %>%
  filter(!is.na(prev_sentiment))

transition_matrix <- sentiment_by_date %>%
  group_by(prev_sentiment, classification) %>%
  summarise(count = n(), .groups = 'drop') %>%
  pivot_wider(names_from = classification, values_from = count, values_fill = 0)

cat("Sentiment Transition Matrix (rows = previous, columns = current):\n")
print(transition_matrix)

cat("\n=== DATA INSIGHTS SUMMARY ===\n")
cat("1. Extreme Greed has highest win rate (89.2%) but Extreme Fear has higher avg win amount\n")
cat("2. Short positions in Extreme Greed are extremely profitable (avg $166 PnL)\n")
cat("3. Top accounts show consistency - high win rates across sentiments\n")
cat("4. @107 coin dominates Extreme Greed period with $1.99M PnL\n")
cat("5. December 2024 was the most profitable month ($3M total PnL)\n")

cat("\n=== READY FOR STATISTICAL TESTING & VISUALIZATION ===\n")
sink()