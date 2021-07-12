---
layout: post
title: Optional VS Code and Docker Setup
# slug: optional-vs-code-and-docker-setup
chapter: 4
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


## VS Code Setup

Once you've got VS Code and Docker installed and setup, add the VS Code [Remote Development](https://code.visualstudio.com/docs/remote/remote-overview) extension so that you can code inside a Linux Docker container. This is awesome for reproducibility, since your development environment will be the same as your Dockerized Linux production environment. It's especially handy if, like me, you're running Windows, since Python and Linux are best friends.

Create a new project directory (either with the below command, or your GUI folder explorer):

```bash
$ mkdir end-to-end-machine-learning && cd end-to-end-machine-learning
```

To configure your [Dockerized development environment in VS Code](https://code.visualstudio.com/docs/remote/create-dev-container), create a *.devcontainer* folder in your project folder. Then create two files inside it:
1. devcontainer.json
2. docker-compose.yml

Paste the following into your *devcontainer.json* file, so VS Code knows where to start:

```json
{
    // Your Docker containers will be prefixed with the following
	"name": "end_to_end_machine_learning",

	// Path that the Docker build should be run from relative to devcontainer.json.
    // In other words, your Dockerfile is one level up from the .devcontainer folder.
	"context": "..",

	// Use either the Dockerfile or docker-compose.yml to create the Docker container
	// "dockerFile": "Dockerfile",
	"dockerComposeFile": "docker-compose.yml",

	// Required if using dockerComposeFile. The name of the service VS Code should connect to once running.
	// The 'service' property is the name of the service for the container that VS Code should
	// use. Update this value and .devcontainer/docker-compose.yml to the real service name.
	"service": "dev_container",

	// The optional 'workspaceFolder' property is the path VS Code should open by default when
	// connected. This is typically a file mount in .devcontainer/docker-compose.yml
	"workspaceFolder": "/workspace",

    // VS Code extensions we'll be using
	"extensions": [
		"ms-python.python",
		"ms-python.vscode-pylance"
	],
}
```

See my comments in the file above. Note the references to *docker-compose.yml*, which we'll create next, and the Docker container "service" inside the *docker-compose.yml* file, which will be called "dev_container" (our Python development Docker container, in which we'll run our Flask/Dash app, and our Jupyter Notebooks).

Next, create the *docker-compose.yml* file in the same *.devcontainer* folder, for managing three different Docker containers, one Docker network, and two Docker volumes for data persistence.

```yml
version: '3.7'
services:
  # TimescaleDB/PostgreSQL database
  timescale:
    image: timescale/timescaledb:latest-pg12
    restart: unless-stopped
    env_file:
      - ../.env
    volumes:
      - type: volume
        source: timescale_volume # the volume name
        target: /var/lib/postgresql/data # the location in the container where the data is stored
        read_only: false
    ports:
      - 0.0.0.0:5432:5432
    networks:
      - timescale_network

  # PGAdmin for administering the TimescaleDB/PostgreSQL database with SQL
  pgadmin:
    image: "dpage/pgadmin4:latest"
    restart: unless-stopped
    env_file:
      - ../.env
    environment:
      PGADMIN_LISTEN_PORT: 9000
    ports:
      - 0.0.0.0:9000:9000
    volumes:
      # So the database server settings get saved and stored even if the container is replaced or deleted
      - pgadmin:/var/lib/pgadmin
    networks:
      - timescale_network

  # Our Python development container, for running our Flask/Dash app, and our Jupyter Notebooks
  dev_container:
    volumes:
      # Mount the root folder that contains .git
      - ..:/workspace
    build:
      # context: where should docker-compose look for the Dockerfile?
      # i.e. either a path to a directory containing a Dockerfile, or a url to a git repository
      context: ..
      dockerfile: Dockerfile.dev
    env_file:
      - ../.env
    environment:
      FLASK_CONFIG: development
      FLASK_ENV: development
    # Forwards port 0.0.0.0:5006 from the Docker host (e.g. your computer)
    # to the dev environment container's port 5000
    ports:
      - 0.0.0.0:5006:5000
    # Overrides default command so things don't shut down after the process ends.
    command: sleep infinity
    networks:
      - timescale_network

networks:
  # The network the above containers share, for accessing the database
  timescale_network:

# Creates a named volume to persist our database data
volumes:
  timescale_volume:
  pgadmin:

```

All the above Docker containers require a *.env* file for your secret environment variables, so let's create that now, in the main project directory. Be sure to change the email address, passwords, and AWS credentials to your own. If you don't yet have AWS credentials, we'll cover that in a later chapter.

