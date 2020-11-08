---
layout: post
title: 'Time Series Charts with Dash, Flask, TimescaleDB, and Docker - Part 1'
tags: [Python, TimescaleDB, Dash, Flask, Docker]
featured_image_thumbnail:
featured_image: assets/images/posts/2020/dog-computer.jpg
featured: true
hidden: false
---

In this three-part tutorial, I'll show you how to create a reactive single-page application entirely in Python, featuring dynamic time series charts from Dash/Plotly, on a Flask website with a specialized time series database called TimescaleDB, which itself is based on PostgreSQL. Quite a mouthful, but this is a pretty cool tech stack that is easy to learn and program, as it only uses Python and regular SQL (no JavaScript). So it's an ideal stack for quickly deploying data science applications. 

The first part of the tutorial will focus on using Docker to setup the specialized TimescaleDB database, and PGAdmin for managing it. We'll create some simulated IoT data and showcase some of the cool features of TimescaleDB, which you won't find with ordinary PostgreSQL.

The second part will focus on setting up a Python Flask website that integrates with the amazing Dash library for creating React JavaScript-based single-page applications (SPA). I'll show you how to properly integrate Dash into Flask, so you can have the best of both web frameworks.

The third part will focus on using Dash to create interactive time series charts for monitoring your IoT data or showcasing your data science application. 

