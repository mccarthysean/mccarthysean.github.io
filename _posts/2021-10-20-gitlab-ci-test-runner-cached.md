---
layout: post
title: 'Custom Gitlab CI/CD Test Runner, Cached for Speed'
tags: [Gitlab, CI/CD, DevOps, Docker, Python, Pytest, FastAPI]
featured: False
hidden: false
---
{% include image-caption.html imageurl="/assets/images/posts/2021/gitlab-ci-runner-logo.png#small" title="Gitlab CI Runner" caption="Gitlab CI Runner Logo" %}

In this article, we'll create a custom Gitlab CI runner, with a sidecar Docker-in-Docker container for building and caching Docker images. 

There are many tutorials and resources for running CI/CD jobs with Gitlab CI, but none that show how to run unit tests with Docker Compose, and very few that show exactly how to cache Docker images between Gitlab CI jobs so that Docker doesn't have to keep pulling new images from Docker Hub, slowing down your builds and using up your Docker Hub quota. 

Benefits of this setup:
1. Don't use up Gitlab CI shared runner minutes
2. Keep your secret data locked down
3. Cache Docker images for speed and efficiency

Let's bootstrap a Python FastAPI setup that uses Docker Compose and Pytest. 

```
# Insert your Gitlab repository URL here (e.g. https://gitlab.com/mccarthysean):
export MY_GITLAB=

# Insert your new repo name here (e.g. gitlab_test_runner)
export NEW_REPO=

# Clone the repository we're going to use/copy
git clone --bare https://github.com/testdrivenio/fastapi-crud-async.git

# Change into the newly-created directory
cd fastapi-crud-async.git

# Now push a copy of the repo to our own Gitlab repository.
# If it fails the first time, try again and it should work.
git push --mirror $MY_GITLAB/$NEW_REPO

# Exit the "bare" folder and remove it
cd ..
rm -rf fastapi-crud-async.git

# Clone your new repo into the folder
git clone $MY_GITLAB/$NEW_REPO
```

Next let's add the following ".gitlab-ci.yml" Gitlab CI config file, defining our image-building and testing jobs:

```sh
touch .gitlab-ci.yml
```

```yml
# Default Docker image to use for running our stages
image:
  # Includes Docker Compose
  name: docker/compose:1.29.2
  # Override the entrypoint (important)
  entrypoint: [""]

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