```shell
# .env

# For the PGAdmin web app
PGADMIN_DEFAULT_EMAIL=your@email.com
PGADMIN_DEFAULT_PASSWORD=password

# For Flask
SECRET_KEY=long-random-string-of-characters-numbers-etc-must-be-unique

# For the Postgres/TimescaleDB database.
# Notice the `POSTGRES_HOST=timescale` which uses the Docker Compose service name as the host.
# If you have TimescaleDB installed elsewhere, please change the host/port, etc to suit your needs.
POSTGRES_HOST=timescale
POSTGRES_PORT=5432
POSTGRES_DATABASE=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
PGDATA=/var/lib/postgresql/data

# Same credentials as above, but for SQLAlchemy
SQLALCHEMY_DATABASE_URI=postgresql+psycopg2://postgres:password@timescale:5432/postgres

# For TimescaleDB backups
# s3_bucket_backup_timescaledb AWS IAM user can only create TimescaleDB backups in a certain bucket
AWS_ACCESS_KEY_ID=key
AWS_SECRET_ACCESS_KEY=secret
AWS_DEFAULT_REGION=us-west-2
```

Note the third container (*dev_container*) requires a file called *Dockerfile.dev*, since that's our custom Python container for the web app and our Jupyter Notebooks. Let's create that file now, but *not* in the *.devcontainer* folder. Put it one level up in the main project folder (i.e. `context: ..`) beside your *.env* file.

```shell
# Base image
# Python 3.9 doesn't install scikit-learn correctly, so use 3.8 instead
FROM python:3.8

# Set the default working directory
WORKDIR /usr/src/app

# Some normal Python optimizations
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Install Google Chrome for Selenium WebDriver integration testing
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
RUN apt-get -y update && \
    apt-get install -y google-chrome-stable git && \
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Install ChromeDriver
RUN apt-get install -yqq unzip
RUN wget -O /tmp/chromedriver.zip http://chromedriver.storage.googleapis.com/`curl -sS chromedriver.storage.googleapis.com/LATEST_RELEASE`/chromedriver_linux64.zip
RUN unzip /tmp/chromedriver.zip chromedriver -d /usr/local/bin/

# Set display port to avoid crash in Selenium WebDriver integration testing
ENV DISPLAY=:99

# Install Poetry for package management
RUN pip3 install --upgrade pip setuptools wheel && \
    pip3 install poetry

# Install packages with Poetry,
# including development packages like Black and PyLint
COPY pyproject.toml /
RUN poetry config virtualenvs.create false && \
  poetry install --no-interaction --no-ansi
```

The above *Dockerfile.dev* creates our development Python container for VS Code debugging. While we're at it, let's create our production *Dockerfile*, which is a bit leaner:

```shell
# Base image
# Python 3.9 doesn't install scikit-learn correctly, so use 3.8 instead
FROM python:3.8-slim-buster

# Set the default working directory
WORKDIR /usr/src/app

# Some normal Python optimizations
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Install Poetry for package management
RUN pip3 install --upgrade pip setuptools wheel && \
    pip3 install poetry

# Install packages with Poetry,
# including development packages like Black and PyLint
COPY pyproject.toml /
RUN poetry config virtualenvs.create false && \
  poetry install --no-interaction --no-ansi

# Copy all the local files to WORKDIR
COPY . .
```

For the production file above, we use `python:3.8-slim-buster` (Debian-buster, slim version) to minimize our image size. We also don't install Chrome and Selenium Webdriver, which are for development/test environments only.

