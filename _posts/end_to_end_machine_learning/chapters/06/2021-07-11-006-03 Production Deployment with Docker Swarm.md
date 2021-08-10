---
layout: post
title: Production Deployment with Docker Swarm
# slug: production-deployment-with-docker-swarm
chapter: 3
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
# featured: false
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


Now that we've got Docker Swarm mode running on our production server, and we've got Traefik running on the Docker swarm, it's time to deploy our web app and database with Docker.

There's one last step for our web app--setting up the production application server. In development, we just use Flask's development server, but of course it's not meant to be run in production. For that, most people use [Gunicorn](https://gunicorn.org/) these days. According to its own website, it's:

> broadly compatible with various web frameworks, simply implemented, light on server resources, and fairly speedy.

We've already installed it back when we installed all our requirements. Our Dockerfile will take care of installing it in production... Speaking of our Dockerfile, here it is. Create a file named `Dockerfile` in your root directory and add the following contents:

```dockerfile
# Base image
# Python 3.9 doesn't install scikit-learn correctly
FROM python:3.8-slim-buster

# Install Poetry for package management
RUN pip3 install --upgrade pip setuptools wheel && \
    pip3 install poetry && \
    # Install curl for the Docker healthcheck, for zero-downtime deployment with Docker Swarm
    apt-get update && \
    apt-get install -y curl netcat && \
    # Clean up
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Install packages with Poetry
COPY pyproject.toml /
RUN poetry config virtualenvs.create false && \
  poetry install --no-interaction --no-ansi --no-dev

# Copy the main app folder to the container
COPY app app
# Copy some other files in the root directory
COPY .env wsgi.py gunicorn-cfg.py entrypoint.sh /

# Let Flask know where to start
ENV FLASK_APP wsgi.py

# Commands to run on container startup
CMD ["/bin/bash", "/entrypoint.sh"]
```

Notice that Docker uses the `python:3.8-slim` Debian Linux base image. Then it installs pip and Poetry, curl and netcat, and uses Poetry to install all the Python libraries, including Gunicorn.

Then Docker copies the `app` folder to the image or container, as well as a few other files (some of which we have yet to create):
1. .env - already created
2. wsgi.py - already created
3. gunicorn-cfg.py
4. entrypoint.sh

