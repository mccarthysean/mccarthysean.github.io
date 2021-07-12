---
layout: post
title: Finish the Dash Layout
# slug: finish-the-dash-layout
chapter: 2
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


Let's dive right into taking our machine learning model and deploying it to our Dash web app.

Add the following layout function to `layout.py`. It's a new Bootstrap "row" containing three more Bootstrap "columns" for:
1. Choosing one ML model from the `RadioItems` list
2. Selecting several explanatory features on which to train the ML model
3. Choosing a) whether to hyper-parameter tune the model; and b) how many time series splits for cross-validation testing

```python
def get_ml_inputs_row():
    """Get the "machine learning inputs" row of the layout"""

    return dbc.Row(
        [
            dbc.Col(
                [
                    html.H4("Machine Learning Model", style={"margin-top": "1rem"}),
                    dbc.RadioItems(
                        id="ml_models_radio",
                        options=[
                            dict(label=value, value=key)
                            for key, value in ml_models_map.items()
                        ],
                        value="rf",
                    ),
                ],
                xs=12,
                sm=6,
                md=4,
            ),
            dbc.Col(
                [
                    html.H4(
                        "Explanatory Features to Use", style={"margin-top": "1rem"}
                    ),
                    dbc.Checklist(
                        id="ml_features_to_use",
                        options=[
                            dict(label=value, value=key)
                            for key, value in ml_features_map.items()
                        ],
                        # Just use all the available keys in the dictionary
                        value=list(ml_features_map.keys()),
                    ),
                ],
                xs=12,
                sm=6,
                md=4,
            ),
            dbc.Col(
                [
                    dbc.Row(
                        dbc.Col(
                            [
                                html.H4(
                                    "Do Hyper-Parameter Tuning",
                                    style={"margin-top": "1rem"},
                                ),
                                dbc.RadioItems(
                                    id="ml_do_hyper_param_tuning",
                                    options=[
                                        dict(
                                            label="Yes (takes longer, but better)",
                                            value=True,
                                        ),
                                        dict(label="No", value=False),
                                    ],
                                    value=False,
                                ),
                            ]
                        )
                    ),
                    dbc.Row(
                        dbc.Col(
                            [
                                html.H5(
                                    "Time Series Cross-Validation Splits",
                                    style={"margin-top": "2rem"},
                                ),
                                html.P("(more splits takes longer to train)"),
                                dcc.Dropdown(
                                    id="ml_cross_validation_splits",
                                    options=[
                                        dict(label="2", value=2),
                                        dict(label="3", value=3),
                                        dict(label="4", value=4),
                                        dict(label="5", value=5),
                                        dict(label="6", value=6),
                                        dict(label="7", value=7),
                                        dict(label="8", value=8),
                                    ],
                                    value=2,
                                ),
                            ]
                        )
                    ),
                ],
                xs=12,
                sm=6,
                md=4,
            ),
        ],
        style={"margin-top": "1em"},
    )
```

Uncomment a few imports from the top of `layout.py`:

```python
from app.dashapp.utils import (
    get_stock_industries,
    get_stock_tickers,
    get_time_series_chart,
    ml_features_map, # NEW
    ml_models_map, # NEW
)
```

Pop over to the `dashapp/utils.py` file and add those imports so we can lookup what the ML abbreviations mean:

```python
ml_models_map = dict(
    ols="Logistic Regression",
    ridge="Ridge Classifier",
    knn="K-Nearest Neighbors",
    dtab="AdaBoost Decision Tree",
    rf="Random Forest",
    sv="Support Vector Machine",
    mlp="Neural Network",
)

ml_features_map = dict(
    rt="Lagged Returns (6 days)",
    macd_binary="Moving Avg. Convergence Divergence (MACD)",
    macd_change_dod="MACD Change Day-Over-Day",
    RSI="Relative Strength Index (RSI)",
    CCI="Commodity Channel Index (CCI)",
    EMV="Ease of Movement (EMV)",
    FI="Force Index (FI)",
)
```