Note the above Dockerfiles have a `COPY pyproject.toml /` line at the bottom. We're going to use Poetry to manage our Python packages, and Poetry uses the *pyproject.toml* as its requirements file, similar to the usual *requirements.txt* file you'd see if you were using pip to install your packages. These days I prefer using [Poetry](https://python-poetry.org/) to [Pip](https://pypi.org/project/pip/) for Python package management.

Create your own *pyproject.toml* file beside your *Dockerfile.dev*, for Poetry to use, and paste in the following contents:

```
[tool.poetry]
name = "end_to_end_machine_learning"
version = "0.1.0"
description = "Build and deploy a machine learning, stock price-forecasting web app."
authors = ["Sean McCarthy <sean.mccarthy@live.ca>"]
license = "MIT"

[tool.poetry.dependencies]
python = "^3.6.1"
click = "^7.1.2"
dash = "^1.16.1"
Flask = "^1.1.2"
Flask-Caching = "^1.9.0"
Flask-Login = "^0.5.0"
Flask-Migrate = "^2.5.3"
Flask-SQLAlchemy = "^2.4.4"
Flask-Testing = "^0.8.0"
Flask-WTF = "^0.14.3"
gevent = "^20.6.2"
greenlet = "^0.4.16"
gunicorn = "^20.0.4"
numpy = "^1.19.2"
pandas = "^1.1.2"
psycopg2-binary = "^2.8.6"
python-dateutil = "^2.8.1"
python-dotenv = "^0.14.0"
python-editor = "^1.0.4"
pytz = "^2020.1"
PyYAML = "^5.3.1"
dash-bootstrap-components = "^0.10.6"
email-validator = "^1.1.1"
yfinance = "^0.1.55"
scikit-learn = "^0.23.2"
ipykernel = "^5.4.2"
matplotlib = "^3.3.3"
keras = "^2.4.3"
statsmodels = "^0.12.1"
selenium = "^3.141.0"
jwt = "^1.1.0"
flask-bootstrap4 = "^4.0.2"

[tool.poetry.dev-dependencies]
flake8 = "^3.8.3"
black = "^20.8b1"
bandit = "^1.6.2"
autoflake = "^1.4"
isort = "^5.5.2"
selenium = "^3.141.0"
pytest = "^6.2.1"
percy = "^2.0.2"
beautifulsoup4 = "^4.9.3"

[build-system]
requires = ["poetry>=0.12"]
build-backend = "poetry.masonry.api"
```

To speed up later debugging, and help VS Code to find our settings, let's now create a *.vscode* folder beside our *.devcontainer* folder, along with the following two files:

1. settings.json
2. launch.json

Inside *settings.json*, paste the following contents to enable Pylance, Pylint, and Jupyter Notebooks, and to help VS Code find our Python interpreter:

```json
{
    "python.languageServer": "Pylance",
    "python.linting.pylintEnabled": true,
    "python.linting.enabled": true,
    "python.pythonPath": "/usr/local/bin/python",
    "jupyter.jupyterServerType": "local"
}
```

Inside *launch.json*, paste the following contents to configure four different debuggers:

1. Flask
2. Regular Python file runner
3. Pytest (run all tests)
4. Pytest (current test file only)

```json
{
    "version": "0.2.0",
    "configurations": [

        // Debug with Flask
        {
            "name": "flask run --no-debugger --no-reload",
            "type": "python",
            "request": "launch",
            "module": "flask",
            "env": {
                "FLASK_APP": "wsgi:app",
                "FLASK_ENV": "development",
                "FLASK_DEBUG": "0"
            },
            "args": [
                "run",
                "--no-debugger",
                "--no-reload",
            ],
            "jinja": true,
            "justMyCode": false
        },

        // Regular Python file debugger to run the current file
        {
            "name": "Python Run Current File",
            "type": "python",
            "request": "launch",
            "program": "${file}",
            "console": "integratedTerminal",
            "jinja": true,
            "justMyCode": false
        },

        // Pytest all files
        {
            "name": "Pytest All Files",
            "type": "python",
            "request": "launch",
            "module": "pytest",
            "console": "integratedTerminal",
            "args": [
                "/workspace/app/tests/",
                // "-v",
                // "--lf",
                "--durations=0",
            ],
        },

        // Pytest run the current file only
        {
            "name": "Pytest Run Current File",
            "type": "python",
            "request": "launch",
            "module": "pytest",
            "console": "integratedTerminal",
            "args": [
                "${file}",
                // "-v",
                // "--lf",
                "--durations=0",
            ],
        },
    ]
}
```

With that, VS Code should have everything it needs to create your fully-reproducible development environment, which will be identical to everyone else's (the beauty of Docker). If you haven't already, either right-click anywhere inside your project folder and click "Open with Code", or from the file menu in VS Code, select "Open Folder..." and select your project folder.

In the bottom-left corner of VS Code, click on the green box and then click ["Reopen in Container"](https://code.visualstudio.com/docs/remote/create-dev-container). Docker will then begin creating your three Docker containers, per your instructions in *./.devcontainer/docker-compose.yml*:

1. timescale
2. pgadmin
3. dev_container

The first two containers won't take long to build, since they're just images to be downloaded and started. The third `dev_container` will take a while to build/start, since it's a custom Python 3.8, Debian Linux-based container that installs all our Python packages with Poetry. Once it's built the first time, it'll subsequently be many times faster to start up, unless you install new Python packages with something like `poetry add --dev bandit`, which will change your *pyproject.toml* requirements file. Go grab a coffee and check back in ~15 minutes--we're installing quite a few Python packages...  ;)

If you need to add a new package in the future, just run, for example `poetry add black` to add the excellent [Black](https://pypi.org/project/black/) package for automatically (and nicely, I might add) formatting your code. To only add Black as a dependency in your development environment, as I do, you'd run `poetry add --dev black`. Very simple. To remove the package, run `poetry remove black`.

Now that we've taken the time to setup our development environment, we can fly through the rest of the course with minimal headaches, focusing on the code and the data science, not the environment.


{% include end_to_end_ml_table_of_contents.html %}
