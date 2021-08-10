---
layout: post
title: Introduction - Machine Learning in Jupyter
# slug: introduction-machine-learning-in-jupyter
chapter: 1
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


### Development Environment for Data Science
In this chapter, we'll spend some time in a Jupyter notebook, doing interactive Python for machine learning and data science. 

There's a lot of trial and error in data science, which doesn't lend itself to application-style Python programming, involving functions and classes. There's also a lot of data so it's memory-intensive, and one often has to load data from a database or CSV file. Unlike debugging a traditional "program", we don't want to repeat all of our expensive steps every time, so we have to go interactive, do stuff line-by-line, and over and over. It usually requires a different sort of integrated development environment (IDE). My favourites are [Spyder](https://www.spyder-ide.org/) and [Jupyter Notebooks](https://jupyter.org/).

Traditionally, Python-based data scientists would install the [Anaconda](https://www.anaconda.com/) or Miniconda Python distributions, and then install packages with `conda` instead of `pip` or `poetry`, and then use Spyder or Jupyter Notebooks directly as the IDE. This was because many scientific Python ([scipy](https://www.scipy.org/)) packages are highly optimized for speed, and written in C instead of pure Python. This used to cause problems for package managers. 

However, the Python data science community moves fast, and these days Anaconda doesn't seem quite as necessary. At least for this course, it's not. I'm going to be using an interactive Jupyter Notebook, but I'm actually going to be using it right inside VS Code. Pretty convenient. And all the C-based scientific Python packages (e.g. scikit-learn, Pandas, NumPy) can be installed with Poetry, so I'm avoiding Anaconda entirely.

What will we be using this fancy development environment for?

### Machine Learning Objective
The overall objective is to use historical stock prices to forecast future stock price movements--specifically, whether the model forecasts the stock to move up or down over the next week. 

If the model says the stock price is headed up, we'll buy 100 shares and hold them until the model says the stock is headed down, and then we'll either sell our shares, or sell them and then actually short-sell 100 shares to profit off prices declining (we'll leave that strategy up to the user).

I think you get the picture. Let's dive in.

# Learning Objectives
By the end of Part 3, you will be able to:
1. Set up a machine learning development environment for interactive data science
2. Download and visualize the data from a Pandas DataFrame table
3. Create explanatory variables called "features" (feature engineering)
4. Create several machine learning models to fit to the training data
5. Hyper-parameter tune each model to find the best-fitting parameters
6. Train the test the model on different sets of time series data, to guard against overfitting (cross-validation)

When you're finished Part 3, you'll have a first-class machine learning pipeline of steps that you can use on any machine learning project. An exciting prospect, in the fascinating, challenging, and rewarding field of data science.

# A Few Words of Caution Regarding Investing
Note that this course is more about the practice of data science, and the deployment of machine learning models to a first-class web app. Making money in the stock market is a very challenging endeavour, and if it were that easy, everyone would be doing it already. As a Chartered Financial Analyst with a master's degree in business administration, I understand this better than most.

In financial economics, there's a theory called the [efficient markets hypothesis](https://en.wikipedia.org/wiki/Efficient-market_hypothesis), which basically states that it should not be possible to make money off historical stock prices alone. That would be too easy, like finding $100 bills lying on the sidewalk. 

There's always a risk/reward tradeoff in finance. If one takes very little risk (e.g. investing in government bonds or GICs), one will get very little return. Millions of smart investors around the world are constantly searching the markets for the best risk/reward tradeoffs, so they're not always easy to find. 

Academics would advise most investors simply to buy diversified index funds (i.e. the whole market), including bonds and stocks, and buy a little bit each month or year (dollar-cost averaging), while minimizing investment fees (i.e. management expense ratio or MER, and trading fees). They note that even experienced fund managers can't consistently "beat the market" year after year, and even if they could, how would you be able to identify such fund managers in advance?

With all that said, let's dare to dream a little bit, and see what machine learning can do for us.

Next: <a href="003-02-Exploratory-Data-Analysis">Exploratory Data Analysis</a>

{% include end_to_end_ml_table_of_contents.html %}
