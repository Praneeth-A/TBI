import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from scipy.stats import chi2_contingency, kruskal
import warnings
warnings.filterwarnings('ignore')

# Set style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (14, 8)

# Load data
merged_data = pd.read_csv("merged_trader_sentiment.csv")
merged_data['date'] = pd.to_datetime(merged_data['date'])

# Remove rows without sentiment
df = merged_data[merged_data['classification'].notna()].copy()

print("="*70)
print("STATISTICAL HYPOTHESIS TESTING")
print("="*70)

# ===== HYPOTHESIS 1: Does sentiment affect PnL? =====
print("\n### H1: Does market sentiment significantly affect trader PnL? ###\n")

# Filter only closed positions
closed_trades = df[df['Closed.PnL'] != 0].copy()

# Group PnL by sentiment
sentiment_groups = [
    closed_trades[closed_trades['classification'] == sent]['Closed.PnL'].values
    for sent in ['Extreme Fear', 'Fear', 'Neutral', 'Greed', 'Extreme Greed']
]

# Kruskal-Wallis H-test (non-parametric ANOVA)
h_stat, p_value = kruskal(*sentiment_groups)
print(f"Kruskal-Wallis H-statistic: {h_stat:.4f}")
print(f"P-value: {p_value:.6f}")

if p_value < 0.05:
    print("✓ SIGNIFICANT: Market sentiment DOES affect PnL (p < 0.05)")
else:
    print("✗ NOT SIGNIFICANT: No clear relationship (p >= 0.05)")

# Effect size calculation
sentiment_pnl = closed_trades.groupby('classification')['Closed.PnL'].agg(['mean', 'median', 'std', 'count'])
print("\nPnL by Sentiment:")
print(sentiment_pnl)

# ===== HYPOTHESIS 2: Win rate differs by sentiment? =====
print("\n\n### H2: Does win rate differ significantly across sentiments? ###\n")

# Create win/loss indicator
closed_trades['is_win'] = (closed_trades['Closed.PnL'] > 0).astype(int)

# Contingency table
contingency = pd.crosstab(closed_trades['classification'], closed_trades['is_win'])
print("\nContingency Table:")
print(contingency)

# Chi-square test
chi2, p_val, dof, expected = chi2_contingency(contingency)
print(f"\nChi-square statistic: {chi2:.4f}")
print(f"P-value: {p_val:.6f}")
print(f"Degrees of freedom: {dof}")

if p_val < 0.05:
    print("✓ SIGNIFICANT: Win rates differ by sentiment (p < 0.05)")
else:
    print("✗ NOT SIGNIFICANT: Win rates are similar (p >= 0.05)")

# ===== HYPOTHESIS 3: Long vs Short performance by sentiment =====
print("\n\n### H3: Do Long/Short strategies perform differently by sentiment? ###\n")

# Classify positions
df['position_type'] = df['Direction'].apply(
    lambda x: 'Long' if x in ['Open Long', 'Close Long', 'Buy'] 
    else ('Short' if x in ['Open Short', 'Close Short', 'Sell'] else 'Other')
)

long_short_data = df[(df['position_type'].isin(['Long', 'Short'])) & (df['Closed.PnL'] != 0)].copy()

# Test for each sentiment
for sentiment in ['Extreme Fear', 'Fear', 'Neutral', 'Greed', 'Extreme Greed']:
    sentiment_data = long_short_data[long_short_data['classification'] == sentiment]
    long_pnl = sentiment_data[sentiment_data['position_type'] == 'Long']['Closed.PnL']
    short_pnl = sentiment_data[sentiment_data['position_type'] == 'Short']['Closed.PnL']
    
    if len(long_pnl) > 0 and len(short_pnl) > 0:
        u_stat, p_val = stats.mannwhitneyu(long_pnl, short_pnl, alternative='two-sided')
        sig = "✓" if p_val < 0.05 else "✗"
        print(f"{sentiment:15} | Long avg: ${long_pnl.mean():8.2f} | Short avg: ${short_pnl.mean():8.2f} | p={p_val:.4f} {sig}")

# ===== HYPOTHESIS 4: Trade size affects profitability =====
print("\n\n### H4: Does trade size correlate with profitability? ###\n")

# Correlation test
size_pnl_data = closed_trades[['Size.USD', 'Closed.PnL']].dropna()
corr_coef, p_val = stats.spearmanr(size_pnl_data['Size.USD'], size_pnl_data['Closed.PnL'])

print(f"Spearman correlation coefficient: {corr_coef:.4f}")
print(f"P-value: {p_val:.6f}")

if p_val < 0.05:
    if corr_coef > 0:
        print("✓ SIGNIFICANT POSITIVE: Larger trades tend to be more profitable")
    else:
        print("✓ SIGNIFICANT NEGATIVE: Larger trades tend to be less profitable")
else:
    print("✗ NOT SIGNIFICANT: Trade size doesn't correlate with profitability")

print("\n" + "="*70)
print("CREATING VISUALIZATIONS...")
print("="*70)

# Create visualizations
fig = plt.figure(figsize=(20, 12))

