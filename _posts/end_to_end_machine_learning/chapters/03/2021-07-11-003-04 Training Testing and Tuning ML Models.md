---
layout: post
title: Training, Testing, and Tuning ML Models
# slug: training-testing-and-tuning-ml-models
chapter: 4
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}

This chapter is pretty exciting, especially if it's your first time building a machine learning model. You may be surprised to learn that the hard work is mostly behind you. At this point, to "train" a machine learning model, we basically just choose a model (or a bunch of them, in our case), and type `model.fit()`. Scikit-learn takes care of the algebra for us, using a lot of memory and CPU in the process (depending on the model). Okay, maybe it's a bit more involved than that, but that's model "training" in a nutshell.

The most important part of this chapter is model "testing", to build confidence in the model and ensure it's not just "over-fitted" to the training data--a very common problem, and one we'll see as well. 

At the same time as we train and test our models, we're also going to be "tuning" or "hyper-parameter tuning" them to find the best inputs to each model. This procedure hopes to find the best "weights" for the various model parameters.

Let's dive right in. Start by splitting our DataFrame into training and testing tables, so we can train the model on one set of data, and test it on totally separate data.

```python
# How many rows is 60% of our data?
n_training_records = int(0.6*len(df))

# Split into two DataFrames
# (first 60% is for training and last 40% is for testing)
df_train = df.iloc[:n_training_records]
df_test = df.iloc[n_training_records:]

# Print how many rows and columns in each DataFrame
print(f"df_train.shape: {df_train.shape}")
print(f"df_test.shape: {df_test.shape}")
```

Look at the various column names available
```python
df.columns
```

Now isolate the features or explanatory/predictive variables from the value we're trying to predict (future price movements).

```python
# Isolate the features from the value we're trying to predict (future price movements)
features_wanted = ['rt', 'rt1', 'rt2', 'rt3', 'rt4', 'rt5', 'price_7d_14d', 'price_7d_14d_delta', 'macd_binary', 'RSI', 'CCI', 'EMV', 'FI']
X = df[features_wanted].values
X_train = df_train[features_wanted].values
X_test = df_test[features_wanted].values
```

Data science is a bit of an art. Have you thought about what value we're actually trying to predict? We could try to predict the "level" of prices tomorrow, or next week, or next month. Level implies a "regression" problem (i.e. trying to predict the value of a continuous variable). 

Alternatively, we could simply classify our returns as up or down, for tomorrow, next week, next month, etc. This is a "classification" problem. Classification problems are labeling problems (e.g. is it true or false, up or down, 1 or 0, cat or dog). 

This is an important point to remember. Machine learning problems are either regression or classification problems, and we use different models to predict each. 

For this course, I've chosen to predict whether prices are going to go up or down over the next week (classification problem). If the model predicts up, we can buy 100 share of stock. If the model predicts down, we can sell or even short-sell 100 shares of the stock. 

```python
y_feature = 'up_down_1wk'
y = df[y_feature].values
y_train = df_train[y_feature].values
y_test = df_test[y_feature].values

print(f"X.shape: {X.shape}")
print(f"y.shape: {y.shape}")

print(f"X_train.shape: {X_train.shape}")
print(f"y_train.shape: {y_train.shape}")

print(f"X_test.shape: {X_test.shape}")
print(f"y_test.shape: {y_test.shape}")
```

Another important step is data "scaling". Many machine learning models work best if the features have roughly the same mean and standard deviation, so machine learning practitioners almost always scale the data. The two most common scaling methods I've seen are "standardization" and "min/max transformation". 

Standardization calculates the z-score, which you may remember from statistics. We simply subtract the sample mean from each data point, and divide by the sample standard deviation, which leaves a sample with mean of 0 and standard deviation of 1. 

Min-max scaling is very similar, and usually scales the data between 0 and 1, so it's good if you don't want negative numbers. 

Either approach would work fine in this case, so I've chosen the `StandardScaler()` to scale each explanatory feature to a mean of zero, and a standard deviation of one. 

```python
# Calculate the z-score with mean of 0 and standard deviation of 1
# In other words, standardize the data
ss = StandardScaler()
X_scaled = ss.fit_transform(df[features_wanted])
```

If you're good at linear regression and you want to look at the various regression statistics (e.g. R-squared, betas, p-values, etc), here's how you can calculate those with the statsmodels package. 

```python
# Add a 1 for the intercept
X_scaled = sm.add_constant(X_scaled)

# If we were using regression, we'd do this
# model_ols = sm.OLS(y, X_scaled)
# results_ols = model_ols.fit()
# print(results_ols.summary())

# sm.Logit class for classification problems
model_logit = sm.Logit(y, X_scaled)
results_logit = model_logit.fit()
print(results_logit.summary())
```

Right now we're building up the variables we're going to use, and then we're going to train, test, and hyper-parameter tune all at the same time, rather than doing it in individual baby steps. I want you to have a first-class machine learning pipeline of code you can apply to any ML project in the future, and this is the most efficient way of doing things. 

