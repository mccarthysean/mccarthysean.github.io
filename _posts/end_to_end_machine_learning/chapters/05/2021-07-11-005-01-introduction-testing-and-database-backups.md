---
layout: post
title: Introduction - Testing and Database Backups
# slug: introduction-testing-and-database-backups
chapter: 1
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


Part 5 focuses on quality control, which is split up into two parts. 

First is unit testing. We'll test the Flask website, and then we'll test the Dash single page application with Selenium webdriver.

Second is database backups. This topic is not discussed as much as it should be, but if a problem arises with your server, your server's storage volumes, or your database itself, it could become very important very quickly. The problem of backups can be mitigated significantly by using a cloud-managed database, such as AWS RDS (Relational Database Service), but there are fewer options for TimescaleDB and they tend to be fairly expensive, so we'll perform our own backups automatically and store them in an AWS S3 bucket.

# Learning Objectives
By the end of Part 5, you will be able to:
1. Write unit tests for a Flask app
2. Write front-end integration tests for a Dash app
3. Automatically backup your TimescaleDB database to an AWS S3 bucket

Next: <a href="005-02-Flask-Testing">Flask Testing</a>

{% include end_to_end_ml_table_of_contents.html %}
