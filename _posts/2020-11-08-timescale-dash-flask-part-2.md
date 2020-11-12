---
layout: post
title: 'Time Series Charts with Dash, Flask, TimescaleDB, and Docker - Part 2'
tags: [Python, TimescaleDB, Dash, Flask]
featured_image_thumbnail:
featured_image: assets/images/posts/2020/python-code-chris-ried-ieic5Tq8YMk-unsplash.jpg
featured: true
hidden: false
---

This is the second of three articles on TimescaleDB, Flask, and Dash. The [first article]({% post_url 2020-11-07-timescale-dash-flask-part-1 %}) focused on getting the [TimescaleDB](https://www.timescale.com/) database running with [Docker](https://www.docker.com/), along with [PGAdmin](https://www.pgadmin.org/) for administering it. This article focuses on the Python language, creating a [Flask](https://flask.palletsprojects.com/) website and then integrating the [Dash](https://plotly.com/dash/) web framework into Flask. 

Flask is a very popular Python web framework, light-weight and extensible, so it's very well-suited for data science applications. Dash is a web framework built on top of Flask, which uses [React](https://reactjs.org/) JavaScript behind-the-scenes to create reactive, interactive single-page applications (SPAs) featuring [Plotly](https://plotly.com/) charts. I would say Dash is to Python what [Shiny](https://shiny.rstudio.com/) is to [R](https://www.r-project.org/), in that both focus on productionalizing data science and machine learning models, without a user having to learn much HTML, CSS, and JavaScript. Typically data scientists are not software engineers, and the intricacies of making a single-page web application are far too complicated and not worth their time. 

This tutorial shows you how to get the best of a few different worlds:

1. A Flask application for your normal website
2. A fancy Dash single-page application that employs the best of React JavaScript
3. A way to productionalize your data science application

Let's start with a simple Flask web application, and I'll show you how to integrate Dash. Part 3 of this series will dive deeper into making interactive charts in Dash.

All the code for this tutorial can be found [here](https://github.com/mccarthysean/TimescaleDB-Dash-Flask) at GitHub. 

# Part 2 - Integrating Python Flask and Dash Web Frameworks

Before we can get started with Python, we always have to create a dedicated Python3 virtual environment. Let's just use `python3 -m venv venv` to create a virtual environment called "venv" in our root project folder. These days I prefer using [Poetry](https://python-poetry.org/) to [Pip](https://pypi.org/project/pip/), but Poetry is not the focus of this article. Now activate the virtual environment with `source venv/bin/activate` on Linux/Mac, or `venv\Scripts\activate.bat` on Windows. Once you've activated the virtual environment, install Flask, Dash, Dash Bootstrap Components, and the PostgreSQL library psycopg2, with `pip install flask dash dash-bootstrap-components psycopg2-binary`.

As an aside, I actually run Windows 10 Pro, as many data scientists do, especially those who come from the business world. So I use VS Code as my IDE, and I code inside a Linux Docker container in VS Code. Check out the documentation for that [here](https://code.visualstudio.com/docs/remote/containers), but once again, that's not the focus of this article.

To create a Flask application, let's start from the outermost entrypoint, or the starting point for the application. In your top-level folder, create a `wsgi.py` file as follows. This is best practice using the `factory pattern` for initializing Flask.

```python
# wsgi.py

from app import create_app

app = create_app()
```

The `wsgi.py` file is looking in a folder called `app` for a function called `create_app`, so let's create an `app` folder to house our Flask application. Inside the app folder, as for all Python packages, create an `__init__.py` file:

```python
# /app/__init__.py

import os
import logging

# Third-party imports
from flask import Flask, render_template

# Local imports
from app import database
from app.dash_setup import register_dashapps


def create_app():
    """Factory function that creates the Flask app"""

    app = Flask(__name__)
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
    logging.basicConfig(level=logging.DEBUG)

    @app.route('/')
    def home():
        """Our only non-Dash route, to demonstrate that Flask can be used normally"""
        return render_template('index.html')

    # Initialize extensions
    database.init_app(app) # PostgreSQL db with psycopg2

    # For the Dash app
    register_dashapps(app)

    return app
```

The above file contains the `create_app()` factory function that the previous `wsgi.py` file needed. Ignore the local imports for now--we'll get back to those.

Inside the `create_app()` factory function, we start off with the basics, instantiating the Flask() instance by passing it the `__name__` of the file and setting the `SECRET_KEY`... Secret key?

```python
def create_app():
    """Factory function that creates the Flask app"""

    app = Flask(__name__)
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
```

Let's open up the `.env` file and add a `SECRET_KEY` environment variable to the bottom of the file, along with your other environment variables:
```bash
# .env

# For the Postgres/TimescaleDB database. 
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_HOST=timescale
POSTGRES_PORT=5432
POSTGRES_DB=postgres
PGDATA=/var/lib/postgresql/data

# For the PGAdmin web app
PGADMIN_DEFAULT_EMAIL=your@email.com
PGADMIN_DEFAULT_PASSWORD=password

# For Flask
SECRET_KEY=long-random-string-of-characters-numbers-etc-must-be-unique # NEW
```

Back to our `__init__.py` file, we setup basic logging and then add our first Flask "route" (the main homepage), just to demonstrate that we've got a normal, working Flask application. 

```python
def create_app():
    """Factory function that creates the Flask app"""

    app = Flask(__name__)
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
    logging.basicConfig(level=logging.DEBUG)

    @app.route('/')
    def home():
        """Our only non-Dash route, to demonstrate that Flask can be used normally"""
        return render_template('index.html')
```

Create a `/app/templates` folder for HTML templates and add an `index.html` file with the following contents for the homepage route:

```html
<html>
    <body>
        <h1 style="text-align: center;">
            Click <a href="/dash/">here</a> to see the Dash single-page application (SPA)
        </h1>
    </body>
</html>
```

Next up, we initialize our database stuff with `database.init_app(app)`. "database" is a local module we imported at the top, so we'll deal with that next.

```python
# Local imports
from app import database # we're dealing with this import now

def create_app():
    """Factory function that creates the Flask app"""

    app = Flask(__name__)
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
    logging.basicConfig(level=logging.DEBUG)

    @app.route('/')
    def home():
        """Our only non-Dash route, to demonstrate that Flask can be used normally"""
        return render_template('index.html')

    # Initialize extensions
    database.init_app(app) # PostgreSQL db with psycopg2
```

Let's create the `database.py` module next, beside the `__init__.py` file. Let's follow Flask's recommended best-practices [here](https://flask.palletsprojects.com/en/1.1.x/tutorial/database/). The point of this module is to make some functions for getting and closing a TimescaleDB database connection, and ensuring that connection is closed by Flask at the end of the HTTP request. The "init_app(app)" function is what gets called from our `__init__.py` `create_app()` factory function. Notice the `teardown_appcontext(close_db)` that ensures the connection is closed on "teardown". Pretty slick. In the future, when we need data from the database, we'll just call `get_conn()` to get a database connection for running our SQL.

In case you're wondering, `g` is *basically* a global object in which you store your database connection. It's complicated so I won't get into it--just know this is best-practice and enjoy your life. ;) Okay fine, here's a [link](https://flask.palletsprojects.com/en/1.1.x/appcontext/#storing-data) for further reading... 

If you're looking for great course on Flask, including a deep-dive into Flask's mechanics, I highly recommend [this course](https://testdriven.io/courses/learn-flask/) by Patrick Kennedy.

```python

import os
import psycopg2
from flask import g


def get_conn():
    """
    Connect to the application's configured database. The connection
    is unique for each request and will be reused if this is called
    again.
    """
    if 'conn' not in g:
        g.conn = psycopg2.connect(
            host=os.getenv('POSTGRES_HOST'),
            port=os.getenv("POSTGRES_PORT"), 
            dbname=os.getenv("POSTGRES_DB"), 
            user=os.getenv("POSTGRES_USER"), 
            password=os.getenv("POSTGRES_PASSWORD"), 
            connect_timeout=5
        )
    
    return g.conn


def close_db(e=None):
    """
    If this request connected to the database, close the
    connection.
    """
    conn = g.pop('conn', None)

    if conn is not None:
        conn.close()
    
    return None


def init_app(app):
    """
    Register database functions with the Flask app. This is called by
    the application factory.
    """
    app.teardown_appcontext(close_db)
```

Finally, at the bottom of the `create_app()` function, we run the `register_dashapps(app)` function from the `dash_setup.py` module. This is where we're going to initialize the Dash web application that uses React JavaScript under the hood. More on that below.

```python
from app.dash_setup import register_dashapps


def create_app():
    """Factory function that creates the Flask app"""

    app = Flask(__name__)
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
    logging.basicConfig(level=logging.DEBUG)

    @app.route('/')
    def home():
        """Our only non-Dash route, to demonstrate that Flask can be used normally"""
        return render_template('index.html')

    # Initialize extensions
    database.init_app(app) # PostgreSQL db with psycopg2

    # For the Dash app
    register_dashapps(app)

    return app
```


## Dash Integration

We're almost there now. Let's move on to the `dash_setup` module, from which we import the `register_dashapps` function. Create a file called `dash_setup.py` inside the /app folder, beside `__init__.py`:

```python
# /app/dash_setup.py

import dash
from flask.helpers import get_root_path


def register_dashapps(app):
    """
    Register Dash apps with the Flask app
    """

    # external CSS stylesheets
    external_stylesheets = [
        'https://cdn.jsdelivr.net/npm/bootstrap@4.5.3/dist/css/bootstrap.min.css'
    ]
    
    # external JavaScript files
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

The `register_dashapps(app)` function gets passed the Flask application instance, which Dash will assign as Dash's "server". 

First, we'll create an HTML template of sorts by passing the `dash.Dash()` class a few stylesheets and scripts. These .js and .css files are found in the "head" section of HTML files, so Dash will put them there for us. 

We're going to be using Bootstrap CSS to make our single-page application look great, and work great on mobile phones. Bootstrap 4 also needs Popper and jQuery, so we include those as per the Bootstrap setup guidelines [here](https://getbootstrap.com/docs/4.5/getting-started/introduction/).

```python
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
```

Now that we've initialized the Dash instance (dashapp), we're going to create its HTML/CSS layout and JavaScript callbacks (React JavaScript behind-the-scenes). 

To avoid circular references, import the layout and callback modules inside the `register_dashapps(app)` function.

```python
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
        register_callbacks(dashapp)

    return None
```

Create a "dashapp" folder inside your "app" folder, containing three new files:
1. `__init__.py`
2. `callbacks.py`
3. `layout.py`

Don't worry about the `__init__.py` file--it's just there so Python (and you) know the folder is part of the package. 

[Part 3]({% post_url 2020-11-11-timescale-dash-flask-part-3 %}) goes into more depth on the Dash layout and callbacks, so for now let's just setup the basics. 

First, `layout.py`, which for now will just contain a Bootstrap navigation bar inside a Bootstrap container:

```python
# /app/dashapp/layout.py

import os

from flask import url_for
import dash_html_components as html
import dash_core_components as dcc
import dash_bootstrap_components as dbc
import psycopg2
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


def get_layout():
    """Function to get Dash's "HTML" layout"""

    # A Bootstrap 4 container holds the rest of the layout
    return dbc.Container(
        [
            # Just the navigation bar at the top for now...
            # Stay tuned for part 3!
            get_navbar(),
        ], 
    )
```

The `get_layout()` function is called from our `dash_setup.py` module, like this:

```python
    ...

    with app.app_context():

        # Assign the get_layout function without calling it yet
        dashapp.layout = get_layout
```

I won't explain the `get_navbar()` function because I think it's self-explanatory, but [here's](https://dash-bootstrap-components.opensource.faculty.ai/docs/components/navbar/) the documentation.

The Dash callbacks are the focus of [Part 3]({% post_url 2020-11-11-timescale-dash-flask-part-3 %}) of this series, so for now let's just fill the `callbacks.py` file with this:

```python
# /app/dashapp/callbacks.py

import dash
import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output, State


def register_callbacks(dash_app):
    """Register the callback functions for the Dash app, within the Flask app"""        

    return None
```

If you want to read more about Dash layout and callbacks, before [Part 3]({% post_url 2020-11-11-timescale-dash-flask-part-3 %}), check out the documentation [here](https://dash.plotly.com/layout).

That's it for Part 2. I hope you've enjoyed it so far. Check out [Part 3]({% post_url 2020-11-11-timescale-dash-flask-part-3 %}) for a deep dive into Dash callbacks and [Plotly](https://plotly.com/python/) charting.

Cheers,<br>
Sean
