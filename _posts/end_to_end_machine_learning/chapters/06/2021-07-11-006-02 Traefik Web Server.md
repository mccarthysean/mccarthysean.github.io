---
layout: post
title: Traefik Web Server for Docker Swarm
# slug: traefik-web-server-for-docker-swarm
chapter: 2
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


Now that you've got your cloud-based server setup (AWS EC2, Digital Ocean, Linode, Azure, Heroku, etc), ensure you've got Docker installed. 

[Here](https://docs.docker.com/engine/install/) are some good instructions for installing Docker.

You'll probably want to install Docker-Compose as well, although we're going to be using Docker Swarm here. Instructions [here](https://docs.docker.com/compose/install/).

In terms of server security, ensure your server allows incoming TCP traffic on ports 80 (insecure HTTP) and 443 (secure HTTPS). If you're using an AWS EC2 server, [here's a guide](https://aws.amazon.com/premiumsupport/knowledge-center/connect-http-https-ec2/).

Now we're ready to fire up the [Traefik](https://traefik.io/) web server, which will serve your website on port 443 with HTTPS. Traefik will take care of all the HTTPS stuff by generating security certificates and private keys for you, from time to time (they must be renewed periodically). Traefik uses LetsEncrypt behind the scenes, and besides supporting Docker Swarm out-of-the-box, having HTTPS automatically setup and renewed is my favourite Traefik feature!

This Traefik setup guide borrows heavily from this awesome resource:
https://dockerswarm.rocks/traefik/

I'm a big fan of Sebastián Ramírez, the creator of the popular FastAPI and Typer packages. He's been an amazing contributor to the open source Python community. 

If you haven't done so already, put Docker in "swarm mode".
`docker swarm init`
	
The above creates the [default ingress overlay network](https://docs.docker.com/network/overlay/#customize-the-default-ingress-network) which is used by swarm services by default.	

Create a network that will be shared with Traefik and the other containers:
`docker network create --scope=swarm --driver=overlay --attachable --opt encrypted traefik-public`

Get the Swarm node ID of this node and store it in an environment variable `NODE_ID`:
{% raw %}
`export NODE_ID=$(docker info -f '{{.Swarm.NodeID}}')`
{% endraw %}

Create a tag in this node, so that Traefik is always deployed to the same node and uses the same volume:
`docker node update --label-add traefik-public.traefik-public-certificates=true $NODE_ID`

Create an environment variable with your email, to be used for the generation of Let's Encrypt certificates, e.g.:
`export EMAIL=your@email.com`

Create an environment variable with the domain you want to use for the Traefik UI (user interface), e.g.:
`export DOMAIN=traefik.example.com`

Create an environment variable with a username (you will use it for the HTTP Basic Auth for Traefik and Consul UIs), for example:
`export USERNAME=admin`

Create an environment variable with the password, e.g.:
`export PASSWORD=changethis`

Use openssl to generate the "hashed" version of the password and store it in an environment variable:
`export HASHED_PASSWORD=$(openssl passwd -apr1 $PASSWORD)`

You can check the contents with:
`echo $HASHED_PASSWORD`

Now that you've setup all the required environment variables, and the `traefik-public` Docker network, it's time to deploy Traefik with Docker. Following is the `docker-compose.traefik.yml` file you'll use.

Then deploy Traefik to the swarm with the following command:
`docker stack deploy -c docker-compose.traefik.yml traefik`

The yaml file uses the environment variables we created above, such as DOMAIN, EMAIL, HASHED_PASSWORD, etc.

```dockerfile
version: '3.3'

services:        
  traefik:
    # Use the latest Traefik image
    image: traefik:v2.2
    ports:
      # If you need to read the client IP in your applications/stacks using the 
      # X-Forwarded-For or X-Real-IP headers provided by Traefik, you need to make 
      # Traefik listen directly, not through Docker Swarm mode, even while being 
      # deployed with Docker Swarm mode. For that, you need to publish the ports using "host" mode.
      # Listen on port 80, default for HTTP, necessary to redirect to HTTPS
      - target: 80
        published: 80
        # We need to publish the ports using "host" mode.
        mode: host
      # Listen on port 443, default for HTTPS
      - target: 443
        published: 443
        # We need to publish the ports using "host" mode.
        mode: host
    deploy:
      placement:
        constraints:
          # Make the traefik service run only on the node with this label
          # as the node with it has the volume for the certificates
          - node.labels.traefik-public.traefik-public-certificates == true
      labels:
        # Enable Traefik for this service, to make it available in the public network
        - traefik.enable=true
        # Use the traefik-public network (declared below)
        - traefik.docker.network=traefik-public
        # Use the custom label "traefik.constraint-label=traefik-public"
        # This public Traefik will only use services with this label
        # That way you can add other internal Traefik instances per stack if needed
        - traefik.constraint-label=traefik-public
        # admin-auth middleware with HTTP Basic auth
        # Using the environment variables USERNAME and HASHED_PASSWORD
        - traefik.http.middlewares.admin-auth.basicauth.users=${USERNAME?Variable not set}:${HASHED_PASSWORD?Variable not set}
        # https-redirect middleware to redirect HTTP to HTTPS
        # It can be re-used by other stacks in other Docker Compose files
        - traefik.http.middlewares.https-redirect.redirectscheme.scheme=https
        - traefik.http.middlewares.https-redirect.redirectscheme.permanent=true

        # traefik-http set up only to use the middleware to redirect to https
        # Uses the environment variable DOMAIN
        - traefik.http.routers.traefik-public-http.rule=Host(`${DOMAIN?Variable not set}`)
        - traefik.http.routers.traefik-public-http.entrypoints=http
        - traefik.http.routers.traefik-public-http.middlewares=https-redirect

        # traefik-https the actual router using HTTPS
        # Uses the environment variable DOMAIN
        - traefik.http.routers.traefik-public-https.rule=Host(`${DOMAIN?Variable not set}`)
        - traefik.http.routers.traefik-public-https.entrypoints=https
        - traefik.http.routers.traefik-public-https.tls=true

        # Use the special Traefik service api@internal with the web UI/Dashboard
        - traefik.http.routers.traefik-public-https.service=api@internal
        # Use the "le" (Let's Encrypt) resolver created below
        - traefik.http.routers.traefik-public-https.tls.certresolver=le
        # Enable HTTP Basic auth, using the middleware created above
        - traefik.http.routers.traefik-public-https.middlewares=admin-auth
        # Define the port inside of the Docker service to use
        - traefik.http.services.traefik-public.loadbalancer.server.port=8080
    volumes:
      # Add Docker as a mounted volume, so that Traefik can read the labels of other services
      - /var/run/docker.sock:/var/run/docker.sock:ro
      # Mount the volume to store the certificates
      - traefik-public-certificates:/certificates
      # # Custom configuration, if needed (otherwise uses "command:" below)
      # - ./traefik/traefik.toml:/etc/traefik/traefik.toml:ro
    command:
      # Enable Docker in Traefik, so that it reads labels from Docker services
      - --providers.docker
      # Add a constraint to only use services with the label "traefik.constraint-label=traefik-public"
      - --providers.docker.constraints=Label(`traefik.constraint-label`, `traefik-public`)
      # Do not expose all Docker services, only the ones explicitly exposed
      - --providers.docker.exposedbydefault=false
      # Enable Docker Swarm mode
      - --providers.docker.swarmmode
      # Create an entrypoint "http" listening on port 80
      - --entrypoints.http.address=:80
      # Create an entrypoint "https" listening on port 443
      - --entrypoints.https.address=:443

      # Create the certificate resolver "le" for Let's Encrypt, uses the environment variable EMAIL
      - --certificatesresolvers.le.acme.email=${EMAIL?Variable not set}
      # Store the Let's Encrypt certificates in the mounted volume
      - --certificatesresolvers.le.acme.storage=/certificates/acme.json
      # Use the TLS Challenge for Let's Encrypt
      - --certificatesresolvers.le.acme.tlschallenge=true
      # Enable the access log, with HTTP requests
      - --accesslog
      # Enable the Traefik log, for configurations and errors
      - --log
      # Enable the Dashboard and API
      - --api
    networks:
      # Use the public network created to be shared between Traefik and
      # any other service that needs to be publicly available with HTTPS
      - traefik-public

volumes:
  # Create a volume to store the certificates, there is a constraint to make sure
  # Traefik is always deployed to the same Docker node with the same volume containing
  # the HTTPS certificates
  traefik-public-certificates:

networks:
  # Use the previously created public network "traefik-public", shared with other
  # services that need to be publicly available via this Traefik
  traefik-public:
    external: true
```

If you need to remove the Traefik stack...
`docker stack rm traefik`
	
Detach Traefik from the Docker network, if need be... First find the Docker container ID with `docker ps`.
`docker network disconnect traefik-public <CONTAINER>`

Check if the stack was deployed with:
`docker stack ps traefik`

The output will look something like this:
```bash
ID             NAME                IMAGE          NODE              DESIRED STATE   CURRENT STATE          ERROR   PORTS
w5o6fmmln8ni   traefik_traefik.1   traefik:v2.2   dog.example.com   Running         Running 1 minute ago
```

You can check the Traefik logs with:
`docker service logs traefik_traefik`

Next up, setting up our web app for deployment with Gunicorn and Traefik.


{% include end_to_end_ml_table_of_contents.html %}
