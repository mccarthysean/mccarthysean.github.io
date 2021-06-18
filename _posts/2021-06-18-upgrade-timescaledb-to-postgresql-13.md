---
layout: post
title: 'Upgrade TimescaleDB from PostgreSQL 11 to PostgreSQL 13 with Docker'
tags: [TimescaleDB, Docker, PostgreSQL, Linux, psql]
featured_image_thumbnail:
# featured_image: assets/images/posts/2021/timescaledb-logo2.png
featured: false
hidden: false
---
{% include image-caption.html imageurl="/assets/images/posts/2021/timescaledb-logo2.png#small" title="TimescaleDB Logo" caption="TimescaleDB Logo" %}

The past few days I've been trying to update my version of TimescaleDB from v1.6.0 to v2.3.0 (see yesterday's post on [updating the TimescaleDB extension]({% post_url 2021-06-17-update-timescaledb-extension-with-docker %})), while also upgrading PostgreSQL from v11 to v13, since TimescaleDB v2.3.0 doesn't support Postgres 11 anymore.

This second post is about how I managed to upgrade PostreSQL to v13 from v11 while preserving all my data (which is saved in a Docker volume).

Here are the [official instructions](https://docs.timescale.com/timescaledb/latest/how-to-guides/update-timescaledb/upgrade-postgresql/) for upgrading PostgreSQL. All they tell you is to use pg_upgrade. However, that's got its own complications, and I didn't want the database to be down for any length of time, so instead I backed up our existing database, then created a new PostgreSQL 13 database with a new Docker volume, and restored the backup to the new database. Following are my steps.

Here's a [link]({% post_url 2021-06-17-backup-restore-timescaledb-database %}) to my previous post on how to automatically backup a TimescaleDB database each night to an AWS S3 bucket, using a custom Docker image I created. Follow those steps to create a backup in an AWS S3 bucket.

Next I created a brand new "docker-compose.prod13.yml" file for my PostgreSQL v13 database. 

Before I executed it, I also created a separate volume for PostgreSQL 13:
```shell
$ docker volume create timescale-db-pg13
```

Here's the yaml file:

```yaml
version: '3.7'
services:
  timescale13:
    # Name of the image and tag the Dockerfile creates
    image: timescale/timescaledb:2.3.0-pg13
    volumes: 
      - type: volume
        # source: timescale-db # the volume name
        source: timescale-db-pg13
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

  # Custom backup container that automatically sends backups to AWS S3 each night
  backup13:
    image: mccarthysean/timescaledb_backup_s3:13-1.0.8
    depends_on: 
      - timescale13
    env_file: .env
    environment:
      # This takes precedence over the env_file
      POSTGRES_HOST: timescale13
      # Schedule this backup job to backup and upload to AWS S3 every so often
      # * * * * * command(s)
      # - - - - -
      # | | | | |
      # | | | | ----- Day of week (0 - 7) (Sunday=0 or 7)
      # | | | ------- Month (1 - 12)
      # | | --------- Day of month (1 - 31)
      # | ----------- Hour (0 - 23)
      # ------------- Minute (0 - 59)
      SCHEDULE: '0 7 * * *'
      # The AWS S3 bucket to which the backup file should be uploaded
      S3_BUCKET: ijack-backup-timescaledb
      # S3_PREFIX creates a sub-folder in the above AWS S3 bucket
      S3_PREFIX: myijack_timescaledb_backup
    networks:
      traefik-public:
    healthcheck:
      # Periodically check if PostgreSQL is ready, for Docker status reporting
      test: ["ping", "-c", "1", "timescale"]
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

# Use a named external volume to persist our data
volumes:
  timescale-db-pg13:
    external: true

networks:
  # Use the previously created public network "traefik-public", shared with other
  # services that need to be publicly available via this Traefik
  traefik-public:
    external: true
```

I deployed the above stack to my `traefik-public` network with:
```shell
$ docker stack deploy --with-registry-auth -c docker-compose.prod13.yml timescale13
```

Then I had two TimescaleDB databases running--the second of which (PG13) was empty and fresh.

First I created the database in the new PG13 container using psql:
```shell
$ docker exec -it timescale13_timescale13 psql -X -U postgres
```
```sql
postgres=# create database mydb;
postgres=# \list
postgres=# exit
```

After creating the database to which I wanted to restore everything, I created a fresh backup of my PostgreSQL v11 database by going into the new `backup13` container I just created and running the following:
```shell
$ docker exec -it timescale13_backup13
$ export POSTGRES_HOST=timescale11
$ bash /backup.sh
```

Running the above backup and uploading its 2.4 GB to AWS S3 took about ~20 minutes, as it does each night when it runs automatically. After it finished, I ran the following to download and restore the backup to my new PostgreSQL v13 database, into its new Docker volume:
```shell
$ docker exec -it timescale13_backup13
$ export POSTGRES_HOST=timescale13
$ bash /download_backup_from_AWS_S3.sh
$ bash /restore.sh
```

The above restore operation took about twice as long (~40 minutes for a 2.4 GB-sized backup file) as the backup operation, but it was worth it because my original database was running the whole time so there was no disruption in the web app service that depends on the database.

Cheers, <br>
Sean