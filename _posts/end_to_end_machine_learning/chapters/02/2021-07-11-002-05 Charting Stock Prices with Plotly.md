---
layout: post
title: Charting Stock Prices with Plotly
# slug: charting-stock-prices-with-plotly
chapter: 5
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


In the previous chapter, we finished the first row of the layout, including:
1. An industries dropdown
2. A stock dropdown
3. A stock ticker download input and button

In this chapter, we'll add a Plotly chart of the newly-downloaded stock price data.

Add the following `get_regular_chart_row()` function to your `layout.py` file, near the bottom. This will give us a Bootstrap row/column in which to place a Dash chart via a callback:

```python
def get_regular_chart_row(stock_ticker):
    """Create a row and column for our Plotly/Dash time series chart"""

    return dbc.Row(
        dbc.Col(
            dbc.Spinner(
                [
                    html.Div(
                        get_time_series_chart(stock_ticker), 
                        id="time_series_chart_div"
                    )
                ]
            )
        )
    )
```

Notice the `get_time_series_chart` function. Un-comment that from the imports at the top:

```python
from app.dashapp.utils import (
    get_stock_industries,
    get_stock_tickers,
    get_time_series_chart, # NEW
    # ml_features_map,
    # ml_models_map,
)
```

Add the `get_regular_chart_row` function you just created to the `get_layout()` function at the bottom of the `layout.py` file:

```python
def get_layout():
    """Function to get Dash's "HTML" layout"""

    industries, industry = get_stock_industries()
    stocks_options, stock = get_stock_tickers(industry)

    # A Bootstrap 4 container holds the rest of the layout
    return dbc.Container(
        [
            get_navbar(),
            get_top_stock_selection_row(industries, industry, stocks_options, stock),
            get_regular_chart_row(stock), # NEW
            # get_ml_inputs_row(),
            # get_train_model_button_row(stock),
            # get_ml_chart_row(),
            # get_profits_chart_row(),
        ]
    )
```

