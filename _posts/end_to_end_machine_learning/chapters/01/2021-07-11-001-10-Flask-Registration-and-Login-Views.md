---
layout: post
title: Flask Registration and Login Views
# slug: flask-registration-and-login-views
chapter: 10
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


In the previous chapter, we created the user registration and login forms. Now let's create the web pages on which to display those forms.

Again, I'm gonna throw all the code at you, so you can have a quick skim and develop some questions in your mind. Then I'll read your mind and answer your questions below...

Create a `views.py` file beside the `models.py` and `forms.py` file, and copy and paste in the below code:

```python
import datetime
import json
import os

from flask import (
    Response,
    abort,
    current_app,
    flash,
    redirect,
    render_template,
    request,
    send_from_directory,
    url_for,
)
from flask_login import current_user, login_required, login_user, logout_user


def _redirect():
    """Finds where to redirect the user"""

    next_url = request.args.get("next")
    if next_url:
        return redirect(next_url)

    return redirect("/dash/")


def register_views(app):
    """Register all views with the Flask app"""

    # Import our forms and User model inside the function,
    # to avoid a common Flask circular reference error
    from app import db
    from app.database import run_sql_query
    from app.forms import LoginForm, RegistrationForm
    from app.models import User

    @app.route("/")
    def home():
        """Super-simple non-Dash route,
        to demonstrate that Flask can be used normally"""
        return render_template("index.html")

    @app.route("/healthcheck/")
    def healthcheck():
        """Check that the app is up and running,
        for Docker Swarm zero-downtime deployment.
        This endpoint is monitored by UptimeRobot, a free monitoring service"""

        run_sql_query("select ticker from public.stock_prices limit 1")

        return "The app and database are working fine"

    @app.route("/register/", methods=["GET", "POST"])
    def register():
        """View for new user registration"""

        form = RegistrationForm()

        if request.method == "POST":
            # Convert the submitted email address to lowercase first
            email_lower = form.email.data.lower()

            # Check if there is already a user with that email address
            user = User.query.filter_by(email=email_lower).first()
            if user:
                flash("That email address is already registered")
                return render_template("register.html", form=form)

        # If the method is a POST request and the form validates,
        # register the new user
        if form.validate_on_submit():
            user = User(
                email=email_lower,
                password=form.password.data,
                first_name=form.first_name.data,
                last_name=form.last_name.data,
            )

            # Add the new user to the database
            db.session.add(user)
            db.session.commit()
            flash("You have successfully registered! You may now login.")
            return redirect(url_for("login"))

        return render_template("register.html", form=form)

    @app.route("/login/", methods=["GET", "POST"])
    def login():
        """View for user login"""

        if current_user.is_authenticated:
            # If the user is already authenticated
            _redirect()

        form = LoginForm()
        if form.validate_on_submit():
            # Check whether the password entered matches the password in the database
            user = User.query.filter_by(email=form.email.data.lower()).first()
            if user.verify_password(form.password.data):
                # Save some details about this login, and previous logins
                user.last_login_at = datetime.datetime.utcnow()
                user.login_count = (
                    1 if user.login_count is None else user.login_count + 1
                )
                db.session.commit()

                # Log user in
                remember_me = form.remember_me.data
                remember_me_for = datetime.timedelta(days=1)
                login_user(user, remember=remember_me, duration=remember_me_for)

                # redirect to the appropriate dashboard page
                return _redirect()

            else:
                # When login details are incorrect
                flash("Invalid email or password")

        return render_template("login.html", form=form)

    @app.route("/logout/")
    @login_required
    def logout():
        """This is what happens when the user logs out"""

        logout_user()
        return redirect(url_for("home"))
```

First things first, head back to your `__init__.py` file and uncomment the following lines referring to the `register_views` function:

```python
from app.views import register_views

...

    # Register the Flask homepage, login, register, and logout views
    register_views(app)
```

Now, back to the actual `register_views` function in the `views.py` module. First, the imports from the `__init__.py` file, which is in the `app` folder. Note we import our forms and `User` model inside the `register_views` function, to avoid a common Flask circular reference error, where one file tries to import from the other, and the other file tries to import from the first file, etc. This is normal with Flask. Just do it. :)

```python
def register_views(app):
    """Register all views with the Flask app"""

    # Import our forms and User model inside the function,
    # to avoid a common Flask circular reference error
    from app import db
    from app.database import run_sql_query
    from app.forms import LoginForm, RegistrationForm
    from app.models import User
```

The first "view" inside the `register_views` function is the main homepage view. If your domain name were "[myijack.com](https://myijack.com)", for instance, this is the first page you'd see. Again, really standard Flask stuff here.

```python
    @app.route("/")
    def home():
        """Super-simple non-Dash route,
        to demonstrate that Flask can be used normally"""
        return render_template("index.html")
```

