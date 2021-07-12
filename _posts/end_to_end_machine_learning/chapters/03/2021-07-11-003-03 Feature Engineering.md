---
layout: post
title: Feature Engineering
# slug: feature-engineering
chapter: 3
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


Now that we have downloaded our stock prices, charted them, and visualized the autocorrelation between lagged (i.e. previous) prices and current prices, it's time to create or "engineer" some extra features/explanatory variables, which could help us predict future prices. 

Feature engineering is the practice of creating "features" or explanatory variables, which have predictive power (i.e. help us to forecast or classify something with machine learning).

Stock traders use what's called "[technical indicators](https://en.wikipedia.org/wiki/Technical_analysis)" in an attempt to make historical prices more predictive of future prices. In other words, they look for patterns in the historical data, hoping the same patterns will repeat in the future, and they can make some money. 

If stock traders use technical indicators to find patterns, why can't a computer do the same thing? That's what machine learning is good for--finding and classifying patterns, and using those patterns to predict or classify an outcome. So let's "engineer" a bunch of technical indicators and use them as "features" in our machine learning, stock price-predicting models.

First, create a bunch of useful columns in a new Jupyter cell:

```python
# Create a new column with the price from the previous time period, 
# and back-fill the value so we don't have any null values
df["price_prev"] = df["price"].shift(1).bfill()

# Calculate the day-over-day price change
df['delta'] = df['price'] - df['price_prev']

# Get tomorrow's price delta, which is how we'll calculate our profits
df['delta_tm'] = df['delta'].shift(-1)

# Calculate the percentage change in price, or the return
df['rt'] = df['delta'] / df['price_prev']

# Get the lagged returns for more previous days, since there's autocorrelation
df['rt1'] = df['rt'].shift(1)
df['rt2'] = df['rt'].shift(2)
df['rt3'] = df['rt'].shift(3)
df['rt4'] = df['rt'].shift(4)
df['rt5'] = df['rt'].shift(5)

# Get the next day's return, which is ultimately what we're trying to forecast/predict
df['rt_tm'] = df['rt'].shift(-1)

# Make a simpler up/down indicator, for whether the return is positive or negative
df['up_down_tm'] = np.where(df['rt_tm'] > 0, 1, 0)

# Make an up-down indicator for the returns over the next week
df['price_1wk'] = df['price'].shift(-7)
df['up_down_1wk'] = np.where(df['price_1wk'] > df['price'], 1, 0)

# Look at the first five records in the DataFrame
df.head(5)
```

### MACD
Next, we're going to hand-calculate our first stock price "technical indicator"--a very popular one called "moving average convergence-divergence" or, more popularly, just "MACD":

```python
# Calculate the 7-day and 14-day rolling average returns, and the delta between them
df['price_7d'] = df['price'].rolling(window=7, min_periods=1).mean()
df['price_14d'] = df['price'].rolling(window=14, min_periods=1).mean()

# Moving average convergence-divergence (MACD) technical indicator
# Calculate the exponential weighted moving averages for the 12 and 26 day historical periods
macd_12 = df['price'].ewm(span=12, adjust=False).mean()
macd_26 = df['price'].ewm(span=26, adjust=False).mean()
df['macd'] = macd_12 - macd_26
df['macd_signal'] = df['macd'].ewm(span=9, adjust=False).mean()
df['macd_binary'] = np.where(df['macd'] > df['macd_signal'], 10, 0)
df['price_7d_14d'] = df['price_7d'] / df['price_14d']
df['price_7d_14d_delta'] = df['price_7d_14d'] - df['price_7d_14d'].shift(1)
```

The are Python packages for calculating technical indicators like MACD for you. If you're interested, a popular package is "[ta](https://pypi.org/project/ta/)" or even "[pandas-ta](https://pypi.org/project/pandas-ta/)", but to get a little practice with the extremely important Pandas DataFrames, we're calculating them manually.

Let's see a chart of the MACD we just created.