If you want to build up to this in smaller steps, [here](https://machinelearningmastery.com/machine-learning-in-python-step-by-step/) is another fantastic Jason Brownlee article that will walk you through an example very similar to ours, from start to finish. 

We have already manually split our time series data into two pieces for a sanity check, but for our ML pipeline, we're going to employ a special time series cross-validation class, which will split our time series data into multiple chunks.

Time series data is special because it's auto-correlated over time (i.e. today's prices are related to yesterday's), so we can just randomly split our data. We must always be predicting data that's in the future. We can't cheat and use next week's prices to predict tomorrow's prices, for example. The following class does that job for us. In our web app, the user can specify the number of time series splits to use when training the data.

```python
# Time series split for cross-validation
tscv = TimeSeriesSplit(n_splits=2)
```

Below we will instantiate quite a few scikit-learn machine learning classification models, inside a scikit-learn "pipeline". The pipeline does specified jobs in a certain order. In our case, we first want to scale the data with our previously-instantiated `StandardScaler` (ss) class. Then we want to "fit" or "train" the machine learning model to the scaled data.

```python
# Classification machine learning models to test

# K-nearest neighbours classifier - very simple classifier that finds the most similar record
ml_pipe_knn = Pipeline([('scale', ss), ('knn', KNeighborsClassifier())])

# Logistic regression - one of the most basic classification models
ml_pipe_ols = Pipeline([('scale', ss), ('ols', LogisticRegression())])

# Ridge classification, which improves on logistic regression by trying not to over-fit on the training data
ml_pipe_ridge = Pipeline([('scale', ss), ('ridge', RidgeClassifier())])

# AdaBoost decision tree classifier, which uses the "ensemble" approach to "boost" the fit
ml_pipe_dtab = Pipeline([('scale', ss), ('dtab', AdaBoostClassifier())])

# Random forest classifier - one of my favourite non-linear classifiers
ml_pipe_rf = Pipeline([('scale', ss), ('rf', RandomForestClassifier())])

# Support vector classifier - another favourite, and difficult to explain in one line ;)
ml_pipe_sv = Pipeline([('scale', ss), ('sv', SVC())])

# Multi-layer perceptron classifier - relatively simple neural network
ml_pipe_mlp = Pipeline([('scale', ss), ('mlp', MLPClassifier())])
```

Next, we'll add the parameters we want to tune/test for each ML model. Most machine learning models have parameters whose values we must specify. Think of these parameters as weights. We're going to try out a number of different weights, and choose the best weights for our final model.

For example, logistic regression only has one parameter to tune--whether we want it to fit the y-intercept or not. Other models have more parameters.

```python
param_grid_ols = [{'ols__fit_intercept': [True, False]}]
```

Here are all the other parameter grids we're going to try, for each of our ML models. 

```python
# Classification hyper-parameter tuning grids
param_grid_ols = [{'ols__fit_intercept': [True, False]}]
param_grid_ridge = [{'ridge__alpha': [0, 0.001, 0.1, 1.0, 5, 10, 50, 100, 1000, 10000, 100000]}]
param_grid_dtab = [{
    'dtab__n_estimators': [50, 100],
    'dtab__learning_rate': [0.75, 1.0, 1.5],
}]
param_grid_rf = [{
    'rf__n_estimators': [100, 200],
    'rf__max_features': ['auto', 'sqrt', 'log2'],
    'rf__max_depth' : [2,4,8],
}]
param_grid_mlp = [{
    'mlp__activation': ['relu', 'tanh'],
    'mlp__solver': ['adam', 'sgd'],
    'mlp__alpha': [0.01, 0.1, 1, 10, 100]
}]
param_grid_sv = [{
    'sv__kernel': ['rbf', 'linear', 'poly'],
    'sv__C': [0.01, 0.1, 1, 10],
    'sv__gamma': [0.01, 0.1, 1],
}]
param_grid_knn = [{
    'knn__n_neighbors': [8, 10, 12, 14, 16, 18],
    'knn__weights': ['uniform', 'distance'],
    'knn__p': [1, 2],
    'knn__n_jobs': [1, -1],
}]
```

Finally, here's a function that performs grid-search cross-validation (i.e. training, tuning, and testing) all at once, and returns the results in a DataFrame, along with the best-tuned model from the tests (i.e. the best-tuned parameters). Later we'll compare the resulting DataFrames from each model, to choose the model with the best and most consistent predictions on the test data.

```python
def grid_search_cross_validate(X, y, name,
    estimator,
    param_grid,
    scoring='accuracy',
    cv=4,
    return_train_score=True
):
    """Perform grid-search hyper-parameter tuning and
    train/test cross-validation to prevent overfitting"""

    time_start = time.time()
    gs = GridSearchCV(estimator=estimator, param_grid=param_grid,
        scoring=scoring, cv=cv, return_train_score=return_train_score)
    gs.fit(X, y)
    seconds_elapsed = time.time() - time_start

    print(f"{name} took {round(seconds_elapsed)} seconds")
    print(f"\n{name} training scores: {gs.cv_results_['mean_train_score']}")
    print(f"{name} testing scores: {gs.cv_results_['mean_test_score']}")
    
    df = pd.DataFrame(gs.cv_results_)
    df['estimator'] = name

    return gs, df
```

Ready to really challenge your computer? Time to set this train in motion and actually train/tune/test our models, and rank them based on "accuracy" of classification (i.e. percentage of correct classifications).

The more memory (RAM) and CPU speed your computer has, the better at this point. I do this sort of thing a lot, so I have a 12-core AMD Ryzen 3900X processor, and 96 GB of memory (pretty good as of 2021). Waiting is my least favourite thing...

```python
# Classification: Run all models (this will take a little while!)
estimator_knn, df_gs_results_knn = grid_search_cross_validate(X_train, y_train, 'knn', ml_pipe_knn, param_grid_knn, scoring="accuracy", cv=tscv)
estimator_ols, df_gs_results_ols = grid_search_cross_validate(X_train, y_train, 'ols', ml_pipe_ols, param_grid_ols, scoring="accuracy", cv=tscv)
estimator_ridge, df_gs_results_ridge = grid_search_cross_validate(X_train, y_train, 'ridge', ml_pipe_ridge, param_grid_ridge, scoring="accuracy", cv=tscv)
estimator_dtab, df_gs_results_dtab = grid_search_cross_validate(X_train, y_train, 'dtab', ml_pipe_dtab, param_grid_dtab, scoring="accuracy", cv=tscv)
estimator_rf, df_gs_results_rf = grid_search_cross_validate(X_train, y_train, 'rf', ml_pipe_rf, param_grid_rf, scoring="accuracy", cv=tscv)
estimator_sv, df_gs_results_sv = grid_search_cross_validate(X_train, y_train, 'sv', ml_pipe_sv, param_grid_sv, scoring="accuracy", cv=tscv)
estimator_mlp, df_gs_results_mlp = grid_search_cross_validate(X_train, y_train, 'mlp', ml_pipe_mlp, param_grid_mlp, scoring="accuracy", cv=tscv)
```

How long did that take? A few minutes? Notice the linear logistic and ridge regression models finished almost instantly, while the non-linear models took much longer, especially the support vector classifier (SVC) and the multi-layer perceptron (MLP) neural network.

Now we can combine the various DataFrames into one, and compare which models worked best! Always a very exciting moment. Open up the DataFrame and have a look at the 

```python
# Combine the grid-search results tables so we can compare and find the best estimator
tables_to_combine = [
    df_gs_results_ols, 
    df_gs_results_ridge,
    df_gs_results_knn,
    df_gs_results_dtab,
    df_gs_results_rf,
    df_gs_results_sv,
    df_gs_results_mlp,
]
df_gs_combined = pd.concat(tables_to_combine, axis=0, sort=False)

# Only look at a few of the most important columns for now
summary_cols = ['estimator', 'mean_test_score', 'std_test_score', 'mean_fit_time']

# Sort the values from best-to-worst accuracy
df_gs_combined_summary = df_gs_combined[summary_cols].sort_values('mean_test_score', ascending=False)

# Have a look at the ranked results!
df_gs_combined_summary.head(10)
```

Now that you know the top model and its accuracy on the test data, thanks to cross-validation (i.e. multiple train/test splits), let's pick the best model and use it to predict whether average prices over the next week are up or down. 

```python
# Make predicted returns using best model (e.g. suppose it was ridge regression)
df_test['y_pred'] = estimator_ridge.predict(X_test)
```

It's a lot of predictions, I know (one each day). Let's look at a confusion matrix of the prediction results (a popular table for classification results). 

From [Wikipedia](https://en.wikipedia.org/wiki/Confusion_matrix), a confusion matrix is:

> a specific table layout that allows visualization of the performance of an algorithm, typically a supervised learning one

Basically, it breaks out the true positives and true negatives from the false positives and false negatives. 

```python
# Confusion matrix
cm = confusion_matrix(y_test, df_test['y_pred'].values)
print("Confusion matrix: \n", cm)
```

Next, calculate the model's accuracy manually, to double-check the results from the DataFrame:

```python
# Accuracy score of the model 
print('Test data accuracy: ', accuracy_score(y_test, df_test['y_pred'].values))
```

Finally, let's chart what our profits would be if we actually followed this strategy with 100 shares of stock:

```python
n_shares = 100
# If our prediction == 1, buy 100 shares; otherwise short-sell 100 shares
df_test['position'] = np.where(df_test['y_pred'] == 1, n_shares, -n_shares)

# Our profit is the number of shares we bought today, times the change in price tomorrow
df_test['profit'] = df_test['position'] * df_test['delta_tm']

# Calculate the cumulative profits
df_test['profit_cumul'] = df_test['profit'].cumsum()

# Chart the results!
df_test['profit_cumul'].plot()
```

That's it for our machine learning pipeline. I hope you found it useful. If you're getting into machine learning, I'm confident you'll use an ML pipeline like this over and over for your projects, so save a copy somewhere handy. 

Next, in Part 4, we will port this Jupyter Notebook code into our machine learning web app so we can play with it on the website. After that, Part 5 - Testing and Database Backups involves testing our app and automating database backups. Finally, in Part 6, we'll deploy the app to production using Docker Swarm and Traefik. 
