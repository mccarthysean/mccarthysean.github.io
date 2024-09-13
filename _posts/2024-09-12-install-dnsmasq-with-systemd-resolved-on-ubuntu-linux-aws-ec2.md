---
layout: post
title: 'Install Local DNS Cache (dnsmasq) on AWS EC2 Ubuntu Linux, with Systemd-Resolved as well'
tags: [AWS, EC2, Ubuntu, Linux, DNS]
featured_image_thumbnail:
# featured_image: assets/images/posts/2021/timescaledb-logo2.png
featured: false
hidden: false
---
This article shows you how to install, configure, and run `dnsmasq` as your local DNS cache on Ubuntu Linux, on an AWS EC2 server. This way you're not running too many DNS lookups from, say, your web app to your managed AWS RDS database, and seeing weird errors like "Temporary failure in name resolution"...

## Update - Consider Using Unbound Instead!
After I wrote this article, I discovered [Unbound](https://unbound.docs.nlnetlabs.nl/en/latest/) and it's much easier, and it *just works*. Consider reading [this article on Unbound]({% post_url 2024-09-13-install-unbound-on-ubuntu-linux-aws-ec2 %}) first.

# Run all of the following in order 
* It's pretty much a script, but best to do it one line at a time
* The following works for Ubuntu, unlike the instructions here: https://repost.aws/knowledge-center/dns-resolution-failures-ec2-linux

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

Install the dnsmasq package and DHCP client
```bash
sudo apt update && sudo apt install -y dnsmasq isc-dhcp-client
```

Create the required User and Group
```bash
groupadd -r dnsmasq
useradd -r -g dnsmasq dnsmasq
```

Set dnsmasq.conf configuration
```bash
echo -e "# Server Configuration\n\
listen-address=127.0.0.1\n\
port=53\n\
bind-interfaces\n\
user=dnsmasq\n\
group=dnsmasq\n\
# I think /var/run/dnsmasq.pid is for a different flavour of AWS Linux EC2\n\
#pid-file=/var/run/dnsmasq.pid\n\
pid-file=/run/dnsmasq/dnsmasq.pid\n\n\
# Name resolution options\n\
resolv-file=/etc/resolv.dnsmasq\n\
cache-size=500\n\
neg-ttl=60\n\
domain-needed\n\
bogus-priv" | sudo tee /etc/dnsmasq.conf > /dev/null
```

Check it
```bash
cat /etc/dnsmasq.conf
```

Populate /etc/resolv.dnsmasq
```bash
sudo bash -c "echo 'nameserver ${NAMESERVER}' > /etc/resolv.dnsmasq" && \
echo "/etc/resolv.dnsmasq contents:" && cat /etc/resolv.dnsmasq
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

Make the localhost 127.0.0.1 the main (local) DNS resolver
```bash
echo "Old /etc/systemd/resolved.conf contents: " && cat /etc/systemd/resolved.conf
sudo sed -i 's/^#DNS=.*$/DNS=127.0.0.1/' /etc/systemd/resolved.conf
```

Use dnsmasq instead of systemd-resolved (i.e. we don't want systemd-resolved to be the DNS Stub Listener)
```bash
sudo sed -i 's/^#DNSStubListener=yes.*$/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo sed -i 's/^#DNSStubListener=no.*$/DNSStubListener=no/' /etc/systemd/resolved.conf

echo "New /etc/systemd/resolved.conf contents: " && cat /etc/systemd/resolved.conf
sudo systemctl reload-or-restart systemd-resolved
sudo systemctl status systemd-resolved
```

Check if it works at this time
```bash
dig aws.amazon.com
```

For dnsmasq to work, iptables mustn't block the DHCP port
```bash
sudo ufw allow bootps
```

Create the PID directory and file
```bash
sudo mkdir -p /run/dnsmasq
sudo touch /run/dnsmasq/dnsmasq.pid
sudo chown -R dnsmasq:dnsmasq /run/dnsmasq
ls -la /run/dnsmasq
cat /run/dnsmasq/dnsmasq.pid
```

Enable and Start dnsmasq service
```bash
sudo systemctl status dnsmasq.service
sudo systemctl enable  dnsmasq.service 
sudo systemctl reload-or-restart dnsmasq.service
```

Test the service and configure dhclient accordingly.
Set the dnsmasq DNS cache as the default DNS resolver.
Note: You must suppress the default DNS resolver that DHCP provides.
To do this, change or create the /etc/dhcp/dhclient.conf file.
```bash
echo "supersede domain-name-servers 127.0.0.1, ${NAMESERVER};" | sudo tee /etc/dhcp/dhclient.conf > /dev/null 
```

Quick check to see if DNS is working right now
```bash
dig aws.amazon.com @127.0.0.1
```

Apply the change (or… `sudo systemctl restart network`)
```bash
sudo dhclient
```

By default, systemd-resolved creates a symbolic link at /etc/resolv.conf that points to a local DNS stub (127.0.0.53). You need to remove this link and replace it with a standard /etc/resolv.conf file.
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

Ensure both services are enabled
```bash
sudo systemctl enable systemd-resolved
sudo systemctl enable dnsmasq.service
```

Reload or restart them for good measure
```bash
sudo systemctl reload-or-restart systemd-resolved
sudo systemctl reload-or-restart dnsmasq.service
```

Verify dnsmasq works correctly
```bash
dig aws.amazon.com @127.0.0.1
```

Cheers, <br>
Sean
