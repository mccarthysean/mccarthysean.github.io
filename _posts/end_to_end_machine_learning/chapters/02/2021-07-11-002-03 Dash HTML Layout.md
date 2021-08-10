---
layout: post
title: Dash HTML Layout
# slug: dash-html-layout
chapter: 3
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


Now that we've created a Dash app and integrated it with Flask, let's work on the `layout.py` file, which for now will just contain a Bootstrap navigation bar inside a Bootstrap container:

```python
# /app/dashapp/layout.py

import datetime
import os

import dash_bootstrap_components as dbc
import dash_core_components as dcc
import dash_html_components as html
from flask import url_for

# We'll uncomment these and work on them in a future chapter!
# from app.dashapp.utils import (
#     get_stock_industries,
#     get_stock_tickers,
#     get_time_series_chart,
#     ml_features_map,
#     ml_models_map,
# )


def get_navbar():
    """Get a Bootstrap 4 navigation bar for our single-page application's HTML layout"""

    return dbc.NavbarSimple(
        children=[
            dbc.NavItem(dbc.NavLink("Blog", href="https://mccarthysean.dev")),
            dbc.NavItem(dbc.NavLink("IJACK", href="https://myijack.com")),
            dbc.DropdownMenu(
                children=[
                    dbc.DropdownMenuItem("References", header=True),
                    dbc.DropdownMenuItem("Dash", href="https://dash.plotly.com/"),
                    dbc.DropdownMenuItem(
                        "Dash Bootstrap Components",
                        href="https://dash-bootstrap-components.opensource.faculty.ai/",
                    ),
                    dbc.DropdownMenuItem("Testdriven", href="https://testdriven.io/"),
                ],
                nav=True,
                in_navbar=True,
                label="Links",
            ),
            dbc.NavItem(
                dbc.Button(
                    "Logout",
                    href="/logout/",
                    external_link=True,
                    color="primary",
                    className="ml-2",
                )
            ),
        ],
        brand="Home",
        brand_href="/",
        color="dark",
        dark=True,
    )


def get_layout():
    """Function to get Dash's "HTML" layout"""

    # A Bootstrap 4 container holds the rest of the layout
    return dbc.Container(
        [
            # Just the navigation bar at the top for now... More to come!
            get_navbar(),
        ], 
    )
```

If you recall, the `get_layout()` function is called from our `dash_setup.py` module, like this:

```python
    ...

    with app.app_context():

        # Assign the get_layout function without calling it yet
        dashapp.layout = get_layout
```

