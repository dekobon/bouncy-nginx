Bouncy Nginx
============

This Docker image provides a pre-setup Nginx instance that is configured
as a reverse proxy. Furthermore, this image contains utilities that allow
you to quickly reconfigure reverse-proxy backends with minimal downtime.
This image runs as a multi-process Docker container using phusion-passenger
and runit. It is implemented such so that users can extend it to write
services that poll the Docker API looking for changes in instances and
thereby auto-populate proxy backends.

### Installation

A typical setup would use docker-compose. If you were using bouncy-nginx on
Joyent's Triton, you would have a docker-compose.yml that looked like:

```yaml
site:
  image: tutum/hello-world:latest
  expose:
    - "80:80"
  restart: always
lb:
  image: dekobon/bouncy-nginx:latest
  ports:
    - "80:80"
  links:
    - site
  restart: always
```

If you aren't using Triton, you will need to mix in your own service discovery
tool into your update_lb_pool.sh script in order to identify the multiple ports
that are being mapped on a single IP address. You will also need to modify the
above yaml example so that it isn't mapping port 80 to 80 because that will
result in a conflict.

Now, you would start up the Docker Compose cluster:

```bash
➜  ~  docker-compose -p bouncy up -d
Pulling site (tutum/hello-world:latest)...
latest: Pulling from tutum/hello-world (212ab15b-7781-48db-a24d-9d198612f558)
c833a1892a15: Already exists
a1dd7097a8e8: Already exists
5e314245be14: Already exists
01fb4017dfb8: Already exists
da052ae129c2: Already exists
2e26b130ff1d: Already exists
b93eb18c953b: Already exists
8989fc3642f5: Already exists
Status: Downloaded newer image for tutum/hello-world:latest
Creating bouncy_site_1...
Creating bouncy_lb_1...
```

Check out the logs and make sure everything is running:

```bash
➜  ~  docker-compose -p bouncy logs
Attaching to bouncy_lb_1, bouncy_site_1
lb_1   | nginx: [emerg] no servers are inside upstream in /etc/nginx/sites-enabled/default:6
lb_1   | ok: run: syslog-ng: (pid 91405) 124s
^C
Aborting.
```

Then you are free to scale the number of site instances:

```bash
➜  ~  docker-compose -p bouncy scale site=3
Creating bouncy_site_2...
Creating bouncy_site_3...
Starting bouncy_site_2...
Starting bouncy_site_3...
```

Now, update the Ngnix proxy dynamically:

```bash
➜  ~ ./update-lb-pool.sh bouncy_site 80 bouncy_lb_1
a4a51a51d72f45f89ee53175267aa732cd5202d8a63d44d7af61f428093fe522 5c9b77041b64410da10b639558700190cd096f397214455b9a2ea134064cf9df f34b2b4d643d444cb19c0d1ac3c09fc755bd2301d8a74b3f9c4d5d2e2fcb2224
Wiping existing pool configuration
Updating with the latest configuration
server 192.168.129.189:80;
server 192.168.129.191:80;
server 192.168.129.192:80;

Loadbalancer IP: 165.225.171.40
```

Go ahead and curl the load balancer API:

```bash
➜  ~ curl -s http://165.225.171.40/ | grep hostname | sed 's|<[^>]*>||g'
	My hostname is 5c9b77041b64
➜  ~ curl -s http://165.225.171.40/ | grep hostname | sed 's|<[^>]*>||g'
	My hostname is a4a51a51d72f
➜  ~ curl -s http://165.225.171.40/ | grep hostname | sed 's|<[^>]*>||g'
	My hostname is f34b2b4d643d
```

Hooray! We got load balancing pool membership with Docker working in a single command.

### Setup Hints
 1. You probably want to mount a data volume on /etc/nginx/sites-available
    in order to preserve your Nginx configuration across construction and
    destruction of your container.
 2. If you add servers inside of the ### start/end pool ### comment block you can use 
    utilities to template in linked servers into your configuration.
 3. Take a look at update-lb-pool.sh for an example of a script that you could
    run from a machine configured with a DOCKER_HOST variable. This script will
    allow you to update your Nginx configuration include all hosts that match a given
    prefix (as is predictably created by docker-compose). For example, you could add
    all instances of your site container by doing: 
    ./update_lb_pool.sh cluster_site 80 cluster_nginx_1
 4. You can reload the proxy configuration at runtime by running the script: /usr/local/bin/bounce_nginx
 5. By default TLS support isn't setup, but there's no reason why you can't
    extend this image and set it up yourself.