Now let's add the `get_time_series_chart` function to the `utils.py` file, along with the `get_stock_price_data_from_db` function it needs:

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
            round(close_adj::numeric, 2) as price,
            round(high::numeric, 2) as high,
            round(low::numeric, 2) as low,
            volume
        from public.stock_prices
        where ticker = '{ticker}'
        order by
            ticker,
            time;
    """

    rows, columns = run_sql_query(sql)

    # Return a DataFrame with the results
    return pd.DataFrame(rows, columns=columns)


def get_time_series_chart(ticker):
    """Get the normal time series chart of the stock price history"""

    df = get_stock_price_data_from_db(ticker)
    x = df["time"]
    y = df["price"]
    title = f"Historical Prices for {ticker}"

    traces = [go.Scatter(x=x, y=y, name="Price")]

    return get_chart(traces, title)
```

Notice the `get_stock_price_data_from_db` function is returning a [Pandas](https://pandas.pydata.org/) DataFrame out of the data. Pandas is an essential library for data scientists working in Python. If you want to be good at data science in Python, you absolutely *must* become proficient at Pandas.

In a nutshell, and Pandas DataFrame is a table full of [NumPy](https://numpy.org/) arrays for columns, but we won't get into any of that right now. Just know Pandas and Numpy are extremely optimized for data science work, and Pandas is a really nice and efficient way of working with tabular data, such as we have in our database.

There's one other required function as well: the `get_chart` function, so let's add that as well. It seems like a lot at first, but Plotly's charts are very logical, and follow this basic pattern. The outer layer is a Dash `Graph` class, and inside is Plotly `graph_obj` (`go`) stuff, like the outer `Figure` class, comprised of data and a chart `Layout` class. You'll quickly get the hang of it.

Here's the full Plotly [API reference](https://plotly.com/python-api-reference/plotly.graph_objects.html), which is an essential resource if you're working with Plotly charts. 

```python
# Dash Core Components Graph
dcc.Graph(
    # Plotly "graph_obj" figure
    figure=go.Figure(
        data=traces, # the data
        layout=go.Layout() # the layout
    )
)
```

Without further ado, here's the `get_chart` function you'll need. 

In the `layout`, I add quite a few options for the `xaxis` since it's a time series chart, and you'll probably want some quick time filters. Usually I'd choose either the `rangeselector` buttons above the chart, or the `rangeslider` below the chart, but I'm adding both to show you what's available. I prefer the `rangeselector` buttons above the chart. If you're into stock trading, you'll know these time filters are quite common and intuitive.

```python
def get_chart(traces, title, annotations=None, date_test=None, rangeslider=True):
    """Get a Dash "Graph" object"""

    if annotations is None:
        annotations = []

    shapes = None
    if date_test is not None:
        shapes, more_annotations = get_train_test_chart_annotations(date_test)
        annotations += more_annotations

    figure = go.Figure(
        data=traces,
        layout=go.Layout(
            title=title,
            plot_bgcolor="white",
            annotations=annotations,
            shapes=shapes,
            legend=dict(
                # Looks much better horizontal than vertical
                orientation="h",
            ),
            xaxis=dict(
                autorange=True,
                # Time-filtering buttons above chart
                rangeselector=dict(
                    buttons=list(
                        [
                            dict(count=7, label="7d", step="day", stepmode="backward"),
                            dict(
                                count=14,
                                label="14d",
                                step="day",
                                stepmode="backward",
                            ),
                            dict(
                                count=1,
                                label="1m",
                                step="month",
                                stepmode="backward",
                            ),
                            dict(
                                count=3,
                                label="3m",
                                step="month",
                                stepmode="backward",
                            ),
                            dict(
                                count=1,
                                label="1y",
                                step="year",
                                stepmode="backward",
                            ),
                            dict(step="all"),
                        ]
                    )
                ),
                type="date",
                # Alternative time filter slider
                rangeslider=dict(visible=rangeslider),
            ),
        ),
    )

    return dcc.Graph(
        # Disable the ModeBar with the Plotly logo and other buttons
        config=dict(displayModeBar=False),
        figure=figure,
    )

```

Notice the following in the `dcc.Graph` instantiation: The `config` parameter is a dictionary, and in it we disable the Plotly logo from showing up in the chart, in the top-right corner. This also disables some optional chart zooming options. Try it with and without, but personally I leave it out because I don't want the Plotly logo on my charts.

```python
    return dcc.Graph(
        # Disable the ModeBar with the Plotly logo and other buttons
        config=dict(displayModeBar=False),
        figure=figure,
    )
```

The `get_chart` function, in turn, requires the `get_train_test_chart_annotations` function, so here it is. This is for adding text annotations to the chart, in addition to the lines and the legend. 

More on this in the next part on machine learning. For now, just copy and paste it.

```python
def get_train_test_chart_annotations(date_test):
    """
    Draw a vertical line to visually separate the
    training period data from the testing period data.

    Also add some text annotations
    """

    # Convert date string to datetime object
    date_time = datetime.datetime.strptime(date_test, "%Y-%m-%d")

    # Add a vertical line to visually separate the
    # training period data from the testing period data
    shapes = [
        dict(
            type="line",
            xref="x",  # relative to x-axis values
            x0=date_time,
            x1=date_time,
            yref="paper",  # relative to pixels on chart
            y0=0,
            y1=1,
        )
    ]

    # Add two text annotations
    annotations = []
    # "Train" annotation
    annotations.append(
        dict(
            xref="x",  # relative to x-axis values
            x=date_time,
            yref="paper",  # relative to pixels on chart
            y=0.95,
            text="Train  ",
            showarrow=False,
            # xshift=-20,
            xanchor="right",
        )
    )
    # "Test" annotation
    annotations.append(
        dict(
            xref="x",  # relative to x-axis values
            x=date_time,
            yref="paper",  # relative to pixels on chart
            y=0.95,
            text="  Test",
            showarrow=False,
            # xshift=20,
            xanchor="left",
        )
    )

    return shapes, annotations
```

Now that we've added the time series chart of historical stock prices to the layout, and pasted in all of the requisite utility functions, we can add a callback for actually populating the chart with data, once the user selects a stock from the stocks dropdown.

Add the following callback to the `callbacks.py` file:

```python
    @dash_app.callback(
        Output("time_series_chart_div", "children"),
        [Input("tickers_dropdown", "value")],
    )
    def get_normal_time_series_chart(tickers_dropdown_value):
        """Get the normal time series chart of the stock price history"""

        return get_time_series_chart(tickers_dropdown_value)
```

This rather basic callback responds to a change in the `tickers_dropdown`'s `value` property (i.e. when the stock ticker in that dropdown changes). 

Then it calls the `get_time_series_chart` function with the new stock ticker, and the resulting chart is "output" to the HTML div element whose ID is `time_series_chart_div`. The property of the "div" whose value we're modifying is its "children". In other words, the div's children are a Dash chart. When the stock ticker changes in the dropdown, we create a Dash chart in the div. 

That's it for Chapter 6 on Plotly charting, and that's it for Part 2 as well, which focused on creating a Dash single-page-application (SPA), including a Dash HTML layout, Dash callbacks for interactivity, and beautiful Dash/Plotly interactive data science charts.

In Part 3, we're going to switch gears again and dive into the data science world of exploratory data analysis (EDA), feature engineering and selection, machine learning model fitting and selection, model hyper-parameter tuning, and cross-validation testing. Get ready to build an awesome machine learning pipeline you can take with you to other machine learning projects. 


{% include end_to_end_ml_table_of_contents.html %}