```python
# Chart the MACD over a smaller time period
df2 = df[df['time'] >= '2020-11-01']
plt.plot(df2['time'], df2['price']/10, label='Price')
plt.plot(df2['time'], df2['macd'], label='MACD')
plt.plot(df2['time'], df2['macd_signal'], label='Signal Line')
plt.plot(df2['time'], df2['macd_binary'], label='Signal Line')
plt.legend(loc='upper left')
plt.show()
```

### RSI
Next, we'll calculate another popular technical indicator, the relative strength index (RSI). 

```python
# Calculate the 14-day relative strength index (RSI) technical indicator
# Window length for RSI moving average
window_length = 14

# Calculate the days where the price went up, otherwise zero
up = pd.Series(np.where(df['delta'] > 0, df['delta'], 0))

# Calculate the days where the price went down, otherwise zero
down = pd.Series(np.where(df['delta'] < 0, df['delta'], 0))
roll_up = up.rolling(window=window_length, min_periods=1).mean()
roll_down = down.abs().rolling(window=window_length, min_periods=1).mean()
df['RSI'] = 100.0 - (100.0 / (1.0 + (roll_up / roll_down)))

# Check out the last 3 rows in the DataFrame
df.tail(3)

# Chart the RSI technical indicator
df['RSI'].plot()
```

### CCI
Next up, the commodity channel index (CCI) technical indicator

```python
# Calculate the 3-day commodity channel index (CCI) technical indicator
df['CCI'] = (df['price'] - df['price'].rolling(3, min_periods=1).mean()) \
    / (0.015 * df['price'].rolling(3, min_periods=1).std())

df['CCI'].plot()
```

### EVM
Next, the ease of movement (EVM) volume-based technical oscillator

```python
# Calculate the ease of movement (EVM) volume-based technical oscillator
distance_moved = ((df['high'] + df['low'])/2 -
    (df['high'].shift(1).bfill() + df['low'].shift(1).bfill())/2)
box_ratio = (df['volume'] / 100_000_000) / (df['high'] - df['low'])
df['EMV'] = distance_moved / box_ratio

df['EMV'].plot()
```

### FI
Next, the force index (FI) volume-based technical oscillator

```python
# Calculate the "force index" technical oscillator,
# a measure of the "forcefullness" of the price change
df['FI'] = df['delta'] * df['volume']

df['FI'].plot()
```

That's it for technical indicators. Next we'll clean up the data. Since we're going to be using these technical indicators as "features" or "explanatory variables" to predict future stock prices, we'll remove any rows with bad data (e.g. null or infinite values).

```python
# Replace any infinite values with nulls (np.nan), and then drop all null/NA values
print(f"df.shape before: {df.shape}")
df = df.replace([np.inf, -np.inf], np.nan)
df = df.dropna()
print(f"df.shape after: {df.shape}")
df.tail(3)
```

## Feature Selection

Feature engineering and feature selection go hand in hand. Feature engineering creates the explanatory features, and feature selection chooses which features we actually want to use in our machine learning model. There are many feature selection approaches and algorithms to consider, such as:

1. Univariate selection - choosing those features which most correlate with future stock prices
2. Recursive feature elimination - removing the worst features, or keeping the best features, respectively
3. Principal component analysis - mathematically reducing the number of features by combining them
4. Feature importance - decision trees like Random Forest can be used to estimate the importance of features

If you want to read more on feature selection, I would highly recommend Jason Brownlee's [blog post](https://machinelearningmastery.com/feature-selection-machine-learning-python/) on the subject. Jason's books and articlces on machine learning are some of the best Python-based reference manuals for all things machine learning, so definitely have a look.

We are making a web app where the user can select among the different technical indicators (features), so we will leave feature selection to the website user and move on to machine learning model training, testing, and tuning. In addition, some machine learning models (e.g. LASSO or ridge regression, random forest, and neural networks, etc) can decide for themselves which features are most important, so they do their own selection.

Next up, training, testing, and tuning various machine learning models!


n_training_records = int(0.6*len(df))
df_train = df.iloc[:n_training_records]
df_test = df.iloc[n_training_records:]
print(f"df_train.shape: {df_train.shape}")
print(f"df_test.shape: {df_test.shape}")