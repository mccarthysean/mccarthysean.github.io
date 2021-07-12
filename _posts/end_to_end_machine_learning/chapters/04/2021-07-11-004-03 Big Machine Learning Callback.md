---
layout: post
title: Big Machine Learning Callback
# slug: big-machine-learning-callback
chapter: 3
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


In the previous chapter, we finished our Dash app's layout, which included a lot of inputs for our machine learning model. Now we're going to create the big callback function to deal with those inputs, train the ML model, and output a few charts back to the layout. 

Some people break down a website into three parts called the MVC Framework:
1. Model (database models or classes)
2. View (the layout)
3. Controller (the business logic)

FYI, we're on the "controller" step now, after completing the view and model steps previously. 

### Building the Dash Callback Function

Let's build up the big callback step by step below. First, notice there are two `Input`s that trigger the callback:
1. The "Train Model" button (`n_clicks` property)
2. The stock ticker dropdown menu `value` property

There are also six `State` elements whose values are available to the function, but which don't *trigger* the function to run. We don't want the model re-training itself every time someone selects an explanatory feature, for example. We can wait until they've selected all the inputs they want, and click the "Train Model" button (or select a different stock ticker).

Finally, notice there are four different `Output`s we're going to build:
1. A message
2. The machine learning buy/sell signals chart
3. The cumulative profits chart
4. The message below the cumulative profits chart

```python

    @dash_app.callback(
        [
            Output("model_trained_msg", "children"),
            Output("ml_chart_div", "children"),
            Output("profits_chart_div", "children"),
            Output("profits_chart_msg_div", "children"),
        ],
        [
            Input("train_ml_btn", "n_clicks"),
            Input("tickers_dropdown", "value")
        ],
        [
            State("ml_models_radio", "value"),
            State("ml_cross_validation_splits", "value"),
            State("ml_features_to_use", "value"),
            State("ml_do_hyper_param_tuning", "value"),
            State("train_test_date_picker", "date"),
            State("ml_strategy", "value"),
        ],
    )
    def train_machine_learning_model(
        train_ml_btn_clicks,
        ticker,
        ml_model,
        n_splits,
        features,
        hyper_tune,
        date_test,
        strategy,
    ):
        """Get the stocks available, based on the industry chosen"""

        if (
            ticker is None
            or ml_model is None
            or n_splits is None
            or features is None
            or hyper_tune is None
            or date_test is None
            or strategy is None
        ):
            raise PreventUpdate

        # This callback might take a while. Let's time it,
        # and display the elapsed time on the website
        time_start = time.time()
```

Below the `time_start` timer in the big callback, add the following functions for grabbing the data from the database, and doing the feature engineering:

```python
        # Get stock price data from TimescaleDB database
        df = get_stock_price_data_from_db(ticker)

        # Create machine learning features (explanatory variables)
        df = feature_engineering(df)
```

You've already got the `get_stock_price_data_from_db` function in the `dashapp.utils.py` module.

Uncomment all the imports at the top of the `callbacks.py` module, since we're going to completely finish the model in this chapter. They should look like the following:

```python
from app.dashapp.ml import feature_engineering, grid_search_cross_validate, train_models
from app.dashapp.utils import (
    download_prices,
    get_chart,
    get_stock_industries,
    get_stock_price_data_from_db,
    get_stock_tickers,
    get_time_series_chart,
    insert_tickers,
    make_annotations,
    ml_models_map,
    upload_to_aws_efficiently,
)
from app.database import get_conn, run_sql_query
```

Create the `ml.py` module in the /dashapp folder, and add the following imports

```python
# /app/dashapp/ml.py

import time

import numpy as np
import pandas as pd
from flask import current_app
from sklearn.ensemble import AdaBoostClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression, RidgeClassifier
from sklearn.model_selection import GridSearchCV, TimeSeriesSplit
from sklearn.neighbors import KNeighborsClassifier
from sklearn.neural_network import MLPClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC
```

Now add the `feature_engineering` function, which adds all the columns we need to the Pandas DataFrame. You'll recognize all this from the previous part on machine learning in Jupyter, where we added all the technical indicators as explanatory features:

