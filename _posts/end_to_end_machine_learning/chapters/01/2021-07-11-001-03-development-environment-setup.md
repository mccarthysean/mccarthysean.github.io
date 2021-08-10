---
layout: post
title: Development Environment Setup
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
featured: false
hidden: false
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


This is a very important chapter, so definitely don't skip it. Before we can do anything in Python, we always have to set up an environment.

Most courses are either focused on building apps, on ad hoc data science, or on SQL. This course tackles all three at the same time, which is unique. We're going to do some ad hoc data science and SQL database stuff, and then we're going to deploy our machine learning model to a Dockerized web app with a PostgreSQL database, so we'll need the best of all both worlds. If you're just building an app, you want an IDE that's great for debugging, and there are many from which to choose (e.g. VS Code, PyCharm, Sublime, etc). If you're just doing ad hoc data science in Python, you'll probably want either Jupyter Notebooks or Spyder, and you'll probably install those using Anaconda or Miniconda. If you're just doing SQL in a PostgreSQL database, you might choose PGAdmin or something else.

What we want is a reproducible, Linux-based environment in which we can debug our Flask/Dash web app, do ad hoc data science and machine learning in Jupyter Notebooks, and write SQL directly in PGAdmin or via the website, or directly in a Python script. All environments must talk to the PostgreSQL database, which is inside a Docker container, on a Docker network, and all must have the same versions of our scientific Python packages, such as Scikit-Learn, so that our models are transferable.

The best IDE I've found for meeting all these requirements is [VS Code](https://code.visualstudio.com/download). With VS Code, you can work inside a 100% reproducible, Dockerized, Linux-based development environment, which exactly matches your production environment. That development environment can contain other Docker containers, such as TimescaleDB and PGAdmin for the database. And you can run your ad hoc data science tasks using the built-in Jupyter Notebooks.

## VS Code Setup

If you'd prefer to use VS Code for everything, as I do, you can actually skip the rest of this chapter and jump directly to the next chapter "Optional VS Code and Docker Setup".

## Non-VS Code Setup

