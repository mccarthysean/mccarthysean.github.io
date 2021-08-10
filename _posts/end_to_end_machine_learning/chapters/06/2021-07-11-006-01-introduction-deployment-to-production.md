---
layout: post
title: Introduction - Deployment to Production
# slug: introduction-deployment-to-production
chapter: 1
tags: [Python, Flask, Dash, TimescaleDB, Docker, Traefik, Machine Learning]
preview: true
hidden: true
---

{% include end_to_end_ml_table_of_contents.html %}

Congratulations, you've made it almost to the finish line. You've got a working and tested machine learning web app, and now it's time to deploy it to a production server. 

There are many cloud-based hosting options available to you. Personally, I prefer AWS EC2 servers, but I've also used cheap Digital Ocean droplets in the past as well. Just ensure you've got Docker installed on the server, and you're good to go.

# Learning Objectives
By the end of Part 6, you will be able to:
1. Deploy a Traefik web server for automatic HTTPS, and which works well with Docker Swarm
2. Deploy your database to the server, along with the automatic backups Docker container
3. Deploy your web app to the server with multiple nodes, if need be

Next: <a href="006-02-Traefik-Web-Server">Traefik Web Server</a>

{% include end_to_end_ml_table_of_contents.html %}
