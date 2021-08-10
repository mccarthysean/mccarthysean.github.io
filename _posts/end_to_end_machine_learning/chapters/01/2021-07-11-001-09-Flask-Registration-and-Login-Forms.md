---
layout: post
title: Flask Registration and Login Forms
# slug: flask-registration-and-login-forms
chapter: 9
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


We just finished creating the `User` model in the `models.py` file. Next, let's create a `forms.py` file right beside it, to handle the registration and login forms the users will be filling out.

Here's everything you'll need in the `forms.py` file. I'll explain everything below.

```python
# forms.py

from flask_wtf import FlaskForm
from wtforms import (
    BooleanField,
    IntegerField,
    PasswordField,
    SelectField,
    SelectMultipleField,
    StringField,
    SubmitField,
    ValidationError,
)
from wtforms.validators import DataRequired, Email, EqualTo

from app.models import User


class RegistrationForm(FlaskForm):
    """User registration form for new accounts"""

    email = StringField("Email", validators=[DataRequired(), Email()])

    password = PasswordField(
        "Password", validators=[DataRequired(), EqualTo("confirm_password")]
    )
    confirm_password = PasswordField("Confirm Password")

    first_name = StringField("First Name", validators=[DataRequired()])
    last_name = StringField("Last Name", validators=[DataRequired()])

    submit = SubmitField("Register")

    def validate_email(self, field):
        if User.query.filter_by(email=field.data).first():
            raise ValidationError("Email is already in use.")


class LoginForm(FlaskForm):
    """Form for users to login"""

    email = StringField("Email", validators=[DataRequired(), Email()])
    password = PasswordField("Password", validators=[DataRequired()])
    remember_me = BooleanField("Remember Me", default=False)
    submit = SubmitField("Login")

```

First note we import the `User` database model from our `models.py` file with `from app.models import User`.

In the `RegistrationForm` class, which inherits from the `FlaskForm` class, we create some form fields, just like in the `models.py` file where we created some database table fields. Let's take it slow and start with the email field:
```python
    email = StringField("Email", validators=[DataRequired(), Email()])
```

The `email` field is an instance of the `StringField` class from the `wtforms` package. Its label is simply "Email", but what are those `validators`? As you probably guessed, they ensure the user types in the right sort of thing. For example, as an email address, it'll have to have an "@" in the middle. Also, the `DataRequired()` denotes it's a required field and can't be left blank. The validators are built-in, and imported with this line:
```python
from wtforms.validators import DataRequired, Email, EqualTo
```

The `password` field has a neat validator: `EqualTo`, which ensures it's the same as the `confirm_password` field below it. `first_name` and `last_name` are also required, and then there's the `SubmitField`, whose label is `Register`. This will be a "Register" button at the bottom of the form. 

The `validate_email` method is actually quite special, and sneaky. As [Miguel Grinberg](https://blog.miguelgrinberg.com/) explained in his excellent "Flask Mega-Tutorial" [here](https://blog.miguelgrinberg.com/post/the-flask-mega-tutorial-part-v-user-logins/page/5):

When you add any methods that match the pattern validate_<field_name>, WTForms takes those as custom validators and invokes them in addition to the stock validators. In this case I want to make sure that the username and email address entered by the user are not already in the database, so these two methods issue database queries expecting there will be no results. In the event a result exists, a validation error is triggered by raising ValidationError. 

Finally, the `LoginForm` is pretty self-explanatory, I would think. This is the form the user submits to login to the website. I've included a `remember_me` checkbox `BooleanField` so the user doesn't have to login as often.

```python

class LoginForm(FlaskForm):
    """Form for users to login"""

    email = StringField("Email", validators=[DataRequired(), Email()])
    password = PasswordField("Password", validators=[DataRequired()])
    remember_me = BooleanField("Remember Me", default=False)
    submit = SubmitField("Login")
```

That's it for Flask forms. In the next chapter, we'll create the business logic for the "views" (i.e. the actual login and registration web pages).

Next: [Flask Registration and Login Views]({% post_url 2021-07-11-001-10-Flask-Registration-and-Login-Views %})

{% include end_to_end_ml_table_of_contents.html %}
