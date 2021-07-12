---
layout: post
title: Chapter 1 - Introduction
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
featured: false
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}

The first part of this course focuses on using [Docker](https://www.docker.com/) to set up the specialized [TimescaleDB](https://www.timescale.com/) database, and [PGAdmin](https://www.pgadmin.org/) for managing it. TimescaleDB is a [PostgreSQL](https://www.postgresql.org/) extension, so it has ALL of the regular Postgres functionality *plus* some awesome features geared toward time series data.

We'll also set up a [Python](https://www.python.org/)-based [Flask](https://flask.palletsprojects.com/) web application as our base web app, in preparation for Part 2, where we'll add [Dash](https://dash.plotly.com/) to make it interactive and *[React](https://reactjs.org/)*ive.

## Learning Objectives

By the end of Part 1, you will be able to:

1. Set up a Docker network for Docker containers to communicate
1. Set up a TimescaleDB database with Docker
1. Set up PGAdmin for administering your TimescaleDB or PostgreSQL database
1. Explain what time series data is and how it differs from regular relational data
1. Set up a Python-based Flask web app, as the base for our Dash machine learning app