I won't explain the `get_navbar()` function because I think it's self-explanatory. When you see it in the browser, you'll understand everything. But [here's](https://dash-bootstrap-components.opensource.faculty.ai/docs/components/navbar/) the documentation if you're curious.

For the rest of Part 2, we'll bounce back and forth between the `layout.py` file, and the `callbacks.py` file. We'll add a piece to the layout, and then write a callback to interact with it. Rinse and repeat. 

That said, let's get started on our `callbacks.py` file beside the `layout.py` file. For now, we'll just import our packages and frame up the `register_callbacks` function:

```python
# /app/dashapp/callbacks.py

import json
import os
import time
from io import StringIO

import dash
import dash_bootstrap_components as dbc
import dash_core_components as dcc
import dash_html_components as html
import numpy as np
import pandas as pd
import plotly.graph_objs as go
import psycopg2
import yfinance as yf
from dash.dependencies import Input, Output, State
from dash.exceptions import PreventUpdate
from flask import current_app
from psycopg2.extras import RealDictCursor

# We'll uncomment these later!
# from app.dashapp.ml import feature_engineering, grid_search_cross_validate, train_models
# from app.dashapp.utils import (
#     download_prices,
#     get_chart,
#     get_stock_industries,
#     get_stock_price_data_from_db,
#     get_stock_tickers,
#     get_time_series_chart,
#     insert_tickers,
#     make_annotations,
#     ml_models_map,
#     upload_to_aws_efficiently,
# )
# from app.database import get_conn, run_sql_query


def register_callbacks(dash_app):
    """Register the callback functions for the Dash app, within the Flask app"""

    pass
```

Let's add a few more HTML components to the "body" of the `layout.py` file. Currently it's just a navigation bar at the top, so let's work our way down by adding a `get_top_stock_selection_row` function.

```python
# /app/dashapp/layout.py

def get_top_stock_selection_row(industries, industry): # NEW
    """Get the first row of the layout"""

    # The layout starts with a Bootstrap row, containing a Bootstrap column
    return dbc.Row(
        [
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
        ],
        style={"margin-top": "1em"},
    )


def get_layout():
    """Function to get Dash's "HTML" layout"""

    # A Bootstrap 4 container holds the rest of the layout
    return dbc.Container(
        [
            get_navbar(),
            get_top_stock_selection_row(industries, industry), # NEW
        ], 
    )
```

Notice in the `get_layout()` function, we've added `get_top_stock_selection_row(industries, industry)` below the navbar function. We'll deal with the `industries` and `industry` arguments pretty soon, but for now let's check out the actual `get_top_stock_selection_row` function so we know why we need them.

The function starts by returning a Dash Bootstrap Components (DBC) `Row`, inside of which is a `Column`. This is standard Bootstrap grid stuff. 

```python
    # The layout starts with a Bootstrap row, containing a Bootstrap column
    return dbc.Row(
        [
            dbc.Col(
                [
```

Notice also that the `get_layout` function first returns a `dbc.Container`. At its most basic, for example, a DBC Bootstrap grid would look like the following:

```python
dbc.Container(
    dbc.Row(
        dbc.Col(
            "Some random text"
        )
    )
)
```

But since we're going to be adding more than one row to the container, and more than one column to each row, the first argument is usually a list, more like the following:

```python
dbc.Container(
    [
        dbc.Row(
            [
                dbc.Col(
                    [
                        "Some random text",
                        "More random text",
                    ]
                ),
            ]
        ),
    ]
)
```

Now, let's look at what's inside that first column. 

First, there's a "Heading 4" (heading of size 4 in HTML), created with [Dash HTML Components](https://dash.plotly.com/dash-html-components) as `html.H4`.

After the heading, we've got a [Dash Core Components](https://dash.plotly.com/dash-core-components) (DCC) dropdown menu, whose HTML "ID" is `industries_dropdown`. That's how the callback will refer to it--by its ID.

You're creating Bootstrap HTML/CSS/JS with nothing but Python! That's the beauty of Dash. 

Finally, note the `xs`, `sm`, and `md` options. On an extra small phone, the column will take up all 12 of the Bootstrap grid columns. On a "small" (`sm`) device like an iPad, the column will take up only the first 6 columns, leaving room for another column to take up the other six column spaces. And on a "medium" (`md`) sized screen, there's room for three columns, each taking up 4 columns of space.

```python

def get_top_stock_selection_row(industries, industry): # NEW
    """Get the first row of the layout"""

    # The layout starts with a Bootstrap row, containing a Bootstrap column
    return dbc.Row(
        [
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
        ],
        style={"margin-top": "1em"},
    )
```

Next, we need to add the `industries` and `industry` arguments for the dropdown menu. Create a `utils.py` file in the `dashapp` folder, and add the following code so we can query our TimescaleDB database for the industries available.

```python
# /app/dashapp/utils.py

import datetime
import os
from io import StringIO

import dash
import dash_bootstrap_components as dbc
import dash_core_components as dcc
import dash_html_components as html
import pandas as pd
import plotly.graph_objs as go
import psycopg2
import yfinance as yf
from dash.dependencies import Input, Output, State
from dash.exceptions import PreventUpdate
from flask import current_app
from psycopg2.extras import RealDictCursor

from app.database import get_conn, run_sql_query


def get_stock_industries():
    """Get a list of different industries for which we have stock prices"""

    sql = """
        --Get the labels and underlying values for the dropdown menu "children"
        SELECT 
            distinct 
            industry as label,
            industry as value
        FROM public.stock_tickers;
    """

    rows, _ = run_sql_query(sql)

    if len(rows) == 0:
        first_value = None
    else:
        first_value = rows[0]["value"]

    return rows, first_value
```

The `get_stock_industries` function does just what you'd expect, querying our TimescaleDB database with regular SQL, and returning the distinct/unique industries in a list of dictionaries, where each row is a dictionary.

Now we need to add the helpful `run_sql_query` function to our `database.py` module, as follows:

```python
# database.py

def run_sql_query(sql, conn=None):
    """Run a generic query and return the rows and columns"""

    if conn is None:
        conn = get_conn()

    # Use the RealDictCursor cursor factory, so each row returned is a dictionary
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(sql)
        columns = [str.lower(x[0]) for x in cursor.description]
        rows = cursor.fetchall()

    return rows, columns
```

Now we can add the `get_stock_industries` function to the `get_layout` function, and pass its return values to the `get_top_stock_selection_row` function, as follows:

```python

def get_layout():
    """Function to get Dash's "HTML" layout"""

    industries, industry = get_stock_industries() # NEW

    # A Bootstrap 4 container holds the rest of the layout
    return dbc.Container(
        [
            get_navbar(),
            get_top_stock_selection_row(industries, industry),
        ]
    )
```

Uncomment the following import at the top:

```python
from app.dashapp.utils import (
    get_stock_industries,
#     get_stock_tickers,
#     get_time_series_chart,
#     ml_features_map,
#     ml_models_map,
)
```

Many Pythonistas enjoy querying their databases with [SQLAlchemy](https://www.sqlalchemy.org/), and I use it too, but sometimes I just wanna get dirty and write some SQL like the olden-days. The [psycopg2](https://www.psycopg.org/) library lets me do that very nicely. Both are great libraries--well-maintained and battle-tested. 

Take this opportunity to check out your new Dash site in your browser. Type `docker-compose up -d --build` in your console.

In the next chapter, we'll add second and third columns to the first row, and use Dash callbacks to populate them, based on the industry chosen in the first dropdown.

Next: <a href="002-04-Dash-Callbacks-Setup">Dash Callbacks Setup</a>

{% include end_to_end_ml_table_of_contents.html %}
