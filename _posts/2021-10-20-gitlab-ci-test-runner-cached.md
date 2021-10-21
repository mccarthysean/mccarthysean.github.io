---
layout: post
title: 'Custom Gitlab CI/CD Runner, Cached for Speed with Docker-in-Docker'
tags: [Gitlab, CI/CD, DevOps, Docker, Python, Pytest, FastAPI]
featured: False
hidden: false
---
{% include image-caption.html imageurl="/assets/images/posts/2021/gitlab-ci-runner-logo.png#small" title="Gitlab CI Runner" %}

In this article, we'll create a custom Gitlab CI runner, with a sidecar Docker-in-Docker container for building and caching Docker images. 

There are many tutorials and resources for running CI/CD jobs with Gitlab CI, but none that show how to run unit tests with Docker Compose, and very few that show exactly how to cache Docker images between Gitlab CI jobs so that Docker doesn't have to keep pulling new images from Docker Hub, slowing down your builds and using up your Docker Hub quota. 

Benefits of this setup:
1. Don't use up Gitlab CI shared runner minutes
2. Keep your secret data locked down
3. Cache Docker images for speed and efficiency

Let's bootstrap a Python FastAPI setup that uses Docker Compose and Pytest. 

Insert your Gitlab repository URL here (e.g. https://gitlab.com/mccarthysean):
```sh
export MY_GITLAB=
```

Insert your new repo name here (e.g. gitlab_test_runner)
```sh
export NEW_REPO=
```

Clone the repository we're going to use/copy
```sh
git clone --bare https://github.com/testdrivenio/fastapi-crud-async.git
```

Change into the newly-created directory
```sh
cd fastapi-crud-async.git
```

Now push a copy of the repo to our own Gitlab repository. If it fails the first time, try again and it should work.
```sh
git push --mirror $MY_GITLAB/$NEW_REPO
```

Exit the "bare" folder and remove it
```sh
cd ..
rm -rf fastapi-crud-async.git
```

Clone your new repo into the folder
```sh
git clone $MY_GITLAB/$NEW_REPO
```

Next let's add the following ".gitlab-ci.yml" Gitlab CI config file, defining our image-building and testing jobs:

```sh
cd $NEW_REPO
touch .gitlab-ci.yml
```

```yml
# Default Docker image to use for running our stages
image:
  # Includes Docker Compose
  name: docker/compose:1.29.2
  # Override the entrypoint (important)
  entrypoint: [""]

# Add another Docker image, which will start up at the same time
# as the above Docker Compose image. This is "Docker-in-Docker",
# and when your script includes a `docker` command, it'll run inside
# this container.
services:
  - name: docker:dind
    alias: dind

# Job stages
stages:
  - build
  - test
  # - deploy

# Global variables available in the Docker job containers
variables:
  # Disable TLS since we're running inside local network.
  DOCKER_TLS_CERTDIR: "" # No TLS
  # DOCKER_HOST is essential. It tells docker CLI how to talk to Docker daemon.
  DOCKER_HOST: tcp://dind:2375 # No TLS
  # Use the overlayfs driver for improved performance.
  DOCKER_DRIVER: overlay2

  # Use Docker BuildKit for better caching and faster builds
  DOCKER_BUILDKIT: 1
  BUILDKIT_INLINE_CACHE: 1
  COMPOSE_DOCKER_CLI_BUILD: 1

  # What to call, and where to push, the resulting Docker images
  IMAGE_BASE: $CI_REGISTRY/$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME
  IMAGE: $IMAGE_BASE:my_image

# Do the following before each job
before_script:
  # First test that gitlab-runner has access to Docker
  - docker info
  # Install bash in the Alpine image
  - apk add --no-cache bash
  # Login to the Gitlab registry
  - docker login -u $CI_REGISTRY_USER -p $CI_JOB_TOKEN $CI_REGISTRY

# The first "build" stage
build:
  stage: build
  script:
    # Build and push the image to the Gitlab image repo, with Docker and BuildKit
    - docker-compose build
    - docker push $IMAGE

# The second "test" stage
test:
  stage: test
  script:
    # Start the containers in the background,
    # using the cached images built in the previous "build" step
    - docker-compose up -d
    # Find the Docker Compose service (container) called "web", which contains pytest
    - export CONTAINER_ID=$(docker-compose ps -q web)
    # Look at the containers we started
    - docker ps
    # Optional: wait until the container is up
    - until [ "`docker inspect -f {{.State.Running}} $CONTAINER_ID`"=="true" ]; do sleep 0.1; done;
    # Key step: run our unit tests with pytest
    - docker exec --tty $CONTAINER_ID pytest
  allow_failure: false
```

Before we can kick off this CI/CD pipeline at Gitlab using their "shared runners", we have to modify the "docker-compose.yml" file so that it builds and caches the `$IMAGE` defined in our ".gitlab-ci.yml" config file, as follows:
```yml
version: '3.8'

services:
  web:
    build:
      # New!
      context: ./src
      cache_from:
        - $IMAGE
    image: $IMAGE
    command: |
      bash -c 'while !</dev/tcp/db/5432; do sleep 1; done; uvicorn app.main:app --reload --workers 1 --host 0.0.0.0 --port 8000'
    volumes:
      - ./src/:/usr/src/app/
    ports:
      - 8002:8000
    environment:
      - DATABASE_URL=postgresql://hello_fastapi:hello_fastapi@db/hello_fastapi_dev
  db:
    image: postgres:13-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data/
    expose:
      - 5432
    environment:
      - POSTGRES_USER=hello_fastapi
      - POSTGRES_PASSWORD=hello_fastapi
      - POSTGRES_DB=hello_fastapi_dev

volumes:
  postgres_data:

```

## Run the jobs

Believe it or not, your Gitlab CI pipeline is ready for its first test! As soon as we push your new ".gitlab-ci.yml" and "docker-compose.yml" files to your Gitlab repo, Gitlab will automatically start a pipeline of your "build" and "test" jobs. 

Let's add all the files in the directory:
```sh
git add .
```

Now commit them with a message:
```sh
git commit -m "Added Gitlab CI/CD file, and modified docker-compose.yml"
```

Finally, push the changes to your remote (online) Gitlab repo:
```sh
git push
```

Now you can (and should!) view them under "CI/CD" and then "Pipelines". 

![Gitlab CI Pipeline](./assets/images/posts/2021/gitlab-pipeline-build-test-jobs.jpg#wide)

Click on the "build" stage icon in Gitlab, then click again, and it will take you to the "Jobs" page, where you can watch the action in real time... Wait patiently until both jobs/stages ("build" and "test") complete successfully.

## Deploy a custom Gitlab runner

By "real time" I mean slooooowww time. We're currently setup to use Gitlab CI's "shared runners", which are quite slow. Plus, you only get so many minutes of free CI/CD job time each month. 

Let's speed it up by deploying and registering our own custom Gitlab runner. Then we can also cache our images, which will further speed things up. The shared runners have to build them from scratch every time, unless you first pull the remote image. 

Create another compose file for our custom Gitlab runner, "docker-compose.runner.yml":
```yml
version: '3.8'

services:
  gitlab_runner:
    image: gitlab/gitlab-runner:alpine-v14.3.2
    container_name: gitlab_runner
    env_file: .env
    # There is NO need for this container to have root privileges!
    # privileged: true
    environment:
      # REGISTRATION_TOKEN and GITLAB_URL are needed for manually registering runners
      # REGISTRATION_TOKEN is in .env file
      GITLAB_URL: https://gitlab.com/
      DOCKER_HOST: tcp://dind:2375 # No TLS
      # Disable Docker TLS validation
      DOCKER_TLS_CERTDIR: "" # No TLS
    volumes:
      - runner_config_volume:/etc/gitlab-runner:Z
    restart: unless-stopped
  
volumes:
  # For persisting the config with the registered runners
  runner_config_volume:
    name: runner_config_volume
```

The above file will create our own Gitlab runner Docker container. It just needs us to create a ".env" file with our `REGISTRATION_TOKEN`, which gives us permission to access this repository at Gitlab.

The `REGISTRATION_TOKEN` is under the repository "Settings" then "CI/CD". Expand the "Runners" you'll see it under "Specific Runners"

![Gitlab CI Runner Registration Token](./assets/images/posts/2021/gitlab-runner-registration-token.jpg)

Create a ".env" file and add the following, with your own unique registration token:
```sh
REGISTRATION_TOKEN=super-secret-token
```

Modify the ".gitignore" file so that git doesn't push your secret ".env" file to the repo, as follows:
```sh
__pycache__
env
# NEW!
.env
```

Let's fire it up locally in the background, and register it with Gitlab!
```sh
docker-compose -f docker-compose.runner.yml up -d --build
```

Check to see that it's running:
```sh
docker ps
```

Now we have to register the runner with Gitlab.com so it's available to run our jobs. Enter the already-running, daemonized container:
```sh
docker exec -it gitlab_runner bash
```

Check that the `$REGISTRATION_TOKEN` variable is set properly through your ".env" file:
```sh
echo $REGISTRATION_TOKEN
```

Now for a really long command to register and configure the runner with Gitlab.com. Copy and paste the following, and run it inside the Gitlab Runner container you've just entered:
```sh
gitlab-runner --debug register \
    --non-interactive \
    --url $GITLAB_URL \
    --registration-token $REGISTRATION_TOKEN \
    --executor docker \
    --description "My Custom Docker Runner" \
    --docker-image "docker:stable" \
    --tag-list "dind,fastapi" \
    --run-untagged=true \
    --locked=false \
    --docker-privileged=true \
    --docker-tlsverify=false \
    --docker-host "tcp://dind:2375" \
    --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
    --docker-volumes "/cache" \
    --docker-volumes "/builds:/builds" \
    --access-level "not_protected" \
    --docker-network-mode "host"
```

Refresh the Gitlab.com "Settings/CI/CD" page and you'll see your runner under "Runners/Available specific runners". Congrats, you've just created and registered your own custom Gitlab CI runner. Now your CI/CD jobs will run much faster and more securely. 

You can now disable the Gitlab.com "Shared runners" since you have your own, faster runner.

Go back into "CI/CD/Jobs" and click on one of your stages (either "build" or "test"), to where you see the Bash script output, and click on "Retry" to run it again, this time using your own custom runner. 

## Now make it faster

We now have our own custom Gitlab runner, which is much faster than the Gitlab.com shared runners. This is where most people stop. But we can make it faster still with image caching. And we can use less Docker Hub quota and network bandwidth. 

We do this by adding our own Docker-in-Docker (dind) service container, instead of having Gitlab runner automatically create a new one for each build stage/job. This way we can save the Docker-in-Docker downloaded and built images in its own persisted Docker volume.

In your ".gitlab-ci.yml" config file, remove the following section. We're going to create our own "dind" container.

```yml

# Add another Docker image, which will start up at the same time
# as the above Docker Compose image. This is "Docker-in-Docker",
# and when your script includes a `docker` command, it'll run inside
# this container.
services:
  - name: docker:dind
    alias: dind
```

Let's add another container, volume, and network to our "docker-compose.runner.yml" file:

```yml
version: '3.8'

services:
  # NEW!
  # dind and the runner are started on the host docker daemon and linked together.
  # dind is used by the runner to start the jobs (environment: DOCKER_HOST: tcp://dind:2375).
  # dind's docker.sock is mounted into the Gitlab Runner-created job containers (--docker-volumes /var/run/docker.sock:/var/run/docker.sock)
  # in the runner registration setup step, so they can use docker commands.
  # As long as the dind volume is not deleted, the docker cache persists between jobs on this runner.
  dind:
    image: docker:20.10.10-rc1-dind-alpine3.14
    container_name: gitlab_runner_dind
    # Root user privileges required for dind container to work
    privileged: true
    environment:
      DOCKER_DRIVER: overlay2
      DOCKER_HOST: tcp://0.0.0.0:2375
      # Disable Docker TLS validation
      DOCKER_TLS_CERTDIR: ""
    networks:
      - gitlab_runner_network
    volumes:
      # For persisting the image cache, to speed up CI/CD jobs
      - dind_volume:/var/lib/docker
    restart: unless-stopped

  gitlab_runner:
    image: gitlab/gitlab-runner:alpine-v14.3.2
    container_name: gitlab_runner
    env_file: .env
    # There is NO need for this container to have root privileges!
    # privileged: true
    environment:
      # REGISTRATION_TOKEN and GITLAB_URL are needed for manually registering runners
      # REGISTRATION_TOKEN is in .env file
      GITLAB_URL: https://gitlab.com/
      DOCKER_HOST: tcp://dind:2375 # No TLS
      # Disable Docker TLS validation
      DOCKER_TLS_CERTDIR: "" # No TLS
    volumes:
      - runner_config_volume:/etc/gitlab-runner:Z
    restart: unless-stopped
    # NEW!
    networks:
      - gitlab_runner_network
    depends_on:
      - dind
    # Legacy link to service with hostname "dind" and alias "docker".
    # This is absolutely necessary.
    links:
      - dind:docker
  
volumes:
  # For persisting the config with the registered runners
  runner_config_volume:
    name: runner_config_volume
  # NEW!
  # For cached Docker images
  dind_volume:
    name: gitlab_runner_dind_volume
  
# NEW!
networks:
  gitlab_runner_network:
    driver: overlay
    name: gitlab_runner_network
```

Rebuild with Docker Compose. Your runner will still be registered because of the persisted `runner_config_volume`.
```sh
docker-compose -f docker-compose.runner.yml up -d --build
```

Check that you now have two containers--the runner, and the "dind" Docker-in-Docker service container:
```sh
docker ps
```

Go back into your CI/CD pipeline, or jobs, and restart the job. Either that, or push a superficial change to your Gitlab repo, to trigger a new pipeline of jobs. 

Your job should now be running through both:
1. Your custom Gitlab runner
2. Your dind Docker-in-Docker service container

The "build" job will take longer this time because it will reinstall the Python packages from scratch, but then the Docker-built image will be stored in the Docker-in-Docker container's persistent volume, so next time it will be *much* faster. Your "test" job should be lightning fast since it uses the cached images from the build job.

Let's go into the Docker-in-Docker "dind" container to check its cached images:
```sh
docker exec -it gitlab_runner_dind sh
docker image ls
```

You should see four newly-cached images, ready for your next CI/CD jobs:
1. gitlab_test_runner:my_image
1. postgres:13-alpine
1. gitlab-runner-helper:x86_64-...
1. docker/compose:1.29.2

In this tutorial, you've learned:
1. How to run a Gitlab CI/CD jobs pipeline
1. How to use pytest to run unit tests with a Docker Compose container
1. How to create your own custom Gitlab runner
1. How to create your own Docker-in-Docker service container

Congrats, you now have the fastest, cheapest, most secure CI/CD pipeline around, using nothing but open source technology.

In case you didn't notice, you also have an [asynchronous FastAPI/PostgreSQL website](https://testdriven.io/blog/fastapi-crud/) up and running. Check out that tutorial next!

Run FastAPI locally (same as the Gitlab CI pipeline does) with (e.g. IMAGE=registry.gitlab.com/mccarthysean/gitlab_test_runner:my_image):
```sh
export IMAGE=
docker-compose up -d --build
```

Check out your FastAPI endpoints at [http://localhost:8002/docs](http://localhost:8002/docs).