```python
def feature_engineering(df):
    """Prepare the DataFrame for machine learning"""

    # Convert the numeric columns to numeric 'float64'
    df["price"] = pd.to_numeric(df["price"])
    df["high"] = pd.to_numeric(df["high"])
    df["low"] = pd.to_numeric(df["low"])
    df["volume"] = pd.to_numeric(df["volume"])

    # Feature Engineering
    # Create a new column with the price from the previous time period,
    # and back-fill the value so we don't have any null values
    df["price_prev"] = df["price"].shift(1).bfill()
    # Calculate the day-over-day price change
    df["delta"] = df["price"] - df["price_prev"]
    # Get tomorrow's price delta, which is how we'll calculate our profits
    df["delta_tm"] = df["delta"].shift(-1)
    # Calculate the percentage change in price, or the return
    df["rt"] = df["delta"] / df["price_prev"]
    # Get the lagged returns for more previous days, since there's autocorrelation
    df["rt1"] = df["rt"].shift(1)
    df["rt2"] = df["rt"].shift(2)
    df["rt3"] = df["rt"].shift(3)
    df["rt4"] = df["rt"].shift(4)
    df["rt5"] = df["rt"].shift(5)
    # Get the next day's return, which is ultimately what we're trying to forecast/predict
    df["rt_tm"] = df["rt"].shift(-1)
    # Make a simpler up/down indicator, for whether the return is positive or negative
    df["up_down_tm"] = np.where(df["rt_tm"] > 0, 1, 0)
    # Make an up-down indicator for the returns over the next week
    df["price_1wk"] = df["price"].shift(-7)
    df["up_down_1wk"] = np.where(df["price_1wk"] > df["price"], 1, 0)

    # Calculate the moving average convergence-divergence (MACD) technical indicator
    macd_12 = df["price"].ewm(span=12, adjust=False).mean()
    macd_26 = df["price"].ewm(span=26, adjust=False).mean()
    df["macd"] = macd_12 - macd_26
    df["macd_signal"] = df["macd"].ewm(span=9, adjust=False).mean()
    df["macd_delta"] = df["macd"] - df["macd_signal"]
    df["macd_change_dod"] = df["macd_delta"] - df["macd_delta"].shift(1)
    df["macd_binary"] = np.where(df["macd"] > df["macd_signal"], 1, 0)

    # Calculate the 14-day relative strength index (RSI) technical indicator
    # Window length for RSI moving average
    window_length = 14
    # Calculate the days where the price went up, otherwise zero
    up = pd.Series(np.where(df["delta"] > 0, df["delta"], 0))
    # Calculate the days where the price went down, otherwise zero
    down = pd.Series(np.where(df["delta"] < 0, df["delta"], 0))
    roll_up = up.rolling(window=window_length, min_periods=1).mean()
    roll_down = down.abs().rolling(window=window_length, min_periods=1).mean()
    df["RSI"] = 100.0 - (100.0 / (1.0 + (roll_up / roll_down)))

    # Calculate the 3-day commodity channel index (CCI) technical indicator
    df["CCI"] = (df["price"] - df["price"].rolling(3, min_periods=1).mean()) / (
        0.015 * df["price"].rolling(3, min_periods=1).std()
    )

    # Calculate the ease of movement (EVM) volume-based technical oscillator
    distance_moved = (df["high"] + df["low"]) / 2 - (
        df["high"].shift(1).bfill() + df["low"].shift(1).bfill()
    ) / 2
    box_ratio = (df["volume"] / 100_000_000) / (df["high"] - df["low"])
    df["EMV"] = distance_moved / box_ratio

    # Calculate the "force index" technical oscillator,
    # a measure of the "forcefullness" of the price change
    df["FI"] = df["delta"] * df["volume"]

    # Replace any infinite values with nulls (np.nan), and then drop all null/NA values
    current_app.logger.info(f"df.shape before removing bad values: {df.shape}")
    df = df.replace([np.inf, -np.inf], np.nan)
    df = df.dropna()
    current_app.logger.info(f"df.shape after removing bad values: {df.shape}")

    return df
```

Back in `callbacks.py`, let's split the Pandas DataFrame into train/test splits so we can train on data before a certain user-defined date (from the callback function inputs), and test on data after that date.

```python
        # Make train/test splits, so we can test on data that's never been seen before
        df_train = df[df["time"] < date_test].copy()
        current_app.logger.info(f"df_train.shape: {df_train.shape}")
```

Next in `callbacks.py`, isolate the explanatory variables from the target variable we're trying to predict

