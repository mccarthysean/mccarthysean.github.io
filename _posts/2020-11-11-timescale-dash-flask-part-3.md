---
layout: post
title: 'Time Series Charts with Dash, Flask, TimescaleDB, and Docker - Part 3'
tags: [Python, TimescaleDB, Dash, Flask]
featured_image_thumbnail:
featured_image: assets/images/posts/2020/python-code-hitesh-choudhary-D9Zow2REm8U-unsplash.jpg
featured: true
hidden: true
---

This is the third of three articles on TimescaleDB, Flask, and Dash. 

The [first article]({% post_url 2020-11-07-timescale-dash-flask-part-1 %}) focused on getting the [TimescaleDB](https://www.timescale.com/) database running with [Docker](https://www.docker.com/), along with [PGAdmin](https://www.pgadmin.org/) for administering it. 

The [second part]({% post_url 2020-11-08-timescale-dash-flask-part-2 %}) focused on the Python language, creating a [Flask](https://flask.palletsprojects.com/) website and then integrating the [Dash](https://plotly.com/dash/) web framework into Flask. 

This third part focuses on using Dash to create a reactive single-page web application for viewing your TimescaleDB database data in beautiful, interactive [Plotly](https://plotly.com/python/) charts.

All the code for this tutorial can be found [here](https://github.com/mccarthysean/TimescaleDB-Dash-Flask) at GitHub. 

# Part 3 - Interactive Charting with Dash for Productionalizing Your Data Science Application

Welcome back. To refresh your memory, in part 2, we finished initializing our Dash instance in `dash_setup.py`, which looked like this:

```python
# /app/dash_setup.py

import dash
from flask.helpers import get_root_path


def register_dashapps(app):
    """
    Register Dash apps with the Flask app
    """

    # external Bootstrap CSS stylesheets
    external_stylesheets = [
        'https://cdn.jsdelivr.net/npm/bootstrap@4.5.3/dist/css/bootstrap.min.css'
    ]
    
    # external Bootstrap JavaScript files
    external_scripts = [
        "https://code.jquery.com/jquery-3.5.1.slim.min.js",
        "https://cdn.jsdelivr.net/npm/popper.js@1.16.1/dist/umd/popper.min.js",
        "https://cdn.jsdelivr.net/npm/bootstrap@4.5.3/dist/js/bootstrap.min.js",
    ]

    # To ensure proper rendering and touch zooming for all devices, add the responsive viewport meta tag
    meta_viewport = [{
        "name": "viewport", 
        "content": "width=device-width, initial-scale=1, shrink-to-fit=no"
    }]

    dashapp = dash.Dash(
        __name__,
        # This is where the Flask app gets appointed as the server for the Dash app
        server = app,
        url_base_pathname = '/dash/',
        # Separate assets folder in "static_dash" (optional)
        assets_folder = get_root_path(__name__) + '/static_dash/', 
        meta_tags = meta_viewport, 
        external_scripts = external_scripts,
        external_stylesheets = external_stylesheets
    )
    dashapp.title = 'Dash Charts in Single-Page Application'

    # Some of these imports should be inside this function so that other Flask
    # stuff gets loaded first, since some of the below imports reference the other
    # Flask stuff, creating circular references 
    from app.dashapp.layout import get_layout
    from app.dashapp.callbacks import register_callbacks

    with app.app_context():

        # Assign the get_layout function without calling it yet
        dashapp.layout = get_layout

        # Register callbacks
        # Layout must be assigned above, before callbacks
        register_callbacks(dashapp)

    return None
```

At the bottom of that file we imported two modules.
```python
    ...

    from app.dashapp.layout import get_layout
    from app.dashapp.callbacks import register_callbacks

    ...
```

Then we put some bare-bones code in `layout.py` and `callbacks.py`. 

Let's begin part 3 by adding some more code to `layout.py`. Here's what it's going to look like after we add some code to the body (not just a navigation bar now):

```python
# /app/dashapp/layout.py

import os

from flask import url_for
import dash_html_components as html
import dash_core_components as dcc
import dash_bootstrap_components as dbc
from psycopg2.extras import RealDictCursor

# Local imports
from app.database import get_conn


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
                    dbc.DropdownMenuItem("Dash Bootstrap Components", href="https://dash-bootstrap-components.opensource.faculty.ai/"),
                    dbc.DropdownMenuItem("Testdriven", href="https://testdriven.io/"),
                ],
                nav=True,
                in_navbar=True,
                label="Links",
            ),
        ],
        brand="Home",
        brand_href="/",
        color="dark",
        dark=True,
    )


def get_sensor_types():
    """Get a list of different types of sensors"""
    sql = """
        --Get the labels and underlying values for the dropdown menu "children"
        SELECT 
            distinct 
            type as label, 
            type as value
        FROM sensors;
    """
    conn = get_conn()
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(sql)
        # types is a list of dictionaries that looks like this, for example:
        # [{'label': 'a', 'value': 'a'}]
        types = cursor.fetchall()
    
    return types


def get_body():
    """Get the body of the layout for our Dash SPA"""

    types = get_sensor_types()

    # The layout starts with a Bootstrap row, containing a Bootstrap column
    return dbc.Row(
        [
            # 1st column and dropdown (NOT empty at first)
            dbc.Col(
                [
                    html.Label('Types of Sensors', style={'margin-top': '1.5em'}),
                    dcc.Dropdown(
                        options=types,
                        value=types[0]['value'],
                        id="types_dropdown"
                    )
                ], xs=12, sm=6, md=4
            ),
            # 2nd column and dropdown (empty at first)
            dbc.Col(
                [
                    html.Label('Locations of Sensors', style={'margin-top': '1.5em'}),
                    dcc.Dropdown(
                        # options=None,
                        # value=None,
                        id="locations_dropdown"
                    )
                ], xs=12, sm=6, md=4
            ),
            # 3rd column and dropdown (empty at first)
            dbc.Col(
                [
                    html.Label('Sensors', style={'margin-top': '1.5em'}),
                    dcc.Dropdown(
                        # options=None,
                        # value=None,
                        id="sensors_dropdown"
                    )
                ], xs=12, sm=6, md=4
            ),
        ]
    )


def get_layout():
    """Function to get Dash's "HTML" layout"""

    # A Bootstrap 4 container holds the rest of the layout
    return dbc.Container(
        [
            get_navbar(),
            get_body(), 
        ], 
    )
```

Let's work from the bottom-up, starting with `get_layout()`. We've added `get_body()` below the navbar function.

Here's what the simple Flask site now looks like in the browser:

![Main page with a simple link to the Dash single-page application](/assets/images/posts/2020/timescale-dash-flask-part-3-click-here-to-see-the-main-dash-page.PNG)

Click the link to view the Dash site at `/dash/`:

**NOTE:** Your second and third dropdowns will be blank at this point. Only the first dropdown has been populated. For the second and third dropdowns, we'll use Dash callbacks instead of populating them in the initial layout. Stay tuned...

![Navigation bar and some dropdowns in the body](/assets/images/posts/2020/timescale-dash-flask-part-3-navbar-and-body.PNG#wide)

## View the site in development mode

I jumped over an important step--how to launch this Flask/Dash site in development so you can view it in your browser. 

Add a file called `.flaskenv` beside your `.env` file in the root project folder, with the following three lines:

```bash
FLASK_APP=wsgi.py
FLASK_RUN_HOST=0.0.0.0
FLASK_RUN_PORT=5002
```

Flask looks for the `.flaskenv` file when you type (spoiler alert) `flask run` in your terminal, and those environment variables tell it where to start, and where to publish (i.e. start with the `FLASK_APP` that's imported and created in `wsgi.py`, and publish on the `0.0.0.0` host, port `5002`).

So once you've created that `.flaskenv` file, type `flask run` and you're off to the races. Go to [http://localhost:5002](http://localhost:5002) in your browser to see your site.

## Back to the code

Getting back to the `layout.py` file, the `get_body()` function returns a Bootstrap `row` and three Boostrap `columns`--one for each of our Dash dropdown menus. 

Focusing on the first column for now, we see there's an `html.Label` "[Dash HTML Component](https://dash.plotly.com/dash-html-components)", followed by a `dcc.Dropdown` "[Dash Core Component](https://dash.plotly.com/dash-core-components)". You're creating Bootstrap HTML/CSS/JS with nothing but Python! That's the beauty of Dash, and for data scientists looking to productionalize their models and data, this is very convenient. 

```python
import dash_html_components as html
import dash_core_components as dcc

    ...

    types = get_sensor_types()

            ...

            dbc.Col(
                [
                    html.Label('Types of Sensors', style={'margin-top': '1.5em'}),
                    dcc.Dropdown(
                        options=types,
                        value=types[0]["value"],
                        id="types_dropdown"
                    )
                ], xs=12, sm=6, md=4
            ),

            ...
```

The `types` variable comes from the `get_sensor_types()` function, which queries our TimescaleDB database and returns the distinct/unique sensor types in a "list of dictionaries". That's what the `cursor_factory=RealDictCursor` does (i.e. returns the database rows as convenient Python dictionaries). Here's the `get_sensor_types()` function:

```python
from psycopg2.extras import RealDictCursor

# Local imports
from app.database import get_conn

...

def get_sensor_types():
    """Get a list of different types of sensors"""
    sql = """
        --Get the labels and underlying values for the dropdown menu "children"
        SELECT 
            distinct 
            type as label, 
            type as value
        FROM sensors;
    """
    conn = get_conn()
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(sql)
        # types is a list of dictionaries that looks like this, for example:
        # [{'label': 'a', 'value': 'a'}]
        types = cursor.fetchall()
    
    return types

...
```

Many Pythonistas enjoy querying their databases with [SQLAlchemy](https://www.sqlalchemy.org/), and I use it too, but sometimes I just wanna get dirty and write some SQL like the olden-days. The [psycopg2](https://www.psycopg.org/) library lets me do that very nicely. Both are great libraries--well-maintained and battle-tested. 

The other two columns and queries in our layout are basically the same as the first, so I won't go through them individually. 

## Callbacks in Dash

It's time to get into the callbacks, so we can make the second and third dropdown menus actually work. 

Here's a reminder of what we're trying to create with the following Python code:

```python
...
            # 2nd column and dropdown (empty at first)
            dbc.Col(
                [
                    html.Label('Locations of Sensors', style={'margin-top': '1.5em'}),
                    dcc.Dropdown(
                        # options=None,
                        # value=None,
                        id="locations_dropdown"
                    )
                ], xs=12, sm=6, md=4
            ),
            # 3rd column and dropdown (empty at first)
            dbc.Col(
                [
                    html.Label('Sensors', style={'margin-top': '1.5em'}),
                    dcc.Dropdown(
                        # options=None,
                        # value=None,
                        id="sensors_dropdown"
                    )
                ], xs=12, sm=6, md=4
            ),

...
```

Again, the second and third dropdowns should be empty at this point because of the following code in the `layout.py` file:

![Navigation bar and some dropdowns in the body](/assets/images/posts/2020/timescale-dash-flask-part-3-navbar-and-body.PNG#wide)

Finally, what we've all been waiting for--some fun interactivity in Dash! Paste the following into `callbacks.py`. 

This is where we're going to populate the 2nd and 3rd dropdown menus, based on the value from the first dropdown:

```python
# /app/dashapp/callbacks.py

import dash
import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output, State
from psycopg2.extras import RealDictCursor

# Local imports
from app.database import get_conn


def get_sensor_locations(type_):
    """Get a list of different locations of sensors"""
    sql = f"""
        --Get the labels and underlying values for the dropdown menu "children"
        SELECT 
            distinct 
            location as label, 
            location as value
        FROM sensors
        WHERE type = '{type_}';
    """
    conn = get_conn()
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(sql)
        # locations is a list of dictionaries that looks like this, for example:
        # [{'label': 'floor', 'value': 'floor'}]
        locations = cursor.fetchall()
    
    return locations


def get_sensors(type_, location):
    """
    Get a list of sensor dictionaries from our TimescaleDB database, 
    along with lists of distinct sensor types and locations
    """
    sql = f"""
        --Get the labels and underlying values for the dropdown menu "children"
        SELECT 
            location || ' - ' || type as label,
            id as value
        FROM sensors
        WHERE 
            type = '{type_}'
            and location = '{location}';
    """
    conn = get_conn()
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(sql)
        # sensors is a list of dictionaries that looks like this, for example:
        # [{'label': 'floor - a', 'value': 1}]
        sensors = cursor.fetchall()

    return sensors


def register_callbacks(dash_app):
    """Register the callback functions for the Dash app, within the Flask app""" 

    @dash_app.callback(
        [
            Output("locations_dropdown", "options"),
            Output("locations_dropdown", "value")
        ],
        [
            Input("types_dropdown", "value")
        ]
    )
    def get_locations_from_types(types_dropdown_value):
        """Get the location options, based on the type of sensor chosen"""

        # First get the location options (i.e. a list of dictionaries)
        location_options = get_sensor_locations(types_dropdown_value)

        # Default to the first item in the list, 
        # and get the "value" from the dictionary
        location_value = location_options[0]["value"]

        return location_options, location_value


    @dash_app.callback(
        [
            Output("sensors_dropdown", "options"),
            Output("sensors_dropdown", "value")
        ],
        [
            Input("types_dropdown", "value"),
            Input("locations_dropdown", "value")
        ]
    )
    def get_sensors_from_locations_and_types(types_dropdown_value, locations_dropdown_value):
        """Get the sensors available, based on both the location and type of sensor chosen"""

        # First get the sensor options (i.e. a list of dictionaries)
        sensor_options = get_sensors(types_dropdown_value, locations_dropdown_value)

        # Default to the first item in the list, 
        # and get the "value" from the dictionary
        sensor_value = sensor_options[0]["value"]

        return sensor_options, sensor_value


    return None
```

The `register_callbacks(dash_app)` function was called in `dash_setup.py`. Here's a refresher:

```python
    # /app/dash_setup.py
    ...

    # Some of these imports should be inside this function so that other Flask
    # stuff gets loaded first, since some of the below imports reference the other
    # Flask stuff, creating circular references 
    from app.dashapp.layout import get_layout
    from app.dashapp.callbacks import register_callbacks

    with app.app_context():

        # Assign the get_layout function without calling it yet
        dashapp.layout = get_layout

        # Register callbacks
        # Layout must be assigned above, before callbacks
        register_callbacks(dashapp) # HERE!
```

Let's focus on the first callback function. All Dash callbacks have `Input()` functions that trigger them, and `Output()` functions, which are the HTML elements that the callbacks are modifying. 

The first parameter in the `Input()` or `Output()` functions is always the `id=` of the element, from the `layout.py` file. The second parameter is always the **property** we're trying to modify. So in the callback function below, we're using the "value" from the "types_dropdown" dropdown as our input to the function, and we're modifying both the "options" and the selected "value" of the "locations_dropdown" dropdown. 

```python
    ... 

    @dash_app.callback(
        [
            Output("locations_dropdown", "options"),
            Output("locations_dropdown", "value")
        ],
        [
            Input("types_dropdown", "value")
        ]
    )
    def get_locations_from_types(types_dropdown_value):
        """Get the location options, based on the type of sensor chosen"""

        # First get the location options (i.e. a list of dictionaries)
        location_options = get_sensor_locations(types_dropdown_value)

        # Default to the first item in the list, 
        # and get the "value" from the dictionary
        location_value = location_options[0]["value"]

        return location_options, location_value

    ...
```

The second callback is only slightly more complicated than the first. It uses the values from both of the first two dropdowns (i.e. the types dropdown, *and* the locations dropdown) to filter the sensor options and selected value. 

```python
    @dash_app.callback(
        [
            Output("sensors_dropdown", "options"),
            Output("sensors_dropdown", "value")
        ],
        [
            Input("types_dropdown", "value"),
            Input("locations_dropdown", "value")
        ]
    )
    def get_sensors_from_locations_and_types(types_dropdown_value, locations_dropdown_value):
        """Get the sensors available, based on both the location and type of sensor chosen"""

        # First get the sensor options (i.e. a list of dictionaries)
        sensor_options = get_sensors(types_dropdown_value, locations_dropdown_value)

        # Default to the first item in the list, 
        # and get the "value" from the dictionary
        sensor_value = sensor_options[0]["value"]

        return sensor_options, sensor_value
```

Here's an example of one of our database queries, which grabs the unique sensors that match the type and location filters. The other database query is almost identical, except it only has to filter on sensor type.

```python

def get_sensors(type_, location):
    """
    Get a list of sensor dictionaries from our TimescaleDB database, 
    along with lists of distinct sensor types and locations
    """
    sql = f"""
        --Get the labels and underlying values for the dropdown menu "children"
        SELECT 
            location || ' - ' || type as label,
            id as value
        FROM sensors
        WHERE 
            type = '{type_}'
            and location = '{location}';
    """
    conn = get_conn()
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(sql)
        # sensors is a list of dictionaries that looks like this, for example:
        # [{'label': 'floor - a', 'value': 1}]
        sensors = cursor.fetchall()

    return sensors
```

Now let's deploy a nice time series chart, to show our chosen sensor's data over time.

Add the following `get_chart_row()` function to your `layout.py` file, near the bottom. This will give us a Bootstrap row/column in which to place a Dash chart via a callback:

```python
...

def get_chart_row(): # NEW
    """Create a row and column for our Plotly/Dash time series chart"""

    return dbc.Row(
        dbc.Col(
            id="time_series_chart_col"
        )
    )


def get_layout():
    """Function to get Dash's "HTML" layout"""

    # A Bootstrap 4 container holds the rest of the layout
    return dbc.Container(
        [
            get_navbar(),
            get_body(), 
            get_chart_row(), # NEW
        ], 
    )
```

Now for the chart itself, which is created in the callbacks.

First ensure you add the following imports to the `callbacks.py` file, and install them with `pip install pandas plotly`:

```python
import pandas as pd
import plotly.graph_objs as go
```

Second, the query to grab the actual time series data, also in the `callbacks.py` file. Notice this time we're creating a [Pandas](https://pandas.pydata.org/) DataFrame out of the data. Pandas is an essential library for data scientists working in Python. 

In a nutshell, and Pandas DataFrame is a table full of [NumPy](https://numpy.org/) arrays for columns, but we won't get into any of that right now. Just know Pandas and Numpy are extremely optimized for data science work.

```python
def get_sensor_time_series_data(sensor_id):
    """Get the time series data in a Pandas DataFrame, for the sensor chosen in the dropdown"""

    sql = f"""
        SELECT 
            --Get the 3-hour average instead of every single data point
            time_bucket('03:00:00'::interval, time) as time,
            sensor_id,
            avg(temperature) as temperature,
            avg(cpu) as cpu
        FROM sensor_data
        WHERE sensor_id = {sensor_id}
        GROUP BY 
            time_bucket('03:00:00'::interval, time), 
            sensor_id
        ORDER BY 
            time_bucket('03:00:00'::interval, time), 
            sensor_id;
    """

    conn = get_conn()
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(sql)
        rows = cursor.fetchall()
        columns = [str.lower(x[0]) for x in cursor.description]

    df = pd.DataFrame(rows, columns=columns)
    
    return df
```

Finally, the Dash/Plotly graph itself--we've reached the finish line!

Notice the callback updates the "children" property of the Bootstrap column with ID "time_series_chart_col". 

The callback uses one `Input()`, and two `State()`s as parameters to the function. The difference between and `Input()` and a `State()` is that the function is only called if the `Input()` changes. If the `State()`s change, the function doesn't get called, but we still have their values available to us in the function.

```python
    ...

    @dash_app.callback(
        Output("time_series_chart_col", "children"),
        [Input("sensors_dropdown", "value")],
        [
            State("types_dropdown", "value"),
            State("locations_dropdown", "value")
        ]
    )
    def get_time_series_chart(
        sensors_dropdown_value, 
        types_dropdown_value, 
        locations_dropdown_value
    ):
        """Get the sensors available, based on both the location and type of sensor chosen"""
```

Next up, we get the time series data (in a DataFrame, as mentioned previously), and grab the `time` column for the x-axis. 

We're going to be adding two line graphs (scatter-plots connected by lines), so we'll grab two columns from the dataframe, "temperature" and "cpu". Add a title variable as well, for the charts.

```python
        df = get_sensor_time_series_data(sensors_dropdown_value)
        x = df["time"]
        y1 = df["temperature"]
        y2 = df["cpu"]
        title = f"Location: {locations_dropdown_value} - Type: {types_dropdown_value}"
```

Now create two Plotly graph objects (e.g. `go.Scatter(`) for the two charts, and we'll pass them both to a `get_graph()` function we'll create next:

```python
        trace1 = go.Scatter(
            x=x,
            y=y1,
            name="Temp"
        )
        trace2 = go.Scatter(
            x=x,
            y=y2,
            name="CPU"
        )

        # Create two graphs using the traces above
        graph1 = get_graph(trace1, f"Temperature for {title}")
        graph2 = get_graph(trace2, f"CPU for {title}")
```

Now for the `get_graph()` function. Plotly/Dash charts have **lots** of options, but don't be overwhelmed; you'll get the hang of them. 

```python
def get_graph(trace, title):
    """Get a Plotly Graph object for Dash"""
    
    return dcc.Graph(
        # Disable the ModeBar with the Plotly logo and other buttons
        config=dict(
            displayModeBar=False
        ),
        figure=go.Figure(
            data=[trace],
            layout=go.Layout(
                title=title,
                plot_bgcolor="white",
                xaxis=dict(
                    autorange=True,
                    # Time-filtering buttons above chart
                    rangeselector=dict(
                        buttons=list([
                            dict(count=1,
                                label="1d",
                                step="day",
                                stepmode="backward"),
                            dict(count=7,
                                label="7d",
                                step="day",
                                stepmode="backward"),
                            dict(count=1,
                                label="1m",
                                step="month",
                                stepmode="backward"),
                            dict(step="all")
                        ])
                    ),
                    type = "date",
                    # Alternative time filter slider
                    rangeslider = dict(
                        visible = True
                    )
                )
            )
        )
    )
```

The first parameter disables the Plotly logo (totally optional):
```python
        config=dict(
            displayModeBar=False
        ),
```

Next in the graph object is the `figure` parameter, which contains two main sub-parameters, `data` and `layout`. Here's the full [API reference](https://plotly.com/python-api-reference/plotly.graph_objects.html), which is an essential resource if you're working with Plotly charts. 

In the `layout`, I add quite a few options for the `xaxis` since it's a time series chart, and you'll probably want some quick time filters. Usually I'd choose either the `rangeselector` buttons above the chart, or the `rangeslider` below the chart, but I'm adding both to show you what's available. I prefer the `rangeselector` buttons above the chart. If you're into stock trading, you'll know these time filters are quite common and intuitive.

Finally, below the `get_graph()` functions, well return a simple HTML `div` with two Bootstrap rows (a Bootstrap row must always contain at least one column):

```python
        return html.Div(
            [
                dbc.Row(dbc.Col(graph1)),
                dbc.Row(dbc.Col(graph2)),
            ]
        )
```

We're done! Here's what the site should look like now:

![Finished web app with Dash dropdown callbacks and Plotly time series charts](/assets/images/posts/2020/timescale-dash-flask-part-3-finished-product.PNG#wide)

Here's the full `callbacks.py` file, for your copying and pasting pleasure:

```python
# /app/dashapp/callbacks.py

import dash
import dash_html_components as html
import dash_core_components as dcc
import dash_bootstrap_components as dbc
from dash.dependencies import Input, Output, State
from psycopg2.extras import RealDictCursor
import pandas as pd
import plotly.graph_objs as go

# Local imports
from app.database import get_conn


def get_sensor_locations(type_):
    """Get a list of different locations of sensors"""
    sql = f"""
        --Get the labels and underlying values for the dropdown menu "children"
        SELECT 
            distinct 
            location as label, 
            location as value
        FROM sensors
        WHERE type = '{type_}';
    """
    conn = get_conn()
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(sql)
        # locations is a list of dictionaries that looks like this, for example:
        # [{'label': 'floor', 'value': 'floor'}]
        locations = cursor.fetchall()
    
    return locations


def get_sensors(type_, location):
    """
    Get a list of sensor dictionaries from our TimescaleDB database, 
    along with lists of distinct sensor types and locations
    """
    sql = f"""
        --Get the labels and underlying values for the dropdown menu "children"
        SELECT 
            location || ' - ' || type as label,
            id as value
        FROM sensors
        WHERE 
            type = '{type_}'
            and location = '{location}';
    """
    conn = get_conn()
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(sql)
        # sensors is a list of dictionaries that looks like this, for example:
        # [{'label': 'floor - a', 'value': 1}]
        sensors = cursor.fetchall()

    return sensors


def get_sensor_time_series_data(sensor_id):
    """Get the time series data in a Pandas DataFrame, for the sensor chosen in the dropdown"""

    sql = f"""
        SELECT 
            --Get the 3-hour average instead of every single data point
            time_bucket('03:00:00'::interval, time) as time,
            sensor_id,
            avg(temperature) as temperature,
            avg(cpu) as cpu
        FROM sensor_data
        WHERE sensor_id = {sensor_id}
        GROUP BY 
            time_bucket('03:00:00'::interval, time), 
            sensor_id
        ORDER BY 
            time_bucket('03:00:00'::interval, time), 
            sensor_id;
    """

    conn = get_conn()
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute(sql)
        rows = cursor.fetchall()
        columns = [str.lower(x[0]) for x in cursor.description]

    df = pd.DataFrame(rows, columns=columns)
    
    return df


def get_graph(trace, title):
    """Get a Plotly Graph object for Dash"""
    
    return dcc.Graph(
        # Disable the ModeBar with the Plotly logo and other buttons
        config=dict(
            displayModeBar=False
        ),
        figure=go.Figure(
            data=[trace],
            layout=go.Layout(
                title=title,
                plot_bgcolor="white",
                xaxis=dict(
                    autorange=True,
                    # Time-filtering buttons above chart
                    rangeselector=dict(
                        buttons=list([
                            dict(count=1,
                                label="1d",
                                step="day",
                                stepmode="backward"),
                            dict(count=7,
                                label="7d",
                                step="day",
                                stepmode="backward"),
                            dict(count=1,
                                label="1m",
                                step="month",
                                stepmode="backward"),
                            dict(step="all")
                        ])
                    ),
                    type = "date",
                    # Alternative time filter slider
                    rangeslider = dict(
                        visible = True
                    )
                )
            )
        )
    )


def register_callbacks(dash_app):
    """Register the callback functions for the Dash app, within the Flask app""" 

    @dash_app.callback(
        [
            Output("locations_dropdown", "options"),
            Output("locations_dropdown", "value")
        ],
        [
            Input("types_dropdown", "value")
        ]
    )
    def get_locations_from_types(types_dropdown_value):
        """Get the location options, based on the type of sensor chosen"""

        # First get the location options (i.e. a list of dictionaries)
        location_options = get_sensor_locations(types_dropdown_value)

        # Default to the first item in the list, 
        # and get the "value" from the dictionary
        location_value = location_options[0]["value"]

        return location_options, location_value


    @dash_app.callback(
        [
            Output("sensors_dropdown", "options"),
            Output("sensors_dropdown", "value")
        ],
        [
            Input("types_dropdown", "value"),
            Input("locations_dropdown", "value")
        ]
    )
    def get_sensors_from_locations_and_types(types_dropdown_value, locations_dropdown_value):
        """Get the sensors available, based on both the location and type of sensor chosen"""

        # First get the sensor options (i.e. a list of dictionaries)
        sensor_options = get_sensors(types_dropdown_value, locations_dropdown_value)

        # Default to the first item in the list, 
        # and get the "value" from the dictionary
        sensor_value = sensor_options[0]["value"]

        return sensor_options, sensor_value


    @dash_app.callback(
        Output("time_series_chart_col", "children"),
        [Input("sensors_dropdown", "value")],
        [
            State("types_dropdown", "value"),
            State("locations_dropdown", "value")
        ]
    )
    def get_time_series_chart(
        sensors_dropdown_value, 
        types_dropdown_value, 
        locations_dropdown_value
    ):
        """Get the sensors available, based on both the location and type of sensor chosen"""

        df = get_sensor_time_series_data(sensors_dropdown_value)
        x = df["time"]
        y1 = df["temperature"]
        y2 = df["cpu"]
        title = f"Location: {locations_dropdown_value} - Type: {types_dropdown_value}"

        trace1 = go.Scatter(
            x=x,
            y=y1,
            name="Temp"
        )
        trace2 = go.Scatter(
            x=x,
            y=y2,
            name="CPU"
        )

        # Create two graphs using the traces above
        graph1 = get_graph(trace1, f"Temperature for {title}")
        graph2 = get_graph(trace2, f"CPU for {title}")

        return html.Div(
            [
                dbc.Row(dbc.Col(graph1)),
                dbc.Row(dbc.Col(graph2)),
            ]
        )
```

That's it! We've accomplished a lot in this three-part tutorial. 

In the [first part]({% post_url 2020-11-07-timescale-dash-flask-part-1 %}), we created a TimescaleDB database and populated it with simulated IoT sensor time series data. We also created a PGAdmin web app for administering our database, and both of those applications were deployed using Docker-Compose--an awesome tool for reproducible environments and deployment. 

In the [second part]({% post_url 2020-11-08-timescale-dash-flask-part-2 %}), we combined a Flask web app with a Dash web app so we could have the best of both worlds--Flask can do pretty much anything, and Dash is great for productionalizing data science single-page apps without needing any JavaScript or React. 

In this third part, we dove into Dash with interactive dropdown menu callbacks and Plotly charts to give a taste of what's possible with Dash.

I hope you've enjoyed the series. Stay safe and keep learning.<br>
Sean