# Plot 1: PnL Distribution by Sentiment
ax1 = plt.subplot(2, 3, 1)
sentiment_order = ['Extreme Fear', 'Fear', 'Neutral', 'Greed', 'Extreme Greed']
pnl_plot_data = closed_trades[closed_trades['Closed.PnL'].between(-1000, 1000)]
sns.violinplot(data=pnl_plot_data, x='classification', y='Closed.PnL', 
               order=sentiment_order, palette='RdYlGn', ax=ax1)
ax1.set_title('PnL Distribution by Market Sentiment', fontsize=14, fontweight='bold')
ax1.set_xlabel('Market Sentiment', fontsize=12)
ax1.set_ylabel('Closed PnL (USD)', fontsize=12)
ax1.tick_params(axis='x', rotation=45)
ax1.axhline(y=0, color='black', linestyle='--', alpha=0.5)

# Plot 2: Win Rate by Sentiment
ax2 = plt.subplot(2, 3, 2)
win_rates = closed_trades.groupby('classification').apply(
    lambda x: (x['Closed.PnL'] > 0).sum() / len(x) * 100
).reindex(sentiment_order)
bars = ax2.bar(range(len(sentiment_order)), win_rates.values, 
               color=['#d62728', '#ff7f0e', '#7f7f7f', '#2ca02c', '#1f77b4'])
ax2.set_title('Win Rate by Market Sentiment', fontsize=14, fontweight='bold')
ax2.set_xlabel('Market Sentiment', fontsize=12)
ax2.set_ylabel('Win Rate (%)', fontsize=12)
ax2.set_xticks(range(len(sentiment_order)))
ax2.set_xticklabels(sentiment_order, rotation=45, ha='right')
ax2.set_ylim(0, 100)
for i, v in enumerate(win_rates.values):
    ax2.text(i, v + 2, f'{v:.1f}%', ha='center', fontweight='bold')

# Plot 3: Long vs Short Performance
ax3 = plt.subplot(2, 3, 3)
long_short_perf = long_short_data.groupby(['classification', 'position_type'])['Closed.PnL'].mean().unstack()
long_short_perf = long_short_perf.reindex(sentiment_order)
long_short_perf.plot(kind='bar', ax=ax3, color=['#1f77b4', '#ff7f0e'])
ax3.set_title('Long vs Short: Avg PnL by Sentiment', fontsize=14, fontweight='bold')
ax3.set_xlabel('Market Sentiment', fontsize=12)
ax3.set_ylabel('Average PnL (USD)', fontsize=12)
ax3.legend(title='Position Type', fontsize=10)
ax3.tick_params(axis='x', rotation=45)
ax3.axhline(y=0, color='black', linestyle='--', alpha=0.5)

# Plot 4: Trading Volume by Sentiment Over Time
ax4 = plt.subplot(2, 3, 4)
daily_volume = df.groupby(['date', 'classification'])['Size.USD'].sum().reset_index()
for sentiment in sentiment_order:
    sent_data = daily_volume[daily_volume['classification'] == sentiment]
    ax4.plot(sent_data['date'], sent_data['Size.USD'], label=sentiment, alpha=0.7, linewidth=2)
ax4.set_title('Daily Trading Volume by Sentiment', fontsize=14, fontweight='bold')
ax4.set_xlabel('Date', fontsize=12)
ax4.set_ylabel('Total Volume (USD)', fontsize=12)
ax4.legend(fontsize=9)
ax4.tick_params(axis='x', rotation=45)

# Plot 5: Trade Size vs PnL
ax5 = plt.subplot(2, 3, 5)
sample_data = closed_trades.sample(min(5000, len(closed_trades)))
scatter = ax5.scatter(sample_data['Size.USD'], sample_data['Closed.PnL'], 
                     c=pd.Categorical(sample_data['classification']).codes, 
                     alpha=0.3, s=20, cmap='RdYlGn')
ax5.set_title('Trade Size vs PnL (5000 sample)', fontsize=14, fontweight='bold')
ax5.set_xlabel('Trade Size (USD)', fontsize=12)
ax5.set_ylabel('Closed PnL (USD)', fontsize=12)
ax5.set_xlim(0, 20000)
ax5.set_ylim(-2000, 2000)
ax5.axhline(y=0, color='black', linestyle='--', alpha=0.5)
ax5.axvline(x=0, color='black', linestyle='--', alpha=0.5)

# Plot 6: Cumulative PnL by Sentiment
ax6 = plt.subplot(2, 3, 6)
for sentiment in sentiment_order:
    sent_data = df[df['classification'] == sentiment].sort_values('date')
    cumulative_pnl = sent_data['Closed.PnL'].cumsum()
    ax6.plot(sent_data['date'], cumulative_pnl, label=sentiment, linewidth=2)
ax6.set_title('Cumulative PnL by Sentiment Over Time', fontsize=14, fontweight='bold')
ax6.set_xlabel('Date', fontsize=12)
ax6.set_ylabel('Cumulative PnL (USD)', fontsize=12)
ax6.legend(fontsize=9)
ax6.tick_params(axis='x', rotation=45)
ax6.axhline(y=0, color='black', linestyle='--', alpha=0.5)

plt.tight_layout()
plt.savefig('sentiment_analysis_visualizations.png', dpi=300, bbox_inches='tight')
print("\n✓ Visualization saved as 'sentiment_analysis_visualizations.png'")

plt.show()

print("\n" + "="*70)
print("ANALYSIS COMPLETE!")
print("="*70)