All the code for this tutorial can be found [here](https://github.com/mccarthysean/Flask-Dash-Plotly-TimescaleDB-Docker-Swarm-Traefik) at GitHub. 

I use Docker wherever possible, for reproducible environments, and super-easy deployment using Docker Swarm, so if you're not familiar with Docker, check out the documentation [here](https://docs.docker.com/). 

# Part 1 - TimescaleDB, PGAdmin, and Docker

First, let's create a Docker network so our forthcoming containers can talk to each other:
```bash
docker network create --attachable --driver bridge timescale_network
```
Next, let's start a local TimescaleDB database using Docker-Compose. This will quickly start a local PostgreSQL database with the TimescaleDB extension automatically configured. Create the following `docker-compose.timescale.yml` file:
```yaml
version: '3.7'
services:
  timescale:
    image: timescale/timescaledb:1.7.4-pg12
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
    environment: 
      POSTGRES_HOST: timescale
    command: ["-c", "config_file=/postgresql_custom.conf"]
    ports: 
      - 5432:5432
    networks:
      timescale_network:
    deploy:
      restart_policy:
        condition: on-failure

# Creates a named volume to persist our database data
volumes:
  timescale_volume:

networks:
  timescale_network:
    external: true
```
Note a few things about the above Docker-Compose file:

1. It uses the `timescale_network` we created in the previous step. 

2. It uses a volume to persist the database's data, even if the Docker container is removed or replaced. This is very common for 'Dockerized' databases. 

3. It uses port 5432 (this will be important when we try to access the database in the future). 

4. It uses a custom configuration file, and a `.env` file to store secret database connection information, like your database password. Let's create those two files:

Here's the custom configuration file, in case you want/need to change any of these settings in the future. The file is too long to put in a code block in this article, so just click <a href="/assets/files/posts/2020/postgresql_custom.conf">this link</a>, then copy and paste the text into a file called `postgresql_custom.conf` and put it in the root of your project folder.

Next, here's a template for our secret `.env` file, which you can leave in the root of your project folder, alongside the Docker-Compose and database configuration files:
```bash
# For the Postgres/TimescaleDB database. 
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=timescale
PGDATA=/var/lib/postgresql/data
```

Now that we've added the custom configuration and .env files, you can start the TimescaleDB database with the following command. The `-d` starts the container in the background (`--detached`).
```bash
docker-compose -f docker-compose.timescale.yml up -d
```
Check your running containers with `docker container ls` or the old-school `docker ps`. If the container is restarting, check the logs with `docker logs <container id>` and ensure you've setup the .env file, the config file, and the Docker network it depends on.

Finally, let's create a friendly PGAdmin environment for administering our database and running SQL. Create a file called `docker-compose.pgadmin.yml` and add the following:
```yaml
version: '3.7'
services:
  pgadmin:
    # Name of the container this service creates. Otherwise it's prefixed with the git repo name
    image: "dpage/pgadmin4:latest"
    restart: unless-stopped
    env_file: .env
    environment: 
      PGADMIN_LISTEN_PORT: 9000
    ports: 
      - 0.0.0.0:9000:9000
    volumes: 
      # So the database server settings get saved and stored even if the container is replaced or deleted
      - pgadmin:/var/lib/pgadmin
    networks:
      timescale_network:
volumes:
  pgadmin:

networks:
  timescale_network:
    external: true
```

Add the following lines to your `.env` file for PGAdmin. You'll need this login information when you try to access PGAdmin in the web browser. 
```bash
# For the PGAdmin web app
PGADMIN_DEFAULT_EMAIL=your@email.com
PGADMIN_DEFAULT_PASSWORD=password
```

Start the PGAdmin (PostgreSQL Admin) web application with the following Docker command:
```bash
docker-compose -f docker-compose.pgadmin.yml up -d
```

Run `docker container ls` again to check if the PGAdmin container is running. Note we specified a port of 9000, so you can now access PGAdmin at http://localhost:9000 or http://127.0.0.1:9000 . Login with the username and password you setup in your `.env` file. 

Now that you've logged into PGAdmin, right-click on "Servers" and "Create/Server...". Name it "TimescaleDB Local" in the "General" tab, and type the following into the "Connection" tab:
* Host: timescale (this is the Docker "Service" hostname defined in the first docker-compose.yml file for the TimescaleDB database container)
* Port: 5432
* Maintenance database: postgres
* Username: postgres
* Password: password

Click "Save" and you should be connected. Now you can double-click on "TimescaleDB Local" and you can access your database tables at "/Databases/postgres/Schemas/public/Tables". Pretty cool, huh? Under the "Tools" menu, click on "Query Tool" and you're ready to start writing SQL. 

You're now the proud commander of a TimescaleDB database, which is identical to a PostgreSQL database ("The world's most advanced open source database", if you believe their marketing), except that it now has special abilities for dealing with high-frequency time series data. 

Time series data is a bit different from regular relational data for describing users and things. Time series data can arrive any second, or even multiple times per second, depending on what you're storing, so the database needs to be able to handle lots of insertions. Some examples are financial data, such as stock market trading prices, or internet of things (IoT) data, usually for monitoring environmental metrics like temperature, pressure, humidity, or anything else you can think of. Usually when you query time series data, you're interested in the most recent data, and you're usually filtering on the timestamp column, so that definitely needs to be indexed. TimescaleDB specializes in this sort of thing. 

Let's create a special TimescaleDB "Hypertable" and insert some data to play with. Here's the [documentation](https://docs.timescale.com/latest/using-timescaledb/hypertables). And [here's the tutorial](https://docs.timescale.com/latest/tutorials/tutorial-howto-simulate-iot-sensor-data) from which I'm getting the simulated data SQL. 

In PGAdmin, if you're not already there, under the "Tools" menu, click on "Query Tool" and type the following SQL to create two IoT data tables:
```sql
CREATE TABLE sensors(
  id SERIAL PRIMARY KEY,
  type VARCHAR(50),
  location VARCHAR(50)
);
CREATE TABLE sensor_data (
  time TIMESTAMPTZ NOT NULL,
  sensor_id INTEGER,
  temperature DOUBLE PRECISION,
  cpu DOUBLE PRECISION,
  FOREIGN KEY (sensor_id) REFERENCES sensors (id)
);
```

Now the the special part that you can't do in a regular PostgreSQL database. We're going to transform the `sensor_data` table into a "Hypertable". Behind the scenes, TimescaleDB is going to partition the data on the time dimension, making it easier to filter, index, and drop old time series data. 

If you've come to this tutorial to take advantage of TimescaleDB's unique features, pay attention because this is where the magic happens.

Run the following query in PGAdmin to create the partitioned hypertable:
```sql
SELECT create_hypertable('sensor_data', 'time');
```

Now that our specialized time series table has been created, let's create a special index on the sensor ID, since we're very likely to filter on both sensor ID and time. 
```sql
create index on sensor_data (sensor_id, time desc);
```

Let's now add a few different sensors to the "sensors" table:
```sql
INSERT INTO sensors (type, location) VALUES
('a','floor'),
('a', 'ceiling'),
('b','floor'),
('b', 'ceiling');
```

Now for the fun part--let's create some simulated time series data:
```sql
INSERT INTO sensor_data (time, sensor_id, cpu, temperature)
SELECT
  time,
  sensor_id,
  random() AS cpu,
  random()*100 AS temperature
FROM generate_series(now() - interval '31 days', now(), interval '5 minute') AS g1(time), generate_series(1,4,1) AS g2(sensor_id);
```

Run a simple select query to see some of our newly-simulated data:
```sql
SELECT * 
FROM sensor_data
WHERE time > (now() - interval '1 day')
ORDER BY time;
```

Here's another example of selecting the aggregated data (i.e. a 1-hour average, instead of seeing every single data point):
```sql
SELECT 
  sensor_id,
  time_bucket('1 hour', time) AS period, 
  AVG(temperature) AS avg_temp, 
  AVG(cpu) AS avg_cpu 
FROM sensor_data 
GROUP BY 
  sensor_id, 
  time_bucket('1 hour', time)
ORDER BY 
  sensor_id, 
  time_bucket('1 hour', time);
```

From the official TimescaleDB tutorial, let's showcase two more queries. First, instead of a time series history, you might just want the *latest* data. For that, you can use the "last()" function:
```sql
SELECT 
  time_bucket('30 minutes', time) AS period, 
  AVG(temperature) AS avg_temp, 
  last(temperature, time) AS last_temp --the latest value
FROM sensor_data 
GROUP BY period;
```

And of course, you'll often want to join the time series data with the *metadata* (i.e. data about data). In other words, let's get a location for each sensor, rather than a sensor ID:
```sql
SELECT 
  t2.location, --from the second metadata table
  time_bucket('30 minutes', time) AS period, 
  AVG(temperature) AS avg_temp, 
  last(temperature, time) AS last_temp, 
  AVG(cpu) AS avg_cpu 
FROM sensor_data t1 
INNER JOIN sensors t2 
  on t1.sensor_id = t2.id
GROUP BY 
  period, 
  t2.location;
```

TimescaleDB has another very useful feature for continually and efficiently updating aggregated views of our time series data. If you often want to report/chart aggregated data, the following view-creation code is for you:
```sql
CREATE VIEW sensor_data_1_hour_view
WITH (timescaledb.continuous) AS --TimescaleDB continuous aggregate
SELECT 
  sensor_id,
  time_bucket('01:00:00'::interval, sensor_data.time) AS time,
  AVG(temperature) AS avg_temp, 
  AVG(cpu) AS avg_cpu
FROM sensor_data
GROUP BY 
  sensor_id,
  time_bucket('01:00:00'::interval, sensor_data.time) AS time
```

That's it for part 1 of this three-part tutorial on TimescaleDB, Dash, and Flask. Stay tuned for part 2 on integrating Dash and Flask, and part 3 on creating reactive, interactive time series charts in Dash for your single-page application (SPA).

Stay healthy,
Sean