```python
        # Isolate the "features" or "explanatory variables" from
        # the value we're trying to predict (tomorrow's returns)
        if "rt" in features:
            # Add the other lagged returns
            features += ("rt1", "rt2", "rt3", "rt4", "rt5")
        X = df[features].values
        X_train = df_train[features].values

        # Isolate the value we're trying to predict
        # y_feature = 'up_down_tm'
        y_feature = "up_down_1wk"
        df[y_feature].values
        y_train = df_train[y_feature].values
```

Now we're ready to train the ML model, so add that function to `callbacks.py`.

```python
        # Train the machine learning model on the training data
        estimator, _ = train_models(
            X_train, y_train, n_splits, features, ml_model, hyper_tune
        )
```

Jump back to `dashapp/ml.py` and add the `train_models` function. Again, all this should be familiar from Part 3 on machine learning in Jupyter. We're basically just copying and pasting it into our web app now.

```python
def train_models(X, y, n_splits, features, ml_model, hyper_tune):
    """Run all models (this will take a little while!)"""

    # Scale the data between 0 and 1
    # mms = MinMaxScaler(feature_range=(0,1))
    ss = StandardScaler()

    # Time series split for cross-validation
    tscv = TimeSeriesSplit(n_splits=n_splits)

    # Classification machine learning models to test
    ml_pipe_ols = Pipeline([("scale", ss), ("ols", LogisticRegression())])
    ml_pipe_ridge = Pipeline([("scale", ss), ("ridge", RidgeClassifier())])
    ml_pipe_dtab = Pipeline([("scale", ss), ("dtab", AdaBoostClassifier())])
    ml_pipe_rf = Pipeline([("scale", ss), ("rf", RandomForestClassifier())])
    ml_pipe_sv = Pipeline([("scale", ss), ("sv", SVC())])
    ml_pipe_knn = Pipeline([("scale", ss), ("knn", KNeighborsClassifier())])
    ml_pipe_mlp = Pipeline([("scale", ss), ("mlp", MLPClassifier())])

    # Classification hyper-parameter tuning grids
    param_grid_ols = [{"ols__fit_intercept": [True, False]}]
    param_grid_ridge = [
        {"ridge__alpha": [0, 0.001, 0.1, 1.0, 5, 10, 50, 100, 1000, 10000, 100000]}
    ]
    param_grid_dtab = [
        {
            "dtab__n_estimators": [50, 100],
            "dtab__learning_rate": [0.75, 1.0, 1.5],
        }
    ]
    param_grid_rf = [
        {
            "rf__n_estimators": [100, 200],
            "rf__max_features": ["auto", "sqrt", "log2"],
            "rf__max_depth": [2, 4, 8],
        }
    ]
    param_grid_mlp = [
        {
            "mlp__activation": ["relu", "tanh"],
            "mlp__solver": ["adam", "sgd"],
            "mlp__alpha": [0.1, 1, 10],
        }
    ]
    param_grid_sv = [
        {
            "sv__kernel": ["rbf", "linear"],
            "sv__C": [0.01, 0.1, 1, 10],
            "sv__gamma": [0.01, 0.1, 1],
        }
    ]
    param_grid_knn = [
        {
            "knn__n_neighbors": [8, 12, 16],
            "knn__weights": ["uniform", "distance"],
            "knn__p": [1, 2],
            "knn__n_jobs": [1, -1],
        }
    ]

    # Train the machine learning model
    estimator, df_grid_search_results = None, None
    if ml_model == "ols":
        estimator, df_grid_search_results = grid_search_cross_validate(
            X, y, "ols", ml_pipe_ols, param_grid_ols, cv=tscv, hyper_tune=hyper_tune
        )
    elif ml_model == "ridge":
        estimator, df_grid_search_results = grid_search_cross_validate(
            X,
            y,
            "ridge",
            ml_pipe_ridge,
            param_grid_ridge,
            cv=tscv,
            hyper_tune=hyper_tune,
        )
    elif ml_model == "knn":
        estimator, df_grid_search_results = grid_search_cross_validate(
            X, y, "knn", ml_pipe_knn, param_grid_knn, cv=tscv, hyper_tune=hyper_tune
        )
    elif ml_model == "dtab":
        estimator, df_grid_search_results = grid_search_cross_validate(
            X, y, "dtab", ml_pipe_dtab, param_grid_dtab, cv=tscv, hyper_tune=hyper_tune
        )
    elif ml_model == "rf":
        estimator, df_grid_search_results = grid_search_cross_validate(
            X, y, "rf", ml_pipe_rf, param_grid_rf, cv=tscv, hyper_tune=hyper_tune
        )
    elif ml_model == "sv":
        estimator, df_grid_search_results = grid_search_cross_validate(
            X, y, "sv", ml_pipe_sv, param_grid_sv, cv=tscv, hyper_tune=hyper_tune
        )
    elif ml_model == "mlp":
        estimator, df_grid_search_results = grid_search_cross_validate(
            X, y, "mlp", ml_pipe_mlp, param_grid_mlp, cv=tscv, hyper_tune=hyper_tune
        )

    return estimator, df_grid_search_results
```

