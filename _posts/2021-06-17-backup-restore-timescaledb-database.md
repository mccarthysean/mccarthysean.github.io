---
layout: post
title: 'Backup a TimescaleDB Database to an AWS S3 Bucket'
tags: [TimescaleDB, Docker, PostgreSQL, Linux, psql, AWS, S3]
featured_image_thumbnail:
featured_image: assets/images/posts/2021/timescaledb-logo2.png
featured: true
hidden: true
---

TimescaleDB is open source software, and they want you to pay for their premium hosted service. Fair enough. Normally I'd just pay the fee, as I do for AWS RDS managed PostgreSQL databases, but their hosted TimescaleDB service is *much* more expensive, so I decided to roll my own in a Docker container. That's easy enough, but I also needed an automated backup Docker service, to save a new backup to an AWS S3 bucket every night.

If you want to copy my strategy, create yourself an AWS S3 bucket (easy to do; just Google it) and then add the following Docker service (container) to your `docker-compose.yml` file. This will start a Docker container alongside your TimescaleDB Docker container. 

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

Here's the `.env` file I use for the `mccarthysean/timescaledb_backup_s3:13-1.0.8` Docker image:

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

Cheers, <br>
Sean