Let's create the last two files in that list, starting with `gunicorn-cfg.py`. Don't worry too much about the configuration options. If you want to read more, see their documentation [here](https://docs.gunicorn.org/en/latest/settings.html):

```bash
# -*- encoding: utf-8 -*-

# Host and port (i.e. socket)
bind = "0.0.0.0:5000"
threads = 2
accesslog = "-"
loglevel = "debug"
capture_output = True
enable_stdio_inheritance = True

# gevent setup
workers = 2
worker_class = "gevent"
# The maximum number of simultaneous clients.
# This setting only affects the Eventlet and Gevent worker types.
worker_connections = 10
```

Next let's create an `entrypoint.sh` shell script to use Netcat to check if the TimescaleDB database is running on port 5432, before launching Gunicorn.

On the final line of the file, we start Gunicorn and pass it the location of the config file we just created, along with the Python `wsgi` module and `app` variable so it knows where to run the Flask-based web app.

```bash
#!/bin/bash

echo "Waiting for TimescaleDB to be available..."

# Use netcat (nc) to check if the TimescaleDB host/port are accessible
while ! nc -z timescale 5432; do
  sleep 0.1
done

echo "TimescaleDB started"

# Finally, start the Gunicorn app server for the Flask app
gunicorn --config /gunicorn-cfg.py wsgi:app
```

I like to keep things simple and create a shell script I can run on my master Docker Swarm "manager node", which issues my Docker deployment commands for me. The steps I take are as follows:

1. SSH into the server
2. cd to ~/git folder
3. `git clone <repository name>` - clone the repository if you haven't already
4. `git pull` if you've already cloned, and just want to pull the latest changes
5. `bash deploy.sh` to run my deployment script

Step 5 runs my deployment script. Here's what my script includes. Notice the second step where it pushes the Docker-built image to my Docker Hub image repository. This step is necessary since each "node" in the Docker swarm (could be multiple servers) needs to download the same Docker image to stay in synch. 

```bash
#!/bin/bash

# Build and tag image locally in one step. 
# No need for docker tag <image> mccarthysean/ijack:<tag>
echo ""
echo "Building the image locally..."
echo "docker-compose -f docker-compose.build.yml build"
docker-compose -f docker-compose.build.yml build

# Push to Docker Hub
# docker login --username=mccarthysean
echo ""
echo "Pushing the image to Docker Hub..."
echo "docker push mccarthysean/stocks_ml:latest"
docker push mccarthysean/stocks_ml:latest

# Deploy to the Docker swarm and send login credentials 
# to other nodes in the swarm with "--with-registry-auth"
echo ""
echo "Deploying to the Docker swarm..."
echo "docker stack deploy --with-registry-auth --compose-file docker-compose.prod.yml stocks_ml"
docker stack deploy --with-registry-auth --compose-file docker-compose.prod.yml stocks_ml
```

Notice the above `deploy.sh` file referred to two more files, and a Docker registry (mccarthysean/stocks_ml). You'll want to sign up for your own [Docker Hub](https://hub.docker.com/) registry at this point. Docker Hub is similar to creating a [GitHub](https://github.com/) or [GitLab](https://about.gitlab.com/) account, but for Docker images instead of source code.

Create the following `docker-compose.build.yml` file to build your image before uploading it to Docker Hub. It's a lot like a Docker Compose file, except it only specifies the image name, the `build` location of the `Dockerfile` you just created, and optional environment variables.

```yml
version: '3.7'
services:

  stocks_ml:
    # Name and tag of image the Dockerfile creates
    image: mccarthysean/stocks_ml:latest
    # Location of the "Dockerfile"
    build: .
    environment:
      FLASK_CONFIG: production
      FLASK_ENV: production
      FLASK_DEBUG: 0
```

With that complete, it's time for our final file of this entire project. Create a `docker-compose.prod.yml` file (your master Docker Compose file for production) with the following contents. This is an advanced Docker Compose file built for Docker Swarm and Traefik, with various advanced deployment options, and a healthcheck to ensure it's running properly.

My favourite thing about Docker Swarm is that you can update your website in production with **zero downtime**. Docker creates the updated containers and tries to start them. If the "healthcheck" passes, Docker removes the old containers and the new ones take over! I've put lots of comments into the file so you can understand it better. Check out [this](https://docs.docker.com/compose/compose-file/compose-file-v3/#deploy) and [this](https://github.com/compose-spec/compose-spec/blob/master/deploy.md) as references for creating Docker Compose files for Docker Swarm. 

```yml
version: '3.7'
services:
  stocks_ml:
    # Name and tag of image the Dockerfile creates
    image: mccarthysean/stocks_ml:latest
    depends_on:
      - timescale
    env_file: .env
    environment:
      FLASK_CONFIG: production
      FLASK_ENV: production
      FLASK_DEBUG: 0
    networks:
      traefik-public:
      timescale_network:
    healthcheck:
      # Command to check if the container is running, for zero-downtime deployment.
      # If the website is fine, curl returns a return code of 0 and deployment continues
      # NOTE: must have curl installed in the stocks_ml Docker container
      test: ["CMD", "curl", "-i", "http://localhost:5000/healthcheck"]
    deploy:
      # Either global (exactly one container per physical node) or
      # replicated (a specified number of containers). The default is replicated
      mode: replicated
      # For stateless applications using "replicated" mode,
      # the total number of replicas to create
      replicas: 1
      update_config:
        # parallelism = the number of containers to update at a time
        parallelism: 1
        # start-first = new task is started first, and the running tasks briefly overlap
        order: start-first
        # What to do if an update fails
        failure_action: rollback
        # time to wait between updating a group of containers
        delay: 5s
      rollback_config:
        # If parallelism set to 0, all containers rollback simultaneously
        parallelism: 0
        # stop-first = old task is stopped before starting new one
        order: stop-first
      restart_policy:
        condition: on-failure
      labels:
        # Ensure Traefik sees it and does Letsencrypt for HTTPS
        - traefik.enable=true
        # Must be on traefik-public overlay Docker Swarm network
        - traefik.docker.network=traefik-public
        - traefik.constraint-label=traefik-public
        # HTTP (port 80)
        - traefik.http.routers.stocks_ml-http.rule=Host(`stocksmldemo.mccarthysean.dev`)
        - traefik.http.routers.stocks_ml-http.entrypoints=http
        - traefik.http.routers.stocks_ml-http.middlewares=https-redirect
        # HTTPS (port 443)
        - traefik.http.routers.stocks_ml-https.rule=Host(`stocksmldemo.mccarthysean.dev`)
        - traefik.http.routers.stocks_ml-https.entrypoints=https
        - traefik.http.routers.stocks_ml-https.tls=true
        - traefik.http.routers.stocks_ml-https.tls.certresolver=le
        # Application-specific port
        - traefik.http.services.stocks_ml.loadbalancer.server.port=5000

  timescale:
    image: timescale/timescaledb:latest-pg12
    volumes: 
      - type: volume
        # source: timescale-db # the volume name
        source: timescale_volume
        target: /var/lib/postgresql/data # the location in the container where the data are stored
        read_only: false
      # Custom postgresql.conf file will be mounted (see command: as well)
      - type: bind
        source: ./postgresql_custom.conf
        target: /postgresql_custom.conf
        read_only: false
    env_file: .env
    command: ["-c", "config_file=/postgresql_custom.conf"]
    # Use the following 0.0.0.0 host if you want to access the database from a local PGAdmin,
    # and the TimescaleDB is on a remote server
    ports:
      - 0.0.0.0:5432:5432
    networks:
      timescale_network:
    healthcheck:
      # Periodically check if PostgreSQL is ready, for Docker status reporting
      # NOTE: This healthcheck only works on PostgreSQL version 12, not 11
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 60s
      timeout: 5s
      retries: 5
    deploy:
      # Either global (exactly one container per physical node) or
      # replicated (a specified number of containers). The default is replicated
      mode: replicated
      # For stateless applications using "replicated" mode,
      # the total number of replicas to create
      replicas: 1
      placement:
        constraints:
          # Since this is for the stateful database,
          # only run it on the swarm manager, not on workers
          - "node.role==manager"
      restart_policy:
        condition: on-failure

  backup:
    image: mccarthysean/timescaledb_backup_s3:latest-12
    depends_on:
      - timescale
    env_file: .env
    environment:
      # Schedule this backup job with cron, to backup and
      # upload to AWS S3 at midnight every day
      SCHEDULE: '0 0 * * *'
      # The AWS S3 bucket to which the backup file should be uploaded
      S3_BUCKET: ijack-backup-timescaledb
      # S3_PREFIX creates a sub-folder in the above AWS S3 bucket
      S3_PREFIX: stocks_ml_backup
      # EXTRA OPTIONS #######################################################################
      # --format custom outputs to a custom-format archive suitable for input into pg_restore
      # Together with the directory output format, this is the most flexible output format
      # in that it allows manual selection and reordering of archived items during restore.
      # This format is also compressed by default
      # "--create --clean" drops the database and recreates it
      # --if-exists adds "IF EXISTS" to the SQL where appropriate
      # --blobs includes large objects in the dump
      # --disable-triggers instructs pg_restore to execute commands to temporarily disable triggers
      # on the target tables while the data is reloaded. Use this if you have referential integrity
      # checks or other triggers on the tables that you do not want to invoke during data reload
      POSTGRES_BACKUP_EXTRA_OPTS: '--format custom --create --clean --if-exists --blobs'
      POSTGRES_RESTORE_EXTRA_OPTS: '--format custom --create --clean --if-exists --jobs 2 --disable-triggers'
    networks:
      timescale_network:
    healthcheck:
      # Periodically check if PostgreSQL is ready in the other container,
      # for Docker status reporting. If we can't reach it, we can't back it up.
      test: ["ping", "timescale"]
      interval: 60s
      timeout: 5s
      retries: 5
    deploy:
      # Either global (exactly one container per physical node) or
      # replicated (a specified number of containers). The default is replicated
      mode: replicated
      # For stateless applications using "replicated" mode,
      # the total number of replicas to create
      replicas: 1
      placement:
        constraints:
          # Since this is for the stateful database,
          # only run it on the swarm manager, not on workers
          - "node.role==manager"
      restart_policy:
        condition: on-failure

# Creates a named volume to persist our database data
volumes:
  timescale_volume:

networks:
  # For the TimescaleDB database
  timescale_network:
    external: true

  # For the Traefik web server
  traefik-public:
    external: true
```

That's it! I really hope you've enjoyed the course and learned a few things along the way. Here's what we accomplished:

1. Setup a great TimescaleDB database with PGAdmin for administration and automatic backups to an AWS S3 bucket
2. Integrated Flask and Dash into a first class interactive Python web app that uses the best functionalities from each package
3. Did some end-to-end machine learning in a Jupyter Notebook, including exploratory data analysis, feature engineering, hyper-parameter tuning, cross-validation time series testing, and model comparison
4. Ported our machine learning models to our Dash web app for our users to experiment with
5. Tested our Flask and Dash functionalities for quality assurance
6. Deployed our app to production with Traefik and Docker Swarm

All the best,<br>
Sean McCarthy


{% include end_to_end_ml_table_of_contents.html %}
