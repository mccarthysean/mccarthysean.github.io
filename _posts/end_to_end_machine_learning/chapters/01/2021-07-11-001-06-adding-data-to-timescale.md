---
layout: post
title: Adding Data to TimescaleDB
# slug: adding-data-to-timescale
chapter: 6
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


# Add data to TimescaleDB with Python
## Part 1, Chapter 4

Let's switch from TimescaleDB to Python for a bit to download some historical stock price data from [Yahoo Finance](https://finance.yahoo.com/) using the excellent [yfinance](https://pypi.org/project/yfinance/) library, and then insert it into TimescaleDB using the [psycopg2](https://pypi.org/project/psycopg2/) library. `yfinance` uses [Pandas](https://pandas.pydata.org/) DataFrames, so we'll use Pandas as well (Pandas is essential for data science and machine learning in Python).

Take a quick look at the following code before adding it to a new file in the project root called *get_stock_prices.py*:

```python
# get_stock_prices.py

import os
from io import StringIO

import pandas as pd
import psycopg2
import yfinance as yf


def download_prices(ticker, period="2y", interval="60m", progress=False):
    """Download stock prices to a Pandas DataFrame"""

    df = yf.download(
        tickers=ticker,
        period=period,
        interval=interval,
        progress=progress
    )

    df = df.reset_index() # remove the index
    df["ticker"] = ticker # add a column for the ticker

    # Rename columns to match our database table
    df = df.rename(columns={
        "Datetime": "time",
        "Open": "open",
        "High": "high",
        "Low": "low",
        "Close": "close",
        "Adj Close": "close_adj",
        "Volume": "volume",
    })

    return df


def upload_to_db_efficiently(df, table_name="public.stock_prices"):
    """
    Upload the stock price data to the TimescaleDB database as quickly and efficiently
    as possible by truncating (i.e. removing) the existing data and copying all-new data
    """

    with psycopg2.connect(
        host=os.getenv("POSTGRES_HOST"),
        port=os.getenv("POSTGRES_PORT"),
        dbname=os.getenv("POSTGRES_DB"),
        user=os.getenv("POSTGRES_USER"),
        password=os.getenv("POSTGRES_PASSWORD"),
        connect_timeout=5
    ) as conn:
        with conn.cursor() as cursor:
            # Truncate the existing table (i.e. remove all existing rows)
            cursor.execute(f"TRUNCATE {table_name}")
            conn.commit()

            # Now insert the brand-new data
            # Initialize a string buffer
            sio = StringIO()
            # Write the Pandas DataFrame as a CSV file to the buffer
            sio.write(df.to_csv(index=None, header=None))
            # Be sure to reset the position to the start of the stream
            sio.seek(0)
            cursor.copy_from(
                file=sio,
                table=table_name,
                sep=",",
                null="",
                size=8192,
                columns=df.columns
            )
            conn.commit()
            print("DataFrame uploaded to TimescaleDB")


if __name__ == "__main__":

    # Download prices for the four stocks in which we're interested
    msft = download_prices("MSFT")
    tsla = download_prices("TSLA")
    cvx = download_prices("CVX")
    xom = download_prices("XOM")

    # Append the four tables to each-other, one on top of the other
    df_all = pd.concat([msft, tsla, cvx, xom])

    # Erase existing data and upload all-new data to TimescaleDB
    upload_to_db_efficiently(df_all)

    print("All done!")
```

As you can see from the code above, we first download the prices for each ticker into Pandas DataFrames. Then, we concatenate those four DataFrames into one, and finally upload all the data to TimescaleDB. Note that the upload function first removes/truncates all existing data, and then inserts the brand new data.

To run the above script, you have two options. The first uses the command line directly (press "CTRL + Shift + `" to get a terminal, or select "Terminal/New Terminal" from the menu).

```bash
$ python get_stock_prices.py
```

Alternatively, select the "Run and Debug" menu on the left in VS Code, and then select "Python Run Current File" from the debug options we configured in the previous chapter (in the `./.vscode/launch.json` file). Then click the "Play" button, or press F5 to run the file.

You should see the following in the terminal:

```bash
DataFrame uploaded to TimescaleDB
All done!
```

## Queries

Head back to PGAdmin and run a quick `SELECT` query to look at the data you just inserted:

```sql
SELECT COUNT(*)
FROM stock_prices;
```

You should have roughly 14,000 rows for the two years of data on the four stocks we downloaded.

Run a simple select query to see some of our newly-inserted historical stock price data:

```sql
SELECT *
FROM stock_prices
WHERE time > (now() - interval '14 days')
ORDER BY time, ticker;
```

Notice we downloaded hourly prices.

Here's another example of selecting the aggregated data (e.g., a daily average, instead of seeing every hourly data point):

```sql
SELECT
  ticker,
  time_bucket('1 day', time) AS period,
  AVG(high) AS high,
  AVG(low) AS low,
  AVG(close_adj) AS close_adj,
  AVG(volume) AS volume
FROM stock_prices
GROUP BY
  ticker,
  time_bucket('1 day', time)
ORDER BY
  ticker,
  time_bucket('1 day', time);
```

Let's showcase two more queries. First, instead of a time series history, you might just want the *latest* data. For that, you can use the "last()" function:

```sql
SELECT
  time_bucket('1 day', time) AS period,
  AVG(close_adj) AS avg_close,
  last(close_adj, time) AS last_close --the latest value
FROM stock_prices
GROUP BY period;
```

And of course, you'll often want to join the time series data with the *metadata* (e.g., data about data). In other words, let's get the name and industry for each stock ticker:

```sql
SELECT
  time_bucket('1 day', time) AS period,
  t2.name, --from the second metadata table
  t2.industry, --from the second metadata table
  AVG(close) AS avg_close,
  last(close, time) AS last_close --the latest value
FROM stock_prices t1
INNER JOIN stock_tickers t2
  on t1.ticker = t2.ticker
GROUP BY
  period,
  t2.name,
  t2.industry;
```

TimescaleDB has another very useful feature called "[continuous aggregates](https://docs.timescale.com/latest/using-timescaledb/continuous-aggregates)" for continually and efficiently updating aggregated views of our time series data. If you often want to report/chart aggregated data, the following view-creation code is for you:

```sql
CREATE MATERIALIZED VIEW stock_prices_1_day_view
WITH (timescaledb.continuous) AS --TimescaleDB continuous aggregate
SELECT
  ticker,
  time_bucket('1 day', time) AS period,
  AVG(close) AS avg_close
FROM stock_prices
GROUP BY
  ticker,
  time_bucket('1 day', time);
```

## Conclusion

That's it for this chapter. We downloaded some stock price data from Yahoo Finance, and inserted it into our TimescaleDB database using Python's psycopg2 library.

Next time, we'll fire up a Python Flask web application, to serve as the base for our machine learning app. Then we'll begin integrating Dash for our stock price-forecasting, machine learning, single-page application. Exciting stuff!

Next: [Building a Python Flask App]({% post_url 2021-07-11-001-07-flask-app %})

{% include end_to_end_ml_table_of_contents.html %}
