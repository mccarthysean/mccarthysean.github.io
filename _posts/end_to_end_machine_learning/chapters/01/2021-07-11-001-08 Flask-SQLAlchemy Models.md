---
layout: post
title: Flask-SQLAlchemy Models
# slug: flask-sqlalchemy models
chapter: 8
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


Now that we have a basic Flask web app set up, let's add Flask-SQLAlchemy so we can easily work with our database, especially for things like user registration and login (essential stuff for most sites).

Let's jump right to the finish line for the `__init__.py` file. And I do mean *right to the finish line*. This is everything we're ever going to add to our `__init__.py` file. 

I've simply commented out the stuff we'll be talking about in the future, but you can see it there now, foreshadowing...

```python
# /app/__init__.py

import logging
import os

# Third-party imports
from flask import Flask, render_template
from flask_bootstrap import Bootstrap
from flask_login import LoginManager # new
from flask_sqlalchemy import SQLAlchemy # new

# Local imports
from app import database
# from app.dash_setup import register_dashapp # new
# from app.views import register_views # new

logging.basicConfig(level=logging.DEBUG)
db = SQLAlchemy() # new
login_manager = LoginManager() # new


def create_app():
    """Factory function that creates the Flask app"""

    app = Flask(__name__)
    # Set a few configuration variables
    app.config["SECRET_KEY"] = os.getenv("SECRET_KEY")

    # SQLAlchemy settings for the database
    app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv("SQLALCHEMY_DATABASE_URI")
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    # TimescaleDB needs the following SQLAlchemy options to be set,
    # for the connection pool, so it doesn't time out and cause a 500 server error
    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
        # pre-ping to see if the connection is still available, or should be recycled
        "pool_pre_ping": True,
        "pool_size": 10, # 10 connections in the pool
        "pool_timeout": 10, # seconds
        "pool_recycle": 300, # seconds
    }

    # Initialize extensions
    db.init_app(app)  # SQLAlchemy for database management
    Bootstrap(app)  # Flask-Bootstrap for easy styling
    login_manager.init_app(app)  # Flask-Login

    The name of the log-in view for Flask-Login
    login_manager.login_view = "login"

    # Register the Flask homepage, login, register, and logout views
    # register_views(app)

    # Ensure the database tables exist. If not, create them
    database.init_app(app)
    # database.check_db_tables(app, db)

    # Register the Dash app, after ensuring the database tables exist
    # dashapp = register_dashapp(app)

    return app
    # return app, dashapp
```

Firstly, above the `create_app()` factory function, we've created the Flask-SQLAlchemy database object with `db = SQLAlchemy()`. This way we can import the `db` object from other modules, but we don't *actually* initialize the `db` object quite yet. We do that inside the `create_app()` factory function, as is best practice. 

While we're at it, we also create the Flask-Login `login_manager` instance with `login_manager = LoginManager()`. We'll need that soon enough, to require users to log in (and, of course, register an account) to view our machine learning app.

Inside the `create_app()` factory function, we actually initialize our instances, by passing them the Flask `app` instance:
```python
    # Initialize extensions
    db.init_app(app)  # SQLAlchemy for database management
    Bootstrap(app)  # Flask-Bootstrap for easy styling
    login_manager.init_app(app)  # Flask-Login
```

I've left a few other things commented out below that. For now, let's create our SQLAlchemy models. In your root `app` directory, create a `models.py` file and paste in the following imports:

```python
import os
import time

from flask_login import UserMixin
from sqlalchemy import Computed, String
from sqlalchemy.dialects.postgresql import INTEGER, NUMERIC, TEXT, TIMESTAMP
from sqlalchemy.ext.associationproxy import association_proxy
from sqlalchemy.ext.hybrid import hybrid_property
from sqlalchemy.orm import column_property, relationship
from werkzeug.security import check_password_hash, generate_password_hash

from app import db, login_manager
```

Notice the bottom line, `from app import db, login_manager`. Here we import the objects we instantiated in `__init__.py`, outside of the `create_app()` factory function. Neat trick.

Now for our first SQLAlchemy `User` model, for website users to register and login. This is a very basic SQLAlchemy model, which models a single record in the `public.users` table in our TimescaleDB database. The variables such as `email`, `first_name`, and `last_name` are fields or columns in the table. They're all `TEXT` type in PostgreSQL/TimescaleDB, and the `id` field is the primary key, which is the unique lookup ID for the table. It is very common for `id` to be the primary key. No two users will be allowed to have the same email address since the `email` variable sets the parameter `unique` to `True`, and the database will enforce that. I'll explain more after you see the model below.

```python
class User(UserMixin, db.Model):
    """Create a User model for the "public.users" database table"""

    __tablename__ = "users"

    id = db.Column(INTEGER, primary_key=True)
    email = db.Column(TEXT, unique=True, nullable=False)
    first_name = db.Column(TEXT, nullable=False)
    last_name = db.Column(TEXT, nullable=False)
    password_hash = db.Column(TEXT, nullable=False)

    last_login_at = db.Column(TIMESTAMP)
    login_count = db.Column(INTEGER)

    @property
    def password(self):
        """Prevent password from being accessed"""
        raise AttributeError("password is not a readable attribute.")

    @password.setter
    def password(self, password):
        """Set password to a hashed password"""
        self.password_hash = generate_password_hash(password)

    def verify_password(self, password):
        """Check if hashed password matches actual password"""
        return check_password_hash(self.password_hash, password)

    def __repr__(self):
        return str(self.email)
```

There are a few other interesting things about this `User` model. The first is the `password` field, which is not actually a field at all, in the database table, but rather a "setter" for the actual `password_hash` field. 

Note if you try to view the password, you'll get an error:
```python
    @property
    def password(self):
        """Prevent password from being accessed"""
        raise AttributeError("password is not a readable attribute.")
```

And setting the password uses the `generate_password_hash` method from the `werkzeug.security` library that gets installed with Flask. This ensures you can't actually read the user's password in the database. It's a one-way encryption thing, and it's best-practice security-wise.
```python
    @password.setter
    def password(self, password):
        """Set password to a hashed password"""
        self.password_hash = generate_password_hash(password)
```

Later on, when the user logs in, the `verify_password` method will be called to check the user's actual supplied password against the hashed password in the database. Note the `check_password_hash` method also comes from the `werkzeug.security` library.
```python
    def verify_password(self, password):
        """Check if hashed password matches actual password"""
        return check_password_hash(self.password_hash, password)
```

That's it for the `models.py` file. Nice to get that out of the way. Next up, user registration and login with some Flask forms.