All of the above layout elements (i.e. radio buttons, checklist items, and dropdown menu), will all serve as inputs to the same large Dash callback function. But wait, there's more! Add a few more elements to our `layout.py` layout as well:

1. Purchase strategy (i.e. no short-selling, or short-selling allowed)
2. Test period start date (train on data before this date, and test on data after this date)
3. A button to click, to start the model training process

```python
def get_train_model_button_row(stock_ticker):
    """Get the row of the layout that contains the
    test start date picker and the "Train Model" button"""

    # The max_test_start_date is the most recent date,
    # after which the test period should start
    max_test_start_date = datetime.date.today() - datetime.timedelta(days=14)

    # Defaults to 365 days ago. In other words, the model will train on data
    # before this date, and test on data on or after this date
    default_test_start_date = datetime.date.today() - datetime.timedelta(days=365)

    return dbc.Row(
        [
            dbc.Col(
                [
                    html.H4(
                        "Strategy",
                        style={"margin-top": "1rem"},
                    ),
                    dbc.RadioItems(
                        id="ml_strategy",
                        options=[
                            dict(
                                label="Long-only (no short-selling)",
                                value="lo",
                            ),
                            dict(label="Long-short (long or short)", value="ls"),
                        ],
                        # Default is long-only
                        value="lo",
                    ),
                ],
                xs=12,
                sm=6,
                md=4,
            ),
            dbc.Col(
                [
                    html.H4(
                        "Test Period Start Date",
                        style={"margin-top": "1rem"},
                    ),
                    html.P("(train on data before this date)"),
                    dcc.DatePickerSingle(
                        id="train_test_date_picker",
                        date=default_test_start_date,
                        max_date_allowed=max_test_start_date,
                        initial_visible_month=default_test_start_date,
                    ),
                    # Button to start the machine learning training process
                    dbc.Button(
                        "Train Model", id="train_ml_btn", color="dark", className="ml-2"
                    ),
                    dbc.Spinner(
                        html.P(
                            id="model_trained_msg",
                            style={"line-height": "2"},
                        ),
                    ),
                ],
                xs=12,
                sm=6,
                md=4,
            ),
        ],
        style={"margin-top": "1rem"},
    )
```

Our `layout.py` Dash layout is almost finished now. Let's add two more rows, to show our model's buy/sell signals chart, and our total profits chart:

```python
def get_ml_chart_row():
    """Create a row and column for our Plotly/Dash time series chart"""

    return dbc.Row(
        dbc.Col(
            dbc.Spinner(
                [
                    html.Div(
                        id="ml_chart_div",
                    ),
                ]
            )
        )
    )


def get_profits_chart_row():
    """Create a row and column for our cumulative profits time series chart"""

    return dbc.Row(
        dbc.Col(
            dbc.Spinner(
                [
                    html.Div(id="profits_chart_div"),
                    html.Div(id="profits_chart_msg_div"),
                ]
            )
        )
    )
```

Uncomment the last few functions from our bottom `get_layout` function, and our `layout.py` file is finished!

```python

def get_layout():
    """Function to get Dash's "HTML" layout"""

    industries, industry = get_stock_industries()
    stocks_options, stock = get_stock_tickers(industry)

    # A Bootstrap 4 container holds the rest of the layout
    return dbc.Container(
        [
            get_navbar(),
            get_top_stock_selection_row(industries, industry, stocks_options, stock),
            get_regular_chart_row(stock),
            get_ml_inputs_row(),
            get_train_model_button_row(stock),
            get_ml_chart_row(),
            get_profits_chart_row(),
        ]
    )
```

We've now finished the Dash app layout. In Chapter 3, we'll add one big callback to take in all those new layout inputs, perform the machine learning, and return our buy/sell signals chart, and our profits chart.
