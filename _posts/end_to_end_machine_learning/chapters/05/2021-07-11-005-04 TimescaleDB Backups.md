---
layout: post
title: TimescaleDB Backups
# slug: timescaledb-backups
chapter: 4
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}


In this chapter we're going to automatically backup our TimescaleDB database to an AWS S3 bucket. Since we're running our own TimescaleDB database, it goes without saying we must have a backup strategy in case something goes wrong. I'm going to make that very easy for you, as you'll see. AWS S3 buckets are a very cheap, reliable, and convenient place to store files safely in the cloud, so that's what I've chosen to use. 

My simple solution is to add the following Docker service (container) to your `docker-compose.timescale.yml` file. This will start a Docker container alongside your TimescaleDB Docker container. 

I created this Docker image myself (see [GitHub](https://github.com/mccarthysean/TimescaleDB-Backup-S3) and [Docker Hub](https://hub.docker.com/repository/docker/mccarthysean/timescaledb_backup_s3)), and it uses the "somewhat official" TimescaleDB backup tool they've provided on their GitHub page [here](https://github.com/timescale/timescaledb-backup). It's pretty early in the development of this tool, but I've tested it and it works well in my production TimescaleDB database.

Below this, I'll show you my `.env` file as well, for the required passwords.

```dockerfile
  backup:
    # image: mccarthysean/timescaledb_backup_s3:latest-13
    image: mccarthysean/timescaledb_backup_s3:13-1.0.8    
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
      # Periodically check if PostgreSQL is ready, for Docker status reporting
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 60s
      timeout: 5s
      retries: 5
    deploy:
      placement:
        constraints:
          # Since this is for the stateful database,
          # only run it on the swarm manager, not on workers
          - "node.role==manager"
      restart_policy:
        condition: on-failure
```

Here's the `.env` file I use for the `mccarthysean/timescaledb_backup_s3:latest-13` Docker image:

```bash
# For the Postgres/TimescaleDB database. 
POSTGRES_HOST=timescale
POSTGRES_PORT=5432
POSTGRES_DATABASE=postgres
POSTGRES_USER=postgres
# POSTGRES_PASSWORD initializes the database password
POSTGRES_PASSWORD=
PGDATA=/var/lib/postgresql/data

# For TimescaleDB backups
# s3_bucket_backup_timescaledb AWS IAM user can only create TimescaleDB backups in a certain bucket
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
# Default region depends on your AWS account. Mine is "us-west-2" since I'm in western Canada
AWS_DEFAULT_REGION=us-west-2
```

I told you this would be a simple solution. Now you just need an AWS account for the following three environment variables in particular:
1. S3_BUCKET
2. AWS_ACCESS_KEY_ID
3. AWS_SECRET_ACCESS_KEY

To restore a backup file into a new Dockerized PostgreSQL database, run the following:
```shell
$ docker exec -it <database container>
$ export POSTGRES_HOST=timescale13
$ bash /download_backup_from_AWS_S3.sh
$ bash /restore.sh
```

The above restore operation takes about twice as long (~40 minutes for a 2.4 GB-sized backup file) as the backup operation, but it's worth it because the original database can stay running the whole time so there's no disruption in any services that depend on the database.

This chapter has given you a taste of what's to come in the next part on deployment to production (hint: it's Docker Swarm and Traefik).
