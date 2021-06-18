---
layout: post
title: 'Deploy a Machine Learning, Stock Price Forecasting Web App with TimescaleDB, Python Dash/Flask, Docker Swarm, and Traefik on AWS - Part 1'
tags: [TimescaleDB, PGAdmin, Docker, Python]
featured_image_thumbnail:
featured_image: assets/images/posts/2020/gilly-wcWN29NufMQ-unsplash.jpg
featured: false
hidden: false
---

In this in-depth course, I'm going to show you how to deploy a machine learning model on the web using a very unique and data scientist-friendly tech stack. 

We'll start out by setting up a [TimescaleDB](https://www.timescale.com/) specialized time series database in a [Docker](https://www.docker.com/) container, managed with [PGAdmin](https://www.pgadmin.org/) (the official admin web app for [PostgreSQL](https://www.postgresql.org/) databases). Then we'll use [Python](https://www.python.org/) to populate that database with historical stock price data. 

Next we'll setup a reactive single-page web application entirely in Python, featuring interactive time series charts from [Dash/Plotly](https://dash.plotly.com/), on a [Flask](https://flask.palletsprojects.com/en/1.1.x/) website. Flask is a very flexible web framework for Python, and Dash is popular for data science web apps, especially since it requires no JavaScript at all, and yet it uses [React](https://reactjs.org/) JavaScript behind-the-scenes. So it's an ideal stack for quickly deploying data science applications. I'll show you how to properly integrate Dash into Flask, so you can have the best of both web frameworks.

Then comes some fun data science, where we'll be predicting stock prices using machine learning. 

Finally, we'll deploy our web application to [AWS](https://aws.amazon.com/) on an EC2 server using [Docker Swarm](https://docs.docker.com/engine/swarm/) and [Traefik](https://traefik.io/) for a web server. 

All the code for this tutorial can be found [here](https://github.com/mccarthysean/Machine-Learning-Deployment-Stock-Price-Forecasting) at GitHub. 

# Part 1 - Docker, TimescaleDB, PGAdmin, and Python

First, let's create a [Docker network](https://docs.docker.com/network/) so our forthcoming containers can talk to each other:
```bash
docker network create --attachable --driver bridge timescale_network
```

Next, let's start a local TimescaleDB database using [Docker-Compose](https://docs.docker.com/compose/). This will quickly start a local PostgreSQL database with the TimescaleDB extension automatically configured. Create the following `docker-compose.timescale.yml` file:
```yaml
# docker-compose.timescale.yml

version: '3.7'
services:
  timescale:
    image: timescale/timescaledb:1.7.4-pg12
    volumes: 
      - type: volume
        # source: timescale-db # the volume name
        source: timescale_volume
        # target: the location in the container where the data are stored
        target: /var/lib/postgresql/data 
        read_only: false
      # Custom postgresql.conf file will be mounted (see command: as well)
      - type: bind
        source: ./postgresql_custom.conf
        target: /postgresql_custom.conf
        read_only: false
    env_file: .env
    environment: 
      POSTGRES_HOST: timescale
    command: ["-c", "config_file=/postgresql_custom.conf"]
    ports: 
      - 0.0.0.0:5432:5432
    networks:
      timescale_network:
    deploy:
      restart_policy:
        condition: on-failure

# Creates a named volume to persist our database data
volumes:
  timescale_volume:

# Joins our external network
networks:
  timescale_network:
    external: true
```

Note a few things about the above Docker-Compose file:

1. It uses the `timescale_network` we created in the previous step. 
2. It uses a volume to persist the database's data, even if the Docker container is removed or replaced. This is very common for 'Dockerized' databases. 
3. It uses port 5432 (this will be important when we try to access the database in the future). 
4. It uses a custom configuration file, and a `.env` file to store secret database connection information, like your database password. Let's create those two files next.

Here's the custom configuration file, in case you want/need to change any of these settings in the future. The file is too long to put in a code block in this article, so just click <a href="/assets/files/posts/2020/postgresql_custom.conf">this link</a>, then copy and paste the text into a file called `postgresql_custom.conf` and put it in the root of your project folder.

Next, here's a template for our secret `.env` file, which you can leave in the root of your project folder, alongside the Docker-Compose and database configuration files:
```bash
# .env

# For the Postgres/TimescaleDB database. 
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_HOST=timescale
POSTGRES_PORT=5432
POSTGRES_DB=postgres
PGDATA=/var/lib/postgresql/data
```

Now that we've added the custom configuration and .env files, you can start the TimescaleDB database with the following command. The `-d` starts the container in the background (`--detached`).
```bash
docker-compose -f docker-compose.timescale.yml up -d
```

Check your running containers with `docker container ls` or the old-school `docker ps`. If the container is restarting, check the logs with `docker logs <container id>` and ensure you've setup the .env file, the config file, and the Docker network it depends on.

Finally, let's create a friendly PGAdmin environment for administering our database and running SQL. Create a file called `docker-compose.pgadmin.yml` and add the following:
```yaml
# docker-compose.pgadmin.yml

version: '3.7'
services:
  pgadmin:
    # Name of the container this service creates. Otherwise it's prefixed with the git repo name
    image: "dpage/pgadmin4:latest"
    restart: unless-stopped
    env_file: .env
    environment: 
      PGADMIN_LISTEN_PORT: 9000
    ports: 
      - 0.0.0.0:9000:9000
    volumes: 
      # So the database server settings get saved and stored even if the container is replaced or deleted
      - pgadmin:/var/lib/pgadmin
    networks:
      timescale_network:

volumes:
  pgadmin:

networks:
  timescale_network:
    external: true
```

Add the following lines to your `.env` file for PGAdmin. You'll need this login information when you try to access PGAdmin in the web browser. 
```bash
# .env

# For the PGAdmin web app
PGADMIN_DEFAULT_EMAIL=your@email.com
PGADMIN_DEFAULT_PASSWORD=password
```

Start the PGAdmin (PostgreSQL Admin) web application with the following Docker command:
```bash
docker-compose -f docker-compose.pgadmin.yml up -d
```

Run `docker container ls` again to check if the PGAdmin container is running. Note we specified a port of 9000, so you can now access PGAdmin at [http://localhost:9000](http://localhost:9000) or [http://127.0.0.1:9000](http://127.0.0.1:9000). Login with the username and password you setup in your `.env` file. 

Now that you've logged into PGAdmin, right-click on "Servers" and "Create/Server...". Name it "TimescaleDB Local" in the "General" tab, and type the following into the "Connection" tab:
* **Host**: timescale (this is the Docker "Service" hostname defined in the first docker-compose.yml file for the TimescaleDB database container)
* **Port**: 5432
* **Maintenance database**: postgres
* **Username**: postgres
* **Password**: password

Click "Save" and you should be connected. Now you can double-click on "TimescaleDB Local" and you can access your database tables at "/Databases/postgres/Schemas/public/Tables". Pretty cool, huh? Under the "Tools" menu, click on "Query Tool" and you're ready to start writing SQL. 

You're now the proud commander of a TimescaleDB database, which is identical to a [PostgreSQL](https://www.postgresql.org/) database ("The world's most advanced open source database", if you believe their marketing), except that it now has special abilities for dealing with high-frequency time series data. 

Time series data is a bit different from regular relational data for describing users and things. Time series data can arrive any second, or even multiple times per second, depending on what you're storing, so the database needs to be able to handle lots of insertions. Some examples are financial data, such as stock market trading prices like we'll be using, or internet of things (IoT) data, usually for monitoring environmental metrics like temperature, pressure, humidity, or anything else you can think of. Usually when you query time series data, you're interested in the most recent data, and you're usually filtering on the timestamp column, so that definitely needs to be indexed. TimescaleDB specializes in this sort of thing. 

Let's create a special TimescaleDB "Hypertable" and insert some data to play with. Here's the official TimescaleDB [documentation](https://docs.timescale.com/latest/using-timescaledb/hypertables). 

In PGAdmin, if you're not already there, under the "Tools" menu, click on "Query Tool" and type the following SQL to create two database tables in the default "public" schema:
```sql
CREATE TABLE stock_tickers (
  ticker TEXT PRIMARY KEY,
  name TEXT,
  industry TEXT
);

CREATE TABLE stock_prices (
  time TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  ticker TEXT,
  open NUMERIC,
  high NUMERIC,
  low NUMERIC,
  close NUMERIC,
  close_adj NUMERIC,
  volume NUMERIC,
  FOREIGN KEY (ticker) REFERENCES stock_tickers (ticker)
);
```

Now for the special part that you can't do in a regular PostgreSQL database. We're going to transform the `stock_prices` table into a "Hypertable". Behind the scenes, TimescaleDB is going to partition the data on the time dimension, making it easier to filter, index, and drop old time series data. 

If you've come to this course to take advantage of TimescaleDB's unique features, the following is where the magic happens.

Run the following query in PGAdmin to create the hypertable, automatically partitioned on the "time" dimension:
```sql
SELECT create_hypertable('stock_prices', 'time');
```

Now that our specialized time series table has been created, let's create a special index on the stock ticker, since we're very likely to filter on both ticker and time. 
```sql
create index on stock_prices (ticker, time desc);
```

Let's now add a few different stocks to the "stock_tickers" table, along with their industries:
```sql
INSERT INTO stock_tickers (ticker, name, industry) VALUES
  ('MSFT','Microsoft Corporation','Technology'),
  ('TSLA','Tesla Inc','Auto Manufacturers'),
  ('CVX', 'Chevron Corp','Energy'),
  ('XOM', 'Exxon Mobil Corporation','Energy');
```

## Add data with Python

Let's switch from TimescaleDB to Python for a few minutes to download some historical stock price data. 

Before we can get started with Python, we always have to create a dedicated Python3 virtual environment. Let's just use `python3 -m venv venv` to create a virtual environment called "venv" in our root project folder. 

These days I prefer using [Poetry](https://python-poetry.org/) to [Pip](https://pypi.org/project/pip/), but Poetry is not the focus of this article. 

Activate the virtual environment with `source venv/bin/activate` on Linux/Mac, or `venv\Scripts\activate.bat` on Windows. Once you've activated the virtual environment, install a bunch of libraries we'll be using in this course with `pip install python-dotenv psycopg2-binary yfinance pandas scikit-learn flask dash dash-bootstrap-components`.

As an aside, I actually run Windows 10 Pro, as many data scientists do, especially those who come from the business world. So I use VS Code as my IDE, and I code inside a Linux Docker container in VS Code. Check out the documentation for that [here](https://code.visualstudio.com/docs/remote/containers), but once again, that's not the focus of this course.

Now that we've got our Python virtual environment set up, we can download some historical stock price data from [Yahoo Finance](https://finance.yahoo.com/)using the excellent [yfinance](https://pypi.org/project/yfinance/) library, and then insert it into TimescaleDB using the [psycopg2](https://pypi.org/project/psycopg2/) library. `yfinance` uses [Pandas](https://pandas.pydata.org/) DataFrames, so we'll use that as well.

Have a quick scan of the code, and I'll explain more below.

```python
# get_stock_prices.py

import os
from io import StringIO

import pandas as pd
import psycopg2
import yfinance as yf


def download_prices(ticker, period='2y', interval='60m', progress=False):
    """Download stock prices to a Pandas DataFrame"""
    
    df = yf.download(
        tickers=ticker,
        period=period,
        interval=interval, 
        progress=progress
    )
    
    df = df.reset_index() # remove the index
    df['ticker'] = ticker # add a column for the ticker
    
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


def upload_to_aws_efficiently(df, table_name="public.stock_prices"):
    """
    Upload the stock price data to AWS as quickly and efficiently as possible
    by truncating (i.e. removing) the existing data and copying all-new data
    """
    
    with psycopg2.connect(
        host=os.getenv('POSTGRES_HOST'),
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
    upload_to_aws_efficiently(df_all)

    print("All done!")

```

As you can see from the code above, first we download the prices for each ticker, into Pandas DataFrames. Then we concatenate those four DataFrames into one, and finally upload all the data to TimescaleDB. Note that the upload function first removes/truncates all existing data, and then inserts the brand-new data.

Head back to PGAdmin and run a quick `SELECT` query to look at the data you just inserted:

Run a simple select query to see some of our newly-inserted historical stock price data. Notice we downloaded hourly prices.
```sql
SELECT * 
FROM stock_prices
WHERE time > (now() - interval '14 days')
ORDER BY time, ticker;
```

Here's another example of selecting the aggregated data (i.e. a daily average, instead of seeing every hourly data point):
```sql
SELECT 
  ticker,
  time_bucket('1 day', time) AS period, 
  AVG(high) AS high, 
  AVG(low) AS low,
  AVG(close) AS close, 
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
  AVG(close) AS avg_close, 
  last(close, time) AS last_close --the latest value
FROM stock_prices 
GROUP BY period;
```

And of course, you'll often want to join the time series data with the *metadata* (i.e. data about data). In other words, let's get the name and industry for each stock ticker:
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

TimescaleDB has another very useful feature called "continuous aggregates" for continually and efficiently updating aggregated views of our time series data. If you often want to report/chart aggregated data, the following view-creation code is for you:
```sql
CREATE VIEW stock_prices_1_day_view
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

That's it for part 1 of this course. [Part 2]({% post_url 2020-11-08-timescale-dash-flask-part-2 %}) will focus on integrating the Python web frameworks Dash and Flask. Part 3 will focus on creating reactive, interactive time series charts in Dash for your single-page application (SPA). Part 4 is on machine learning, and Part 5 is on deployment to AWS EC2 with Docker Swarm and Traefik.

Stay healthy,<br>
Sean
