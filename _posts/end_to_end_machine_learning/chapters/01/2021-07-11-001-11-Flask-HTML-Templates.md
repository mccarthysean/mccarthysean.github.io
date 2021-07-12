---
layout: post
title: Flask HTML Templates
# slug: flask-html-templates
chapter: 11
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


In the previous chapter, we built the "views", or the business logic behind user registration and login. This chapter will build the HTML templates that actually present the registration and login forms to the user.

HTML templates are usually put in a folder called `templates`, inside the `app` folder, so please create the `templates` folder now. Flask will expect to see it there. I'll show you the HTML for each template file below

Inside the `templates` folder, please add three HTML files:

1. index.html
2. register.html
3. login.html

First, the `index.html` file (dead-simple HTML here), which just has a "Heading1" or `<h1>` tag with a link to our soon-to-be-created `/dash/` app:

```html
<html>
    <body>
        <h1 style="text-align: center; margin-top: 2rem;">
            Click <a href="/dash/">here</a> to see the Dash single-page application (SPA)
        </h1>
    </body>
</html>
```

Next, paste the following into the `register.html` file, which is a bit more complex. I'll explain below:

{% raw %}
```html
{% extends "bootstrap/base.html" %}

{% import "bootstrap/utils.html" as utils %}
{% import "bootstrap/wtf.html" as wtf %}

{% block title %}Register{% endblock %}

{% block content %}
<div class="container">
  <div class="row justify-content-center">
    <div class="col-md-6 col-lg-4">
      <h1 style="margin-top: 2rem;">Register</h1>
      {{ utils.flashed_messages() }}
      {{ wtf.quick_form(form) }}
      <br>
      <p>Have an account already? <a href="{{ url_for('login') }}">Login</a></p>
    </div>
  </div>
</div>
{% endblock %}
```
{% endraw %}

We use a lot of helpers in the `register.html` file above. First, it builds off of, or "extends" the `bootstrap/base.html` file, which comes from the Flask-Bootstrap4 package we installed a while back. This ensures the Bootstrap 4 CSS and JavaScript files are downloaded. Super-helpful, simplifying, and time-saving. I'm trying hard to avoid front-end development and design stuff. Bootstrap was made for data scientists like us, who'd rather spend time on the model, not the design details of the website, although we know it's super-important to look good doing it. But I digress...

Next, using Jinja2 syntax, we import the Bootstrap utils and wtf helpers, to design the form for us!

{% raw %}
```html
{% import "bootstrap/utils.html" as utils %}
{% import "bootstrap/wtf.html" as wtf %}
```
{% endraw %}

Then we quickly set the page title in the HTML `head` metadata:
{% raw %}
```html
{% block title %}Register{% endblock %}
```
{% endraw %}

Finally, the meat and potatoes of the user registration page. The outer `<div class="container"` is a [Bootstrap grid](https://getbootstrap.com/docs/4.0/layout/grid/) thing. Bootstrap containers usually "contain" rows, and rows contain up to 12 columns (the screen width is divided into 12 convenient chunks).

The `utils.flashed_messages()` is a convenient place to flash messages such as "wrong password you dummy try again". 

But the most convenient, **and most important**, bit of all is the `wtf.quick_form(form)` which creates an HTML form, from the `form` argument in the view. We'll get to that very soon, right after the `login.html` file, which is very similar to the `register.html` file we just created.

{% raw %}
```html
{% block content %}
<div class="container">
  <div class="row justify-content-center">
    <div class="col-md-6 col-lg-4">
      <h1 style="margin-top: 2rem;">Register</h1>
      {{ utils.flashed_messages() }}
      {{ wtf.quick_form(form) }}
      <br>
      <p>Have an account already? <a href="{{ url_for('login') }}">Login</a></p>
    </div>
  </div>
</div>
{% endblock %}
```
{% endraw %}

Now, here's the `login.html` file I promised. Look familiar? The only extra line I added was a `Need an account?` link to the registration page we just created. Note the {% raw %}`{{ url_for('register') }}`{% endraw %} which is Flask's `url_for` function inside of the Jinja2 syntax braces (i.e. {% raw %}`{{ }}`{% endraw %}). Note, the 'register' points to the actual view function called `register()` in `views.py`.

{% raw %}
```html
{% extends "bootstrap/base.html" %}

{% import "bootstrap/utils.html" as utils %}
{% import "bootstrap/wtf.html" as wtf %}

{% block title %}Login{% endblock %}

{% block content %}
<div class="container">
  <div class="row justify-content-center">
    <div class="col-md-6 col-lg-4">
      <h1 style="margin-top: 2rem;">Login</h1>
      {{ utils.flashed_messages() }}
      {{ wtf.quick_form(form) }}
      <br>
      <p>Need an account? <a href="{{ url_for('register') }}">Register</a></p>
    </div>
  </div>
</div>
{% endblock %}
```
{% endraw %}

That's it for HTML templates, and that's it for Flask, for now. In Part 2, we move on to Dash to create our single-page application for our machine learning model.
