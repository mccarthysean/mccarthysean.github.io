---
layout: post
title: Dash Callbacks Setup
slug: dash-callbacks-setup
chapter: 4
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.md %}


It's time to get into the callbacks, so we can make our second dropdown menu actually work. 

But first, let's add the second column to the layout, to pick a stock from the industry selected in the first dropdown menu.

```python

def get_top_stock_selection_row(industries, industry, stocks_options, stock): # NEW params added
    """Get the first row of the layout"""

    # The layout starts with a Bootstrap row, containing a Bootstrap column
    return dbc.Row(
        [
            # First column in row
            dbc.Col(
                [
                    html.H4("Pick an Industry", style={"margin-top": "1rem"}),
                    dcc.Dropdown(
                        options=industries,
                        value=industry,
                        id="industries_dropdown",
                    ),
                ],
                xs=12,
                sm=6,
                md=4,
            ),

            # Second column in row - NEW
            dbc.Col(
                [
                    html.H4("Pick a Stock", style={"margin-top": "1rem"}),
                    dcc.Dropdown(
                        options=stocks_options, 
                        value=stock,
                        id="tickers_dropdown"
                    ),
                ],
                xs=12,
                sm=6,
                md=4,
            ),
        ]
    )


def get_layout():
    """Function to get Dash's "HTML" layout"""

    industries, industry = get_stock_industries()
    stocks_options, stock = get_stock_tickers(industry) # NEW

    # A Bootstrap 4 container holds the rest of the layout
    return dbc.Container(
        [
            get_navbar(),
            get_top_stock_selection_row(
                industries,
                industry,
                stocks_options, # NEW
                stock # NEW
            ),
        ]
    )
```

Our second dropdown is much like our first, and requires a list of options, and a chosen stock, so let's add the `get_stock_tickers` function to our `utils.py`:

```python
# /app/dashapp/utils.py

def get_stock_tickers(industry):
    """Get a list of stocks based on the industry chosen"""

    sql = f"""
        --Get the labels and underlying values for the dropdown menu "children"
        SELECT 
            distinct 
            case when name is null then ticker else name end as label, 
            upper(ticker) as value
        FROM public.stock_tickers
        WHERE industry = '{industry}';
    """

    rows, _ = run_sql_query(sql)

    if len(rows) == 0:
        first_value = None
    else:
        first_value = rows[0]["value"]

    return rows, first_value

```

Uncomment the following import at the top:

```python
from app.dashapp.utils import (
    get_stock_industries,
    get_stock_tickers, # NEW
#     get_time_series_chart,
#     ml_features_map,
#     ml_models_map,
)
```

It's time for our first callback! Paste the `get_stocks_from_industries_dropdown` callback function inside the `register_callbacks` function. 

```python
def register_callbacks(dash_app):
    """Register the callback functions for the Dash app, within the Flask app"""

    @dash_app.callback(
        # The id="tickers_dropdown" gets modified with
        # new "options" based on the industry "Input"
        Output("tickers_dropdown", "options"), 
        [
            # The id="industries_dropdown" is the trigger for the callback
            Input("industries_dropdown", "value")
        ]
    )
    def get_stocks_from_industries_dropdown(industries_dropdown_value):
        """Get the stocks available, based on the industry chosen"""

        stocks_options, _ = get_stock_tickers(industries_dropdown_value)

        return stocks_options
```

All Dash callbacks have `Input()` objects that trigger them, and `Output()` objects as well, which are the HTML elements that the callbacks are modifying.

The first parameter in the `Input()` or `Output()` functions is always the `id=` of the element, from the `layout.py` file. The second parameter is always the **property** we're trying to modify. So we're using the "value" from the "industries_dropdown" dropdown as our input to the function, and we're modifying the "options" of the "tickers_dropdown" stocks dropdown menu.

Type `docker-compose up -d --build` in your terminal and try it out! We now have two functioning dropdowns:
1. Select the industry
2. Select the stock ticker, based on the industry chosen in the first dropdown

Now for the final column of the first row, where we allow the user to *input* her own stock ticker, and have it download from Yahoo Finance. Add the third column to the `get_top_stock_selection_row` function of the `layout.py` file.

```python
            dbc.Col(
                [
                    html.H4("Download Fresh Stock Data", style={"margin-top": "1rem"}),
                    dbc.InputGroup(
                        [
                            dbc.Input(id="add_stock_input", placeholder="ticker"),
                            dbc.InputGroupAddon(
                                dbc.Button("Download", id="add_stock_input_button"),
                                addon_type="append",
                            ),
                        ]
                    ),
                    dbc.Spinner(
                        html.P(
                            html.Span(
                                id="stock_uploaded_msg", className="align-middle"
                            ),
                            style={"line-height": "2"},
                        )
                    ),
                ],
                xs=12,
                sm=6,
                md=4,
            ),
```

This third column is kind of neat. Below the H4 heading, it's got a Dash Bootstrap Components (DBC) `InputGroup`, which contains a `dbc.Input` in which the user can type the ticker name, with a `dbc.InputGroupAddon` "Download" button "appended" on the right.

Below the input and button, there's an empty `html.P` "paragraph" element, into which we can dump a message about the success or failure of the download. Not the paragraph is also inside a cool Bootstrap `Spinner`, which spins while the stock price data are being downloaded! Baller.

