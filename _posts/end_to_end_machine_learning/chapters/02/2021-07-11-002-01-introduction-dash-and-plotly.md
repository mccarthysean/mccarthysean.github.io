---
layout: post
title: Introduction - Dash and Plotly
# slug: introduction-dash-and-plotly
chapter: 1
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


In Part 2, we're going to take our Flask web app to the next level, and integrate Dash--a data science Python library that allows us to make interactive, first-class React-JavaScript-based single-page-applications with zero JavaScript. It's almost too good to be true. I know very few data scientists who even understand JavaScript, let alone excel at it. 

Dash even creates the HTML templates and CSS in Python, so it's extremely comfortable for Python enthusiasts. If that weren't enough, there's even a [Dash Bootstrap Components](https://dash-bootstrap-components.opensource.faculty.ai/) library for incorporating stylish and mobile-friendly, mobile-first Bootstrap components.

But wait, there's more! Dash is also based on the beautiful [Plotly](https://plotly.com/) interactive data science charts. I've tried the [Matplotlib](https://matplotlib.org/), [Seaborn](https://seaborn.pydata.org/), and even [Bokeh](https://docs.bokeh.org/en/latest/index.html) charting packages for Python, and Plotly is by far the best, whether you're making standalone charts for a PowerPoint, or interactive animations for the web. 

Bottom line is: look no further, data scientist friends, Dash/Plotly for the win. Your coworkers are soon to be impressed.

First, we're going to build a Dash HTML layout using Dash Bootstrap Components, and then we're going to add "callbacks" for performing business logic when the user interacts with our front-end. Callbacks are really the fun part of web development, where each new interactive feature makes our app that much more useful to the end-user. 

# Learning Objectives
By the end of Part 2, you will be able to:
1. Create a Dash HTML layout with Dash Bootstrap Components for effortless mobile responsiveness
2. Create Dash callbacks to interact with the layout


{% include end_to_end_ml_table_of_contents.html %}