The previous `train_models` function depends on another function called `grid_search_cross_validate`, so add that to our `ml.py` module as well. This is the last function in `ml.py`!

```python
def grid_search_cross_validate(
    X,
    y,
    name,
    estimator,
    param_grid,
    scoring="accuracy",
    cv=4,
    return_train_score=True,
    hyper_tune=True,
):
    """Perform grid-search hyper-parameter tuning and
    train/test cross-validation to prevent overfitting"""

    time_start = time.time()
    df = pd.DataFrame()
    if hyper_tune:
        estimator = GridSearchCV(
            estimator=estimator,
            param_grid=param_grid,
            scoring=scoring,
            cv=cv,
            return_train_score=return_train_score,
        )
        estimator.fit(X, y)
        df = pd.DataFrame(estimator.cv_results_)
        df["estimator"] = name
    else:
        # gs = GridSearchCV(estimator=estimator, param_grid=param_grid,
        #     scoring=scoring, cv=cv, return_train_score=return_train_score)
        estimator.fit(X, y)

    seconds_elapsed = time.time() - time_start
    current_app.logger.info(f"{name} took {round(seconds_elapsed)} seconds")

    return estimator, df
```

Back in `callbacks.py`, add the following to the big `train_machine_learning_model` callback. 

First, it uses the newly-trained `estimator` to predict all y-values, based on the `X` features chosen.

Next, it decides what our stock "position" should be (either 100 shares "long", 0 shares "flat", or -100 shares "short"). In finance lingo, "long" means you own the shares and you'll profit if the price goes up. "Short" means you've short-sold the shares and you'll profit if the price goes down. 

```python
        # Add predictions to DataFrame, so we can chart them
        df["pred"] = estimator.predict(X)

        # If our prediction == 1, buy 100 shares.
        # Otherwise either short-sell 100 shares, or exit the position
        n_shares = 100
        if strategy == "lo":
            # Long-only strategy (no short-selling)
            df["position"] = np.where(df["pred"] == 1, n_shares, 0)
        else:
            # Allow short-selling
            df["position"] = np.where(df["pred"] == 1, n_shares, -n_shares)
```

Next, make buy and sell flags for our buy/sell indicators chart, based on the position. 

```python
        # Make buy and sell flags based on the position
        df["buy"] = np.where(
            (df["position"] == n_shares) & (df["position"].shift(1) != n_shares), 1, 0
        )
        df["sell"] = np.where(
            (df["position"] != n_shares) & (df["position"].shift(1) == n_shares), 1, 0
        )
```

The purpose of the previous buy/sell indicators was to chart them as annotations on a scatterplot line chart, so create the "traces" for the buy/sell chart:

```python
        traces_buy_sell = [go.Scatter(x=df["time"], y=df["price"], name="Price")]
```

Now create some buy-signal annotations for that chart:

```python
        # Buy signal annotations
        df2 = df.loc[df["buy"] == 1, ["time", "price"]]
        annotations = make_annotations(
            x=df2["time"],
            y=df2["price"],
            xref="x",
            yref="y",
            text="B",
            yanchor="top",
            color="black",
        )
```

The above referenced a `make_annotations` function, so add that to `dashapp/utils.py`:

```python
def make_annotations(x, y, xref, yref, text, yanchor, color):
    """Make a list of annotation dictionaries,
    for annotating the charts with buy/sell indicators"""

    return [
        dict(
            x=x,
            y=y,
            xref=xref,
            yref=yref,
            text=text,
            yanchor=yanchor,
            font=dict(color=color),
        )
        for x, y in zip(x, y)
    ]
```

Now use the same `make_annotations` function again in `callbacks.py` to make the sell-signal annotations and add them to the `annotations` list:

