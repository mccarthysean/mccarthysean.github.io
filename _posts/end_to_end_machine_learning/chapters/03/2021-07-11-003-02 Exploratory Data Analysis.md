---
layout: post
title: Exploratory Data Analysis
# slug: exploratory-data-analysis
chapter: 2
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


To start machine learning, what are the high level steps in plain English?

1. Get data
2. Explore and visualize data, and relationships between data
3. Find and create variables that help predict what we've trying to predict
4. Train and test various machine learning models to find the best one

Let's rephrase the above using data science lingo:

1. Data collection
2. Exploratory data analysis (EDA) and visualization
3. Feature engineering and feature selection
4. Model selection, testing, and tuning

Luckily for us, we've already got a web app that downloads the stock price data for us, so step 1 is taken care of. In VS Code or a Jupyter Notebook, start by adding the following imports to the first "cell".

```python
import os
import time
from math import sqrt

from dotenv import load_dotenv
import psycopg2
import pandas as pd
from pandas.plotting import autocorrelation_plot
import numpy as np
import matplotlib.pyplot as plt
import joblib
import statsmodels.api as sm
from statsmodels.tsa.arima_model import ARIMA
from sklearn.linear_model import LinearRegression, LogisticRegression, Ridge, RidgeClassifier
from sklearn.tree import DecisionTreeRegressor, export_graphviz, DecisionTreeClassifier
from sklearn.ensemble import RandomForestRegressor, AdaBoostRegressor, RandomForestClassifier, AdaBoostClassifier
from sklearn.svm import SVR, SVC
from sklearn.neighbors import KNeighborsRegressor, KNeighborsClassifier
from sklearn.neural_network import MLPRegressor, MLPClassifier
from sklearn.feature_selection import SelectFromModel, RFECV
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler, MinMaxScaler, Normalizer, OneHotEncoder
from sklearn.impute import SimpleImputer
from sklearn.model_selection import TimeSeriesSplit, cross_val_score, GridSearchCV
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.metrics import (
    mean_absolute_error, mean_squared_error, explained_variance_score,
    r2_score, confusion_matrix, accuracy_score
)
```

In the next "cell", add a function for downloading stock price data from our database, where our web app has saved it. You will need to have set the following five environment variables in your `.env` file, for connecting to the database:

```bash
# .env file
POSTGRES_HOST=
POSTGRES_PORT=
POSTGRES_DATABASE=
POSTGRES_USER=
POSTGRES_PASSWORD=
```

```python
def get_stock_price_data_from_db(ticker):
    """
    Download the stock price data from the TimescaleDB database
    and return it in a Pandas DataFrame.
    """
    sql = f"""
        select
            time,
            ticker,
            round(close_adj, 2) as price,
            round(high, 2) as high,
            round(low, 2) as low,
            volume
        from public.stock_prices
        where ticker = '{ticker}'
        order by
            ticker,
            time;
    """    
    # Load the database environment variables from the current directory
    load_dotenv()

    with psycopg2.connect(
        host=os.getenv('POSTGRES_HOST'),
        port=os.getenv("POSTGRES_PORT"), 
        dbname=os.getenv("POSTGRES_DATABASE"), 
        user=os.getenv("POSTGRES_USER"), 
        password=os.getenv("POSTGRES_PASSWORD"), 
        connect_timeout=5
    ) as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql)
            columns = [str.lower(x[0]) for x in cursor.description]
            rows = cursor.fetchall()

    # Return a DataFrame with the results
    return pd.DataFrame(rows, columns=columns)

```

In the next cell, run the function with a stock ticker whose data you previously downloaded into your web app. In this case, suppose I had previously downloaded the historical stock prices for Tesla (ticker TSLA). The function below will download the TSLA data from the database, into a Pandas DataFrame called "df":

```python
# Get stock price data from the TimescaleDB
df = get_stock_price_data_from_db(ticker='TSLA')

# Look at the first 3 rows
df.head(3)
```

In Pandas, the `head()` method looks at the first rows of the DataFrame. I specified only the top 3 rows. Likewise, the `tail()` method looks at the last few rows of the DataFrame.

Next we'll look at the types of data in each column, with the `info()` method.

```python
# Look at the column types.
# We'll need to convert everything to floating point first, to avoid errors
df.info()

# You'll get output something like this:
<class 'pandas.core.frame.DataFrame'>
RangeIndex: 2517 entries, 0 to 2516
Data columns (total 6 columns):
 #   Column  Non-Null Count  Dtype         
---  ------  --------------  -----         
 0   time    2517 non-null   datetime64[ns]
 1   ticker  2517 non-null   object        
 2   price   2517 non-null   object        
 3   high    2517 non-null   object        
 4   low     2517 non-null   object        
 5   volume  2517 non-null   object        
dtypes: datetime64[ns](1), object(5)
memory usage: 118.1+ KB
```

Most columns have been downloaded as "objects" or character strings, so we'll convert those columns to floating point numbers, so we can do some math on them.

```python
# Convert the numeric columns to numeric 'float64'
df["price"] = pd.to_numeric(df["price"])
df["high"] = pd.to_numeric(df["high"])
df["low"] = pd.to_numeric(df["low"])
df["volume"] = pd.to_numeric(df["volume"])
df.info()

# Now the info() method shows "float64" data types
<class 'pandas.core.frame.DataFrame'>
RangeIndex: 2517 entries, 0 to 2516
Data columns (total 6 columns):
 #   Column  Non-Null Count  Dtype         
---  ------  --------------  -----         
 0   time    2517 non-null   datetime64[ns]
 1   ticker  2517 non-null   object        
 2   price   2517 non-null   float64       
 3   high    2517 non-null   float64       
 4   low     2517 non-null   float64       
 5   volume  2517 non-null   float64       
dtypes: datetime64[ns](1), float64(4), object(1)
memory usage: 118.1+ KB
```

Let's see a quick chart of the prices.

```python
# Plot the data to see what we're dealing with
df['price'].plot()
```

Since we're dealing with time series data, we're going to be using historical, "lagged" prices to predict future prices. If you think about it, tomorrow's price is going to be closely related to today's price, which is close to yesterday's price, and so on. That's called autocorrelation, or correlation over time.

We previously imported autocorrelation_plot from `pandas.plotting` so let's have a look. Large positive or negative autocorrelations will be helpful as predictive "features" or "explanatory variables". 

```python
# Plot the autocorrelation for a large number of lags in the time series
# If the autocorrelation value is large, then the price depends on previous prices,
# which is almost always the case with stock prices
autocorrelation_plot(df['price'])
plt.show()
```

Now that we have looked at our data and seen that it exhibits some autocorrelation, we can move past exploratory data analysis (EDA) into feature engineering and feature selection.


{% include end_to_end_ml_table_of_contents.html %}