Now, to add a slightly more complicated callback, which fires up when the user clicks the "Download" button:

```python

    @dash_app.callback(
        [
            Output("stock_uploaded_msg", "children"),
            Output("industries_dropdown", "options"),
            Output("industries_dropdown", "value"),
            Output("tickers_dropdown", "value"),
        ],
        [Input("add_stock_input_button", "n_clicks")],
        [State("add_stock_input", "value")],
    )
    def get_new_stock_information(add_stock_input_button_clicks, add_stock_input_value):
        """Add a stock's historical data to the database"""

        if add_stock_input_button_clicks is None or add_stock_input_value is None:
            # If this callback fires with no data, stop execution
            raise PreventUpdate

        # First get the location options (i.e. a list of dictionaries)
        ticker_upper = str(add_stock_input_value).upper()
        try:
            industry_chosen = download_prices(ticker_upper)
        except KeyError:
            current_app.logger.exception("Trouble finding stock information...")
            msg = f"{ticker_upper} didn't work! Please try a different stock... :("
            return msg, dash.no_update, dash.no_update, dash.no_update

        msg = f"{ticker_upper} downloaded!"
        industries, _ = get_stock_industries()

        return msg, industries, industry_chosen, ticker_upper
```

This callback has four `Output`s, one `Input` trigger, and one `State` variable, which doesn't trigger the callback, but whose value is available to the function. Makes sense right? The "Download" button is the input trigger, and the text value of the input box is the ticker we want to download, but only after the user has clicked the "Download" button.

In the end, the callback returns:
1. A message for the user, about the stock prices download success
2. A new list of industries, including the newest stock ticker's industry
3. The chosen industry, from among the new industry options
4. The chosen ticker for the stocks dropdown

Note that both the `Input` trigger, and the `State` variable are parameters for the callback function. 

We start out with some typical error-checking. If either of the inputs is `None`, stop Dash from updating with `raise PreventUpdate`.

Notice another cool Dash feature, to return only part of the data, if there's an error:
```python
        try:
            industry_chosen = download_prices(ticker_upper)
        except KeyError:
            current_app.logger.exception("Trouble finding stock information...")
            msg = f"{ticker_upper} didn't work! Please try a different stock... :("
            return msg, dash.no_update, dash.no_update, dash.no_update # NEAT STUFF
```

Let's add the `download_prices` function to the `utils.py` file in the `dashapp` folder. The `download_prices` function depends on a few other functions for uploading and inserting tickers, so we'll add those at the same time. You've seen these functions before, in Part 1, Chapter 4 "Add Data to Python".

```python
def insert_tickers(ticker, name=None, industry=None):
    """Insert the tickers into the "stock_tickers" table,
    and update them if they already exist"""

    sql = f"""
        insert into public.stock_tickers (ticker, name, industry)
        values ('{ticker}', '{name}', '{industry}')
        on conflict (ticker)
        do update
            set name = '{name}', industry = '{industry}'
    """

    conn = get_conn()
    with conn.cursor() as cursor:
        cursor.execute(sql)
        conn.commit()


def upload_to_aws_efficiently(df, ticker, table_name="public.stock_prices"):
    """
    Upload the stock price data to AWS as quickly and efficiently as possible
    by truncating (i.e. removing) the existing data and copying all-new data
    """

    conn = get_conn()
    with conn.cursor() as cursor:
        # Remove the existing data for that ticker
        cursor.execute(f"delete from {table_name} where ticker = '{ticker}'")
        conn.commit()

        # Now insert the brand-new data
        # Initialize a string buffer
        sio = StringIO()
        # Write the Pandas DataFrame as a CSV file to the buffer
        sio.write(df.to_csv(index=None, header=None))
        # Be sure to reset the position to the start of the stream
        sio.seek(0)
        cursor.copy_from(
            file=sio, table=table_name, sep=",", null="", size=8192, columns=df.columns
        )
        conn.commit()

    current_app.logger.info("DataFrame uploaded to TimescaleDB")


def download_prices(ticker, name=None, industry=None, period="10y", interval="1d"):
    """Download stock prices to a Pandas DataFrame, insert """

    stock = yf.Ticker(ticker)
    info = stock.info

    name = info.get("shortName", None)
    industry = info.get("sector", None)
    if industry is None:
        industry = info.get("category", None)

    # Update the tickers in the "stock_tickers" table
    insert_tickers(ticker, name=name, industry=industry)

    df = yf.download(tickers=ticker, period=period, interval=interval, progress=False)

    df = df.reset_index()  # remove the index
    df["ticker"] = ticker  # add a column for the ticker

    # Rename columns to match our database table
    df = df.rename(
        columns={
            "Date": "time",
            "Datetime": "time",
            "Open": "open",
            "High": "high",
            "Low": "low",
            "Close": "close",
            "Adj Close": "close_adj",
            "Volume": "volume",
        }
    )

    upload_to_aws_efficiently(df, ticker=ticker, table_name="public.stock_prices")

    return industry
```

Wow, we've accomplished a lot. We've added a row to our layout with two dropdowns, an input field, and a download button. Then we added two callback functions, which quickly escalated in terms of complexity and features. 

In the next chapter, we'll build a beautiful Plotly/Dash chart for the historical stock price data we just downloaded. Interactive data visualization, coming up!