If you prefer a different IDE than VS Code, by all means use it. However, the ad hoc data science stuff works best in either [Jupyter Notebooks](https://jupyter.org/) or [Spyder](https://www.spyder-ide.org/). The easiest way to get both is to download [Anaconda](https://www.anaconda.com/products/individual) or the lighter-weight [Miniconda](https://docs.conda.io/en/latest/miniconda.html). 

For those who prefer a different IDE, you'll probably need to setup two separate environments--one for debugging your web app, and another one for running ad hoc data science tasks in Jupyter Notebooks or Spyder. 

### Poetry Package Installation

We're going to use Poetry to manage our Python packages, and Poetry uses the *pyproject.toml* as its requirements file, similar to the usual *requirements.txt* file you'd see if you were using pip to install your packages. These days I prefer using [Poetry](https://python-poetry.org/) to [Pip](https://pypi.org/project/pip/) for Python package management.

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

### Pip Alternative to Poetry

Using [pip](https://pypi.org/project/pip/) to install packages is the traditional approach. If you'd prefer to use pip instead of Poetry, you can copy the following to a *requirements.txt* file and install it into your virtual environment using `pip3 install -r requirements.txt`. 

```bash
alembic==1.5.8
appdirs==1.4.4
appnope==0.1.2; sys_platform == "darwin" or platform_system == "Darwin"
atomicwrites==1.4.0; sys_platform == "win32"
attrs==20.3.0
autoflake==1.4
backcall==0.2.0
bandit==1.7.0
beautifulsoup4==4.9.3
black==20.8b1
brotli==1.0.9
cached-property==1.5.2; python_version < "3.8"
certifi==2020.12.5
cffi==1.14.5; platform_python_implementation == "CPython" and sys_platform == "win32" or implementation_name == "pypy"
chardet==4.0.0
click==7.1.2
colorama==0.4.4; sys_platform == "win32" or platform_system == "Windows"
cycler==0.10.0
dash==1.20.0
dash-bootstrap-components==0.10.7
dash-core-components==1.16.0
dash-html-components==1.1.3
dash-renderer==1.9.1
dash-table==4.11.3
decorator==5.0.7
dnspython==2.1.0
dominate==2.6.0
email-validator==1.1.2
flake8==3.9.1
flask==1.1.2
flask-bootstrap4==4.0.2
flask-caching==1.10.1
flask-compress==1.9.0
flask-login==0.5.0
flask-migrate==2.7.0
flask-sqlalchemy==2.5.1
flask-testing==0.8.1
flask-wtf==0.14.3
future==0.18.2
gevent==20.12.1
gitdb==4.0.7
gitpython==3.1.15
greenlet==0.4.17
gunicorn==20.1.0
h5py==3.2.1
idna==2.10
importlib-metadata==4.0.1; python_version < "3.8"
iniconfig==1.1.1
ipykernel==5.5.3
ipython==7.22.0
ipython-genutils==0.2.0
isort==5.8.0
itsdangerous==1.1.0
jedi==0.18.0
jinja2==2.11.3
joblib==1.0.1
jupyter-client==6.2.0
jupyter-core==4.7.1
keras==2.4.3
kiwisolver==1.3.1
lxml==4.6.3
mako==1.1.4
markupsafe==1.1.1
matplotlib==3.4.1
mccabe==0.6.1
multitasking==0.0.9
mypy-extensions==0.4.3
nest-asyncio==1.5.1
numpy==1.20.2
packaging==20.9
pandas==1.1.5
pandas==1.2.4
parso==0.8.2
pathspec==0.8.1
patsy==0.5.1
pbr==5.5.1
percy==2.0.2
pexpect==4.8.0; sys_platform != "win32"
pickleshare==0.7.5
pillow==8.2.0
plotly==4.14.3
pluggy==0.13.1
prompt-toolkit==3.0.18
psycopg2-binary==2.8.6
ptyprocess==0.7.0; sys_platform != "win32"
py==1.10.0
pycodestyle==2.7.0
pycparser==2.20; platform_python_implementation == "CPython" and sys_platform == "win32" or implementation_name == "pypy"
pyflakes==2.3.1
pygments==2.8.1
pyparsing==2.4.7
pytest==6.2.3
python-dateutil==2.8.1
python-dotenv==0.14.0
python-editor==1.0.4
pytz==2020.5
pywin32==300; sys_platform == "win32"
pyyaml==5.4.1
pyzmq==22.0.3
regex==2021.4.4
requests==2.25.1
retrying==1.3.3
scikit-learn==0.23.2
scipy==1.6.1
scipy==1.6.2
selenium==3.141.0
six==1.15.0
smmap==4.0.0
soupsieve==2.2.1; python_version >= "3.0"
sqlalchemy==1.3.24
statsmodels==0.12.2
stevedore==3.3.0
threadpoolctl==2.1.0
toml==0.10.2
tornado==6.1
traitlets==5.0.5
typed-ast==1.4.3
typing-extensions==3.7.4.3
urllib3==1.26.4
visitor==0.1.3
wcwidth==0.2.5
werkzeug==1.0.1
wtforms==2.3.3
yfinance==0.1.59
zipp==3.4.1; python_version < "3.8"
zope.event==4.5.0
zope.interface==5.4.0
```


Ensure you've got Docker installed on your computer (probably [Docker Desktop](https://www.docker.com/products/docker-desktop) if you're on Windows or Mac). This course makes extensive use of Docker for reproducible environments in both development and production. If you haven't used Docker before, now is the time to start. It's incredible. 

Create a *docker-compose.yml* file for managing three different Docker containers, one Docker network, and two Docker volumes for data persistence.

```yml
version: '3.7'
services:
  # TimescaleDB/PostgreSQL database
  timescale:
    image: timescale/timescaledb:latest-pg12
    restart: unless-stopped
    env_file:
      - .env
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
      - .env
    environment:
      PGADMIN_LISTEN_PORT: 9000
    ports:
      # Use 0.0.0.0 to make this DB admin app accessible from "http://localhost:9000"
      - 0.0.0.0:9000:9000
    volumes:
      # So the database server settings get saved and stored even if the container is replaced or deleted
      - pgadmin:/var/lib/pgadmin
    networks:
      - timescale_network

  # Our Python development container, for running our Flask/Dash app, and our Jupyter Notebooks
  dev_container:
    volumes:
      # Mount the root folder so its contents update automatically in development
      - .:/usr/src/app
    build:
      # context: where should docker-compose look for the Dockerfile?
      # i.e. either a path to a directory containing a Dockerfile, or a url to a git repository
      context: .
      dockerfile: Dockerfile.dev
    env_file:
      - .env
    environment:
      FLASK_CONFIG: development
      FLASK_ENV: development
    # Forwards requests from http://localhost:5006 on the Docker host (e.g. your computer)
    # to the dev environment container's port 5000.
    # Your web app is accessible at "http://localhost:5006"
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

Note the third container (*dev_container*) requires a file called *Dockerfile.dev*, since that's our custom Python container for the web app (and our Jupyter Notebooks, if you're using VS Code). Let's create that file now in the main project folder beside your *.env* file.

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
COPY pyproject.toml .
RUN poetry config virtualenvs.create false && \
  poetry install --no-interaction --no-ansi
```

The above *Dockerfile.dev* creates our Python container for our development web app. While we're at it, let's create our production *Dockerfile*, which is a bit leaner:

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
COPY pyproject.toml .
RUN poetry config virtualenvs.create false && \
  poetry install --no-interaction --no-ansi

# Copy all the local files to WORKDIR
COPY . .
```

For the production file above, we use `python:3.8-slim-buster` (Debian-buster, slim version) to minimize our image size. We also don't install Chrome and Selenium Webdriver, which are for development/test environments only.

Build and start the above containers using Docker with the following shell command:
```shell
docker-compose up -d --build
```

The first two containers won't take long to build, since they're just images to be downloaded and started. The third `dev_container` will take a while to build/start, since it's a custom Python 3.8, Debian Linux-based container that installs all our Python packages with Poetry. Once it's built the first time, it'll subsequently be many times faster to start up, unless you install new Python packages with something like `poetry add --dev bandit`, which will change your *pyproject.toml* requirements file. Go grab a coffee and check back in ~15 minutes--we're installing quite a few Python packages...  ;)

> If you need to add a new package in the future, just activate your project's virtual environment and run, for example `poetry add black` to add the excellent [Black](https://pypi.org/project/black/) package for automatically (and nicely, I might add) formatting your code. To only add Black as a dependency in your development environment, as I do, you'd run `poetry add --dev black`. Very simple. To remove the package, run `poetry remove black`.

Now that we've taken the time to setup our development environment, we can fly through the rest of the course with minimal headaches, focusing on the code and the data science, not the environment.

{% include end_to_end_ml_table_of_contents.html %}