What's that `index.html` page though? That's actually the only non-Python, non-SQL code in this course. It's a simple HTML template, which is read by the browser and displayed to the user. I'll cover our three simple HTML templates in the next chapter. But first, let's inspect the other views besides the `home()` view.

The second view is simply a website "health-check" for monitoring whether the site is up. Docker Swarm makes use of this, and I'd also highly recommend setting up a free website monitoring service at [UptimeRobot](https://uptimerobot.com/). It's free and it takes about 1 minute to setup.

Anyway, the healthcheck route would be at `https://yourdomain.com/healthcheck` and all it does is verify: 1) that the site is up; and 2) that the database is working. If so, it returns only the text "The app and database are working fine".

```python
    @app.route("/healthcheck/")
    def healthcheck():
        """Check that the app is up and running,
        for Docker Swarm zero-downtime deployment.
        This endpoint is monitored by UptimeRobot, a free monitoring service"""

        run_sql_query("select ticker from public.stock_prices limit 1")

        return "The app and database are working fine"
```

Below the health-check view comes the "registration" view. It uses the `RegistrationForm` we created in `forms.py`. 

The `validate_on_submit()` method of the form checks whether it's a 'POST', 'PUT', 'PATCH', or 'DELETE' request (i.e. form data is being sent to the server), as opposed to a 'GET' request, which seeks only to download the web page, without sending a form to the server. If it's not a 'GET' request, it them validates each field in the form. If both checks pass, a new `User` model is created and added to the database, using the form data for each database field.

Finally, a "You have successfully registered!" message is flashed to the screen, and the user is redirected to the "login" view next.

After submitting a form, it is best practice to redirect the user to a different page, so that the form never tries to get submitted again.

```python
    @app.route("/register/", methods=["GET", "POST"])
    def register():
        """View for new user registration"""

        # If the method is a POST request and the form validates,
        # register the new user
        form = RegistrationForm()
        if form.validate_on_submit():
            # Convert the submitted email address to lowercase first
            email_lower = form.email.data.lower()

            user = User(
                email=email_lower,
                password=form.password.data,
                first_name=form.first_name.data,
                last_name=form.last_name.data,
            )

            # Add the new user to the database
            db.session.add(user)
            db.session.commit()
            flash("You have successfully registered! You may now login.")
            return redirect(url_for("login"))

        return render_template("register.html", form=form)
```

The `login` view is next, and it's similar to the `register` view. I'm including a little `_redirect()` function, which redirects the user, either to the page the user initially requested, before being asked to login, or to the default `/dash/` view, which we haven't created yet. Have a look and I'll explain a bit more below.

```python
def _redirect():
    """Finds where to redirect the user"""

    next_url = request.args.get("next")
    if next_url:
        return redirect(next_url)

    return redirect("/dash/")

...

    @app.route("/login/", methods=["GET", "POST"])
    def login():
        """View for user login"""

        if current_user.is_authenticated:
            # If the user is already authenticated
            _redirect()

        form = LoginForm()
        if form.validate_on_submit():
            # Check whether the password entered matches the password in the database
            user = User.query.filter_by(email=form.email.data.lower()).first()
            if user.verify_password(form.password.data):
                # Save some details about this login, and previous logins
                user.last_login_at = datetime.datetime.utcnow()
                user.login_count = (
                    1 if user.login_count is None else user.login_count + 1
                )
                db.session.commit()

                # Log user in
                remember_me = form.remember_me.data
                remember_me_for = datetime.timedelta(days=1)
                login_user(user, remember=remember_me, duration=remember_me_for)

                # redirect to the appropriate dashboard page
                return _redirect()

            else:
                # When login details are incorrect
                flash("Invalid email or password")

        return render_template("login.html", form=form)
```

First, we check if the user is already authenticated, using the `current_user.is_authenticated` property from the Flask-Login package. If the user is already logged, there's no need to show the login page, so redirect the user elsewhere:
```python
        if current_user.is_authenticated:
            # If the user is already authenticated
            _redirect()
```

Next, we grab the `LoginForm` that we imported from the `forms.py` module, and do the same `form.validate_on_submit()` check to see if the user has filled out the form already, or if the login page has been requested with a simple "GET" request.

Next, of course, we verify the user's password using the `verify_password` method of the `User` database model instance. If the password is correct, we update the `last_login_at` and `login_count` fields, and commit them to the `public.users` table in the database. 

Finally, we check whether the user wants us to "remember" her, set the duration for one day, log her in, and redirect her where she wants to go. 

If password verification failed, we simply flash a "Invalid email or password" message, and reload the login page.

This chapter is getting a little long, so please see the next chapter for an explanation of the HTML templates to which we referred in the `return render_template("login.html", form=form)` line.


{% include end_to_end_ml_table_of_contents.html %}