```python
        # Sell signal annotations
        df3 = df.loc[df["sell"] == 1, ["time", "price"]]
        sell_annotations = make_annotations(
            x=df3["time"],
            y=df3["price"],
            xref="x",
            yref="y",
            text="S",
            yanchor="bottom",
            color="red",
        )

        # Add the "sell" annotations to the "buy" annotations
        annotations += sell_annotations
```

Now it's time to create the buy/sell chart in `callbacks.py`, using the traces and annotations we just made.

```python
        # Title for the chart
        title = f"Buy/Sell Signals for {ticker}"

        # Get the buy/sell signals chart
        chart_buy_sell = get_chart(
            traces_buy_sell, title, annotations=annotations, date_test=date_test
        )
```

Now that we have the buy/sell signals chart complete, we move on to creating the second chart `Output`, which shows the cumulative profits from our strategy. Let's set about calculating those cumulative profits first using Pandas' helpful `cumsum()` method. We'll calculate the cumulative profits both before and after the train/test date the user specified.

```python
        # Our profit is the number of shares we bought today, times the change in price tomorrow
        df["profit"] = df["position"] * df["delta_tm"]
        df["profit_cumul_train"] = df.loc[df["time"] < date_test, "profit"].cumsum()
        df["profit_cumul_test"] = df.loc[df["time"] >= date_test, "profit"].cumsum()

        traces_profits = [
            go.Scatter(
                x=df["time"],
                y=df["profit_cumul_train"],
                name="Training-Period Profit on 100 Shares",
                line=dict(color="MediumSeaGreen"),
            ),
            go.Scatter(
                x=df["time"],
                y=df["profit_cumul_test"],
                name="Test-Period Profit on 100 Shares",
                line=dict(color="DodgerBlue"),
            ),
        ]

        # Title for the chart
        title = f"Cumulative Profit on 100 Shares of {ticker}"

        # Get the buy/sell signals chart
        chart_profits = get_chart(
            traces_profits, title, date_test=date_test, rangeslider=False
        )
```

Using the above cumulative profit calculations, we're now going to create a message to display below the second chart. Pandas' `iloc()` method grabs rows and columns from the DataFrame based on their order, rather than their values or names. We want the last value in each period, so we use -1 to slice the data.

```python
        # Make a message to display below the second chart, showing the final value of the portfolio
        ending_value_train = df.loc[df["time"] < date_test, "profit_cumul_train"].iloc[
            -1
        ]
        ending_value_test = df.loc[df["time"] >= date_test, "profit_cumul_test"].iloc[
            -1
        ]
```

Here's the message to display below the second chart, using the ending values we just calculated. We're almost finished now!

```python
        text_style_train = {"color": "black" if ending_value_train > 0 else "red"}
        text_style_test = {"color": "black" if ending_value_test > 0 else "red"}
        profits_chart_msg = html.Div(
            [
                html.P(
                    [
                        "Training Period Ending Value: ",
                        html.Span(f"{ending_value_train:,.0f}", style=text_style_train),
                    ]
                ),
                html.P(
                    [
                        "Testing Period Ending Value: ",
                        html.Span(f"{ending_value_test:,.0f}", style=text_style_test),
                    ]
                ),
            ],
            style={"text-align": "center"},
        )
```

Drumroll please... let's finish off the `callbacks.py` file by finishing the huge `train_machine_learning_model` callback:

```python
        # How long did this callback take?
        seconds_elapsed = round(time.time() - time_start, 1)

        # Message to display below the "Train Model" button
        ml_model_label = ml_models_map.get(ml_model, "").lower()
        msg = f"{ticker} {ml_model_label} model trained in {seconds_elapsed} seconds!"
        current_app.logger.info(msg)

        return msg, chart_buy_sell, chart_profits, profits_chart_msg
```

Believe it or not, that's it! Congratulations... we've finished our machine learning web app! Now we just have to do some testing and automated database backups, and then we can deploy it to a production server with Docker Swarm and Traefik!

Give yourself a pat on the back if you've made it this far. You've probably accomplished your main objectives for this course. However, if you want your web app to function properly all the time, you've got to write some tests for it. You should also know how to automatically backup your special TimescaleDB database (not many people in the world know how to do that, believe it or not). And deployment with Docker Swarm and Traefik is really useful as well, for scaling your web app across multiple Docker containers, on multiple servers if need be. Very cool stuff, so I'll see you in Part 5!


{% include end_to_end_ml_table_of_contents.html %}
