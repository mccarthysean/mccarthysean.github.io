---
layout: post
title: 'Update TimescaleDB Extension with Docker'
tags: [TimescaleDB, Docker, PostgreSQL, Linux, psql]
featured_image_thumbnail:
featured_image: assets/images/posts/2021/timescaledb-logo2.png
featured: true
hidden: true
---

I really like TimescaleDB as a PostgreSQL-based time series database, and I especially love installing it in Docker containers, just like I would with PostgreSQL. However, I had some trouble updating the TimescaleDB extension version in Docker, so I thought I'd share my solution in case someone else needs it.

My problem was that after updating my "docker-compose.yml" file to use the latest TimescaleDB version (v2.3.0 at the time of writing), I got the following error when I tried to do database operations. Previously I was using TimescaleDB v1.6.0.
```
ERROR:  could not access file "$libdir/timescaledb-1.6.0": No such file or directory
```

Here are the [official instructions](https://docs.timescale.com/timescaledb/latest/how-to-guides/update-timescaledb/updating-docker/#updating-a-timescaledb-docker-installation) for updating the TimescaleDB extension.

Here's a super-helpful [StackOverflow answer](https://stackoverflow.com/a/57556005/3385948).

First ensure you've got the latest Docker image installed:
```shell
docker pull timescale/timescaledb:latest-pg12
```

Start the container as you've done before, whether you're using `docker run ...` or `docker-compose up -d --build`... 

Here's my "docker-compose.yml" file:
```yml
version: '3.7'
services:
  timescale:
    # Name of the image and tag the Dockerfile creates (update this as needed)
    # image: timescale/timescaledb:1.6.0-pg12
    image: timescale/timescaledb:latest-pg12
    volumes: 
      # Main TimescaleDB external volume
      - type: volume
        # source: timescale-db # the volume name
        source: timescale-db-volume
        # source: project_timescale-db
        target: /var/lib/postgresql/data # the location in the container where the data are stored
        read_only: false
      # Custom postgresql.conf file will be mounted (see command: as well)
      - type: bind
        source: ./postgresql_custom.conf
        target: /postgresql_custom.conf
        read_only: false
    env_file: .env
    command: ["-c", "config_file=/postgresql_custom.conf"]
    ports: 
      - 0.0.0.0:5432:5432
    networks:
      traefik-public:
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

# Uses a named volume to persist our data
volumes:
  timescale-db-volume:
    external: true

networks:
  # Use the previously created public network "traefik-public", shared with other
  # services that need to be publicly available via this Traefik
  traefik-public:
    external: true
```

Connect to the running Docker container and start psql immediately:
```shell
docker exec -it <container> psql -X -U postgres
```

Connect to the database you want to update (e.g. for a DB called "mydb") to update its TimescaleDB extension. **This step was missing in the [official documentation](https://docs.timescale.com/timescaledb/latest/how-to-guides/update-timescaledb/updating-docker/#updating-a-timescaledb-docker-installation).**
```sql
postgres=# \c mydb
You are now connected to database "mydb" as user "postgres".
```

Alternately, connect directly to the chosen database *on startup*:
```shell
docker exec -it <container> psql -X -U postgres -d mydb
```

Update the extension:
```sql
mydb=# ALTER EXTENSION timescaledb UPDATE;
ALTER EXTENSION
```
 
Check the version now!
```sql
mydb=# SELECT default_version, installed_version FROM pg_available_extensions where name = 'timescaledb';
 default_version | installed_version
-----------------+-------------------
 2.3.0           | 2.3.0
(1 row)
```

TimescaleDB should be updated and working fine now. :)

Cheers,
Sean