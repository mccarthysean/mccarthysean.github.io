---
layout: post
title: Dash Integration with Flask
# slug: dash-integration-with-flask
chapter: 2
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


Let's get started creating and integrating the Dash app, and ensuring the user has to log in to play with it. 

First, head back to the `__init__.py` file and uncomment the following lines. This is where we're going to initialize the Dash app.
```python
from app.dash_setup import register_dashapp

...

    # Register the Dash app, after ensuring the database tables exist
    dashapp = register_dashapp(app)
```

Also change the bottom line of the `__init__.py` file from `return app` to `return app, dashapp`. This will be useful in the testing chapter, for integration-testing our Dash app.

Let's now build out the `dash_setup` module, from which we import the `register_dashapps` function. Create a file called `dash_setup.py` inside the /app folder, beside `__init__.py`. Here's all the code; I'll explain below.

```python
# /app/dash_setup.py

import dash
from flask import current_app
from flask.helpers import get_root_path
from flask_login import login_required


def protect_dashviews(dashapp):
    """If you want your Dash app to require a login,
    call this function with the Dash app you want to protect"""

    for view_func in dashapp.server.view_functions:
        if view_func.startswith(dashapp.config.url_base_pathname):
            dashapp.server.view_functions[view_func] = login_required(
                dashapp.server.view_functions[view_func]
            )


def register_dashapp(server):
    """Register Dash apps with the Flask app"""

    # external Bootstrap CSS stylesheets
    external_stylesheets = [
        "https://cdn.jsdelivr.net/npm/bootstrap@4.5.3/dist/css/bootstrap.min.css"
    ]

    # external Bootstrap JavaScript files
    external_scripts = [
        "https://code.jquery.com/jquery-3.5.1.slim.min.js",
        "https://cdn.jsdelivr.net/npm/popper.js@1.16.1/dist/umd/popper.min.js",
        "https://cdn.jsdelivr.net/npm/bootstrap@4.5.3/dist/js/bootstrap.min.js",
    ]

    # To ensure proper rendering and touch zooming for all devices, add the responsive viewport meta tag
    meta_viewport = [
        {
            "name": "viewport",
            "content": "width=device-width, initial-scale=1, shrink-to-fit=no",
        }
    ]

    dashapp = dash.Dash(
        __name__,
        # This is where the Flask app gets appointed as the server for the Dash app
        server=server,
        url_base_pathname="/dash/",
        # Folder for extra CSS, images, JavaScript, etc.
        assets_folder=get_root_path(__name__) + "/static/",
        meta_tags=meta_viewport,
        external_scripts=external_scripts,
        external_stylesheets=external_stylesheets,
    )
    dashapp.title = "Dash Charts in Single-Page Application"

    # Some of these imports should be inside this function so that other Flask
    # stuff gets loaded first, since some of the below imports reference the other
    # Flask stuff, creating circular references
    from app.dashapp.callbacks import register_callbacks
    from app.dashapp.layout import get_layout

    with server.app_context():

        # Assign the get_layout function without calling it yet
        dashapp.layout = get_layout

        # Register callbacks
        # Layout must be assigned above, before callbacks
        register_callbacks(dashapp)

    # If you require a login for your Dash app, call this function
    protect_dashviews(dashapp)

    return dashapp
```

The first function in our module is `protect_dashviews`. This is where we require users to be logged in to view the Dash app. It simply loops through each `view_function` in the Flask "server", and if the view_func starts with "/dash/", it encapsulates the `view_function` inside Flask-Login's `login_required` function. Pretty slick, if you ask me.

```python
def protect_dashviews(dashapp):
    """
    If you want your Dash app to require a login,
    call this function with the Dash app you want to protect
    """

    for view_func in dashapp.server.view_functions:
        if view_func.startswith(dashapp.config.url_base_pathname):
            dashapp.server.view_functions[view_func] = login_required(
                dashapp.server.view_functions[view_func]
            )
```

Next, the all-important `register_dashapps(server)` function gets passed the Flask application instance, which Dash will assign as Dash's "server". 

The Dash app starts by initializing some of the HTML "head" metadata, which is the first HTML stuff at the top of any HTML page. We pass the `dash.Dash()` class a few stylesheets and scripts. 

We're going to use Bootstrap CSS to make our single-page application both *look* great, and *work* great on mobile phones. Bootstrap 4 needs Popper and jQuery, so we include those as per the Bootstrap setup guidelines [here](https://getbootstrap.com/docs/4.5/getting-started/introduction/).

```python
def register_dashapp(server):
    """Register Dash apps with the Flask app"""

    # external Bootstrap CSS stylesheets
    external_stylesheets = [
        "https://cdn.jsdelivr.net/npm/bootstrap@4.5.3/dist/css/bootstrap.min.css"
    ]

    # external Bootstrap JavaScript files
    external_scripts = [
        "https://code.jquery.com/jquery-3.5.1.slim.min.js",
        "https://cdn.jsdelivr.net/npm/popper.js@1.16.1/dist/umd/popper.min.js",
        "https://cdn.jsdelivr.net/npm/bootstrap@4.5.3/dist/js/bootstrap.min.js",
    ]

    # To ensure proper rendering and touch zooming for all devices, add the responsive viewport meta tag
    meta_viewport = [
        {
            "name": "viewport",
            "content": "width=device-width, initial-scale=1, shrink-to-fit=no",
        }
    ]

    dashapp = dash.Dash(
        __name__,
        # This is where the Flask app gets appointed as the server for the Dash app
        server=server,
        url_base_pathname="/dash/",
        # Folder for extra CSS, images, JavaScript, etc.
        assets_folder=get_root_path(__name__) + "/static/",
        meta_tags=meta_viewport,
        external_scripts=external_scripts,
        external_stylesheets=external_stylesheets,
    )
    dashapp.title = "Dash Charts in Single-Page Application"
```

Now that we've initialized the Dash instance (dashapp), we're going to create its HTML/CSS layout and JavaScript callbacks (React JavaScript behind-the-scenes). 

To avoid Flask circular references (again), import the layout and callback modules inside the `register_dashapps(app)` function.

```python
    ... 

    # Some of these imports should be inside this function so that other Flask
    # stuff gets loaded first, since some of the below imports reference the other
    # Flask stuff, creating circular references
    from app.dashapp.callbacks import register_callbacks
    from app.dashapp.layout import get_layout

    with server.app_context():

        # Assign the get_layout function without calling it yet
        dashapp.layout = get_layout

        # Register callbacks
        # Layout must be assigned above, before callbacks
        register_callbacks(dashapp)

    # If you require a login for your Dash app, call this function
    protect_dashviews(dashapp)

    return dashapp
```

Now to create the files we just imported... Create a "dashapp" folder inside your "app" folder, containing three new files:
1. `__init__.py`
2. `callbacks.py`
3. `layout.py`

Don't worry about the `__init__.py` file--it's just there so Python (and you) know the folder is part of the package. 

In the next chapter, we'll build out the `layout.py` file for the HTML layout. Then in Chapter 5, we'll work on the callbacks for interactivity.


{% include end_to_end_ml_table_of_contents.html %}
