---
layout: post
title: 'Install Local DNS Cache (Unbound) on AWS EC2 Ubuntu Linux'
tags: [AWS, EC2, Ubuntu, Linux, DNS]
featured_image_thumbnail:
# featured_image: assets/images/posts/2021/timescaledb-logo2.png
featured: false
hidden: false
---
This article shows you how to install, configure, and run [Unbound](https://unbound.docs.nlnetlabs.nl/en/latest/) as your local DNS cache on Ubuntu Linux, on an AWS EC2 server. This way you're not running too many DNS lookups from, say, your web app to your managed AWS RDS database, and seeing weird errors like "Temporary failure in name resolution"...

Here's a link to the [Unbound documentation](https://unbound.docs.nlnetlabs.nl/en/latest/), which is really helpful.

I previously wrote an [article]({% post_url 2024-09-12-install-dnsmasq-with-systemd-resolved-on-ubuntu-linux-aws-ec2 %}) about how to install dnsmasq, working together with systemd-resolved, but Unbound is so much easier, and it *just works*.

Credit to [this tutorial at Yandex](https://yandex.cloud/en/docs/tutorials/infrastructure-management/local-dns-cache)

## Run all of the following in order

* It's pretty much a script, but best to do it one line at a time

Check whether this is to run on VPC (default) or EC2 classic and set NAMESERVER accordingly

```bash
INTERFACE=$(curl --silent http://169.254.169.254/latest/meta-data/network/interfaces/macs/ | head -n1)
IS_IT_CLASSIC=$(curl --write-out %{http_code} --silent --output /dev/null http://169.254.169.254/latest/meta-data/network/interfaces/macs/${INTERFACE}/vpc-id)

if [[ $IS_IT_CLASSIC == '404' ]]
then
  NAMESERVER="172.16.0.23"
else
  NAMESERVER="169.254.169.253"
fi

echo "IS_IT_CLASSIC = $IS_IT_CLASSIC (old Kapua 200 response, new reserved instance, 401)"
echo "NAMESERVER = $NAMESERVER"
```

You should see something like `NAMESERVER = 169.254.169.253` (the main AWS Route53 nameserver)

Install the Unbound package, Unbound-Anchor package for DNS security, the `dig` package, and the DHCP client.

```bash
sudo apt-get update -y
sudo apt-get install unbound unbound-anchor dnsutils isc-dhcp-client -y
```

Create a configuration file, including the Amazon DNS resolver for resolving hosts on your private VPC.

```bash
echo -e "\n\
server:\n\
    # Listen for queries on port 53\n\
    port: 53\n\
    # Listen for DNS queries only on the loopback interface (localhost). This means it's only accessible from the local machine\n\
    interface: 127.0.0.1\n\
    # Allow DNS queries from the 127.0.0.0/8 address range (localhost). Restrict access only to the local machine\n\
    access-control: 127.0.0.0/8 allow\n\
    # Set the logging level for validation. Level 2 provides detailed logs for DNSSEC validation\n\
    # Change this if you don't want to see so many log messages\n\
    val-log-level: 2\n\
    # Level 2 provides detailed logging information\n\
    verbosity: 2\n\
    \n\
    do-ip4: yes\n\
    do-ip6: no\n\
    do-udp: yes\n\
    do-tcp: yes\n\
    num-threads: 2\n\
    num-queries-per-thread: 1024\n\
    # Hide the server's identity in responses\n\
    hide-identity: yes\n\
    hide-version: yes\n\
    # Enables DNS prefetching to improve response times for frequently requested records\n\
    prefetch: yes\n\
    # Root hints (can be updated by unbound-anchor)\n\
    # root-hints: "/var/lib/unbound/root.hints"\n\
    \n\
    # Configures Unbound to treat amazonaws.com as a private domain, which might affect how queries for this domain are handled\n\
    # private-domain: "amazonaws.com"\n\
    \n\
    # The following line includes additional configuration files from the\n\
    # /etc/unbound/unbound.conf.d directory.\n\
    # include-toplevel: "/etc/unbound/unbound.conf.d/*.conf"\n\
    \n\
    # The following line will configure unbound to perform cryptographic\n\
    # DNSSEC validation using the root trust anchor.\n\
    # Thich is crucial for DNSSEC validation.\n\
    # auto-trust-anchor-file: "/var/lib/unbound/root.key"\n\
\n\
# Defines a zone where DNS queries are forwarded to another DNS server\n\
forward-zone:\n\
    # Forward all DNS queries (for any domain) to the specified DNS server. \n\
    # Unbound will not perform any DNS resolution itself but will forward all requests\n\
    # to the server defined in the forward-addr directive.\n\
    # While Unbound itself is not resolving the queries, it will cache the responses it gets\n\
    # from the AWS VPC private resolver. Subsequent queries for the same domain within the cache's\n\
    # TTL (Time-To-Live) will be served from Unbound's local cache rather than being forwarded again.\n\
    name: \".\"\n\
    # Amazon's VPC private DNS resolver (likely 169.254.169.253)\n\
    forward-addr: $NAMESERVER\n\
\n\
# remote-control:\n\
  # control-enable: yes\n\
  # by default the control interface is is 127.0.0.1 and ::1 and port 8953\n\
  # it is possible to use a unix socket too\n\
  # control-interface: /run/unbound.ctl\n\
" | sudo tee /etc/unbound/unbound.conf > /dev/null && \
echo "" && cat /etc/unbound/unbound.conf
```

Manually update the root trust anchor for DNSSEC validation

```bash
sudo mv /var/lib/unbound/root.key /var/lib/unbound/root.key.bak
sudo unbound-anchor -c  -v -a "/var/lib/unbound/root.key"
```

<!-- Alternatively...

```sh
sudo curl -o /var/lib/unbound/root.key https://data.iana.org/root-anchors/root.key
sudo chown unbound:unbound /var/lib/unbound/root.key
sudo chmod 644 /var/lib/unbound/root.key
``` -->

<!-- Check it to ensure it exists now

```bash
cat /var/lib/unbound/root.key
``` -->

Ensure the `unbound` user can access the required /var/lib folder

```bash
sudo chown -R unbound:root /var/lib/unbound
sudo chmod -R 755 /var/lib/unbound
ls -la /var/lib/unbound
```

Check the Unbound configuration files for syntax errors or misconfigurations

```bash
unbound-checkconf -f /etc/unbound/unbound.conf
```

Reload the Unbound config

```bash
sudo systemctl reload-or-restart unbound.service
sudo systemctl status unbound.service
```

Check the logs for the service

```sh
journalctl --unit unbound --lines 1000 --pager-end --follow
```

## Check DNSSEC DNS Security

Run the following and you should see the `ad` flag there. If things go wrong, try the unbound option `val-log-level: 2` that will log explanations why the DNSSEC validation fails (one line per failed query). See [this link](https://nlnetlabs.nl/documentation/unbound/howto-anchor/) for more.

```sh
dig amazonaws.com
dig @8.8.8.8 com. SOA +dnssec
dig +dnssec A www.dnssec.cz
```

Create /etc/dhcp3/dhclient.conf

```bash
sudo mkdir -p /etc/dhcp3
sudo touch /etc/dhcp3/dhclient.conf || true
echo -e "
#supersede domain-name "fugue.com home.vix.com";\n\
prepend domain-name-servers 127.0.0.1;\n\
request subnet-mask, broadcast-address, time-offset, routers,\n\
domain-name, domain-name-servers, host-name,\n\
netbios-name-servers, netbios-scope;" | sudo tee /etc/dhcp3/dhclient.conf > /dev/null
```

Check it

```bash
cat /etc/dhcp3/dhclient.conf
```

Make the localhost 127.0.0.1 the main (local) DNS resolver, if you have systemd-resolved installed

```bash
echo "Old /etc/systemd/resolved.conf contents: " && cat /etc/systemd/resolved.conf
sudo sed -i 's/^#DNS=.*$/DNS=127.0.0.1/' /etc/systemd/resolved.conf
```

Enable DNS security (highly recommended)

```bash
sudo sed -i 's/^#DNSSEC=yes.*$/DNSSEC=yes/' /etc/systemd/resolved.conf
```

Use Unbound instead of systemd-resolved (i.e. we don't want systemd-resolved to be the DNS Stub Listener)

```bash
sudo sed -i 's/^#DNSStubListener=yes.*$/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo sed -i 's/^#DNSStubListener=no.*$/DNSStubListener=no/' /etc/systemd/resolved.conf

echo "New /etc/systemd/resolved.conf contents: " && cat /etc/systemd/resolved.conf
sudo systemctl reload-or-restart systemd-resolved
```

Check if it works at this time

```bash
dig aws.amazon.com
sudo systemctl status systemd-resolved
```

For dnsmasq to work, iptables mustn't block the DHCP port

```bash
sudo ufw allow bootps
```

Stop systemd-resolved and dnsmasq first, if they're running

```bash
sudo systemctl stop dnsmasq.service
sudo systemctl disable dnsmasq.service

sudo systemctl restart systemd-resolved

sudo systemctl status systemd-resolved
sudo systemctl status dnsmasq.service
```

Edit the /etc/resolv.conf file manually and ensure it contains the following line at the top:

```bash
nameserver 127.0.0.1
```

Start Unbound

```bash
sudo systemctl start unbound.service
sudo systemctl status unbound.service
```

Test the service and configure dhclient accordingly.
Set the dnsmasq DNS cache as the default DNS resolver.
Note: You must suppress the default DNS resolver that DHCP provides.
To do this, change or create the /etc/dhcp/dhclient.conf file.

```bash
echo "supersede domain-name-servers 127.0.0.1, ${NAMESERVER};" | sudo tee /etc/dhcp/dhclient.conf > /dev/null 
```

Apply the change (or… `sudo systemctl restart network`)

```bash
sudo dhclient
```

Test that DNS lookups work now!

```bash
dig aws.amazon.com @127.0.0.1
dig google.com @127.0.0.1 | grep -B3 Query
dig microsoft.com
```

## Optional Step

By default, systemd-resolved creates a symbolic link at /etc/resolv.conf that points to a local DNS stub (127.0.0.53). You can remove this link and replace it with a standard /etc/resolv.conf file if you like.

```bash
echo "/etc/resolv.conf contents:" && cat /etc/resolv.conf
ls -la /etc/resolv.conf
cat /etc/resolv.conf
```

Make the file *not* immutable, so we can delete, move, or change it.

```bash
sudo chattr -i /etc/resolv.conf
# sudo unlink /etc/resolv.conf 
sudo mv /etc/resolv.conf /etc/resolv.conf.bak-Sep-11-2024
```

Create a new /etc/resolv.conf file manually, specifying a DNS server (e.g., Google's public DNS or another one you prefer):

```bash
sudo bash -c 'echo "nameserver ${NAMESERVER}" > /etc/resolv.conf'
```

Prevent systemd or other services from modifying your new /etc/resolv.conf file, you can set it as immutable

```bash
sudo chattr +i /etc/resolv.conf
```

To undo the above and make the file *mutable* again, run `sudo chattr -i /etc/resolv.conf`

Check the permissions, and whether it's a file. Previously it was a symlink.

```bash
ls -la /etc/resolv.conf
```

Verify Unbound DNS resolver works correctly

```bash
dig aws.amazon.com @127.0.0.1
```

Cheers, <br>
Sean
