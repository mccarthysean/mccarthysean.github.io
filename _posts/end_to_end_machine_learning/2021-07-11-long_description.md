---
layout: post
title: End to End Machine Learning Course
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
featured_image_thumbnail:
featured_image: assets/images/posts/2021/kevin-ku-w7ZyuGYNpRQ-unsplash.jpg
featured: True
hidden: true
---

<p><em>Learn how to build, test, and deploy a stock price forecasting machine learning model, using Flask, Dash, TimescaleDB, Docker Swarm, and Traefik.</em></p>

## Objective

In this course, you'll learn how to build a stock price forecasting, machine learning web application. End users will be able to choose between a number of different machine learning models, and various explanatory variables (features), to see how much money could be made trading in and out of a certain stock. Users will be able pick any stock ticker, and the machine learning model will train itself to the historical data, and then test its model on new, unseen data in the *test period*.

This course is geared toward those who want to learn machine learning, stock price forecasting, and full-stack web development at the same time. In the data science world, a *unicorn* is someone who has all three of the following skills and experience:

1. Data science and machine learning skills
1. Software development skills
1. Domain or industry expertise

After completing this course, you'll have experience building an end-to-end machine learning pipeline, as well as the software development know-how to publish your model as a web app. And perhaps you'll even try to make some money in the financial markets as well, although -- fair warning -- this course is more about machine learning and web development. The stock price forecasting bit is mostly for fun. Finance and economics is a fascinating, challenging, and rewarding field, but know that trying to make money in the stock market is a risky, difficult business. As a Chartered Financial Analyst (CFA Charterholder) with a master's degree in business administration (MBA), I'm obligated to inform you that a lot of smart people -- and their algorithms -- are competing to make money in the financial markets. To use some cliches, "there's no free lunch", and "if it were easy, everyone would do it".

You will learn quite a few things in this course that you simply can't find anywhere else on the web:

1. Combining Flask and Dash apps with user registration, requiring users to log in to see the Dash machine learning app
1. Testing a Dash app with Selenium, including logging in first
1. Automatically backing up a TimescaleDB database to an AWS S3 bucket
1. Deploying a Flask/Dash app with Traefik and Docker Swarm for automatic TLS/HTTPS with zero-downtime deployment

## Tools and Technologies

1. Python
1. Flask
1. Dash
1. Scikit-Learn, Pandas, and NumPy
1. Docker, Docker Compose, and Docker Swarm
1. TimescaleDB
1. Traefik
1. Amazon Web Services (AWS)

## Prerequisites

This is not a beginner course. It's designed for the advanced-beginner -- someone with at least six months of web development experience. Before beginning, you should have some familiarity with the following topics. Refer to these resources for more info:

| Topic            | Resource |
|------------------|----------|
| Docker           | [Get started with Docker](https://docs.docker.com/engine/getstarted/) |
| Docker Compose   | [Get started with Docker Compose](https://docs.docker.com/compose/gettingstarted/) |
| Flask            | [Flaskr TDD](https://github.com/mjhea0/flaskr-tdd), [Developing Web Applications with Python and Flask](/courses/learn-flask/) |

## How long does it take to complete?

Chapters can take anywhere from a few hours to an entire day. The Dash and machine learning chapters will probably be the most challenging to understand.

{% include end_to_end_ml_table_of_contents.md %}
