# PrivateBin on nginx, php-fpm & alpine

**PrivateBin** is a minimalist, open source online [pastebin](https://en.wikipedia.org/wiki/Pastebin) where the server has zero knowledge of pasted data. Data is encrypted and decrypted in the browser using 256bit AES in [Galois Counter mode](https://en.wikipedia.org/wiki/Galois/Counter_Mode).

This repository contains the Dockerfile and resources needed to create a docker image with a pre-installed PrivateBin instance in a secure default configuration. The images are based on the docker hub alpine image, extended with the GD module required to generate discussion avatars and the Nginx webserver to serve static JavaScript libraries, CSS & the logos. All logs of php-fpm and Nginx (access & errors) are forwarded to docker logs.

## Running the image

Assuming you have docker successfully installed and internet access, you can fetch and run the image from the docker hub like this:

```bash
docker run -d --restart="always" --read-only -p 8080:8080 -v $PWD/privatebin-data:/srv/data privatebin/nginx-fpm-alpine
```

The parameters in detail:

- `-v $PWD/privatebin-data:/srv/data` - replace `$PWD/privatebin-data` with the path to the folder on your system, where the pastes and other service data should be persisted. This guarantees that your pastes aren't lost after you stop and restart the image or when you replace it. May be skipped if you just want to test the image.
- `-p 8080:8080` - The Nginx webserver inside the container listens on port 8080, this parameter exposes it on your system on port 8080. Be sure to use a reverse proxy for HTTPS termination in front of it in production environments.
- `--read-only` - This image supports running in read-only mode. Using this reduces the attack surface slightly, since an exploit in one of the images services can't overwrite arbitrary files in the container. Only /tmp, /var/tmp, /var/run & /srv/data may be written into.
- `-d` - launches the container in the background. You can use `docker ps` and `docker logs` to check if the container is alive and well.
- `--restart="always"` - restart the container if it crashes, mainly useful for production setups

> Note that the volume mounted must be owned by UID 65534 / GID 82. If you run the container in a docker instance with "userns-remap" you need to add your subuid/subgid range to these numbers.
> 
> Note, too, that this image exposes the same service on port 80, for backwards compatibility with older versions of the image. To use port 80 with the current image, you either need to have a filesystem with extended attribute support so the nginx binary can be granted the capability to bind to ports below 1024 as non-root user or you need to start the image with user id 0 (root) using the parameter `-u 0`.

### Custom configuration

In case you want to use a customized [conf.php](https://github.com/PrivateBin/PrivateBin/blob/master/cfg/conf.sample.php) file, for example one that has file uploads enabled or that uses a different template, add the file as a second volume:

```bash
docker run -d --restart="always" --read-only -p 8080:8080 -v $PWD/conf.php:/srv/cfg/conf.php:ro -v $PWD/privatebin-data:/srv/data privatebin/nginx-fpm-alpine
```

Note: The `Filesystem` data storage is supported out of the box. The image includes PDO modules for MySQL, PostgreSQL and SQLite, required for the `Database` one, but you still need to keep the /srv/data persisted for the server salt and the traffic limiter.

### Adjusting nginx or php-fpm settings

You can attach your own `php.ini` or nginx configuration files to the folders `/etc/php7/conf.d/` and `/etc/nginx/conf.d/` respectively. This would for example let you adjust the maximum size these two services accept for file uploads, if you need more then the default 10 MiB.

### Timezone settings

The image supports the use of the following two environment variables to adjust the timezone. This is most useful to ensure the logs show the correct local time.

- `TZ`
- `PHP_TZ`

Note: The application internally handles expiration of pastes based on a UNIX timestamp that is calculated based on the timezone set during its creation. Changing the PHP_TZ will affect this and leads to earlier (if the timezone is increased) or later (if it is decreased) expiration then expected.

### Kubernetes deployment

Below is an example deployment for Kubernetes.

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: privatebin-deployment
  labels:
    app: privatebin
spec:
  replicas: 3
  selector:
    matchLabels:
      app: privatebin
  template:
    metadata:
      labels:
        app: privatebin
    spec:
      initContainers:
      - name: privatebin-volume-permissions
        image: privatebin/chown:1.31.1-musl-1.1.24-r9
        command: ['65534:82', '/mnt']
        securityContext:
          runAsUser: 0
          readOnlyRootFilesystem: True
        volumeMounts:
        - mountPath: /mnt
          name: privatebin-data
          readOnly: False
      containers:
      - name: privatebin
        image: privatebin/nginx-fpm-alpine:1.3.4
        ports:
        - containerPort: 8080
        env:
        - name: TZ
          value: Antarctica/South_Pole
        - name: PHP_TZ
          value: Antarctica/South_Pole
        securityContext:
          runAsUser: 65534
          runAsGroup: 82
          readOnlyRootFilesystem: True
        livenessProbe:
          httpGet:
            path: /
            port: http
        readinessProbe:
          httpGet:
            path: /
            port: http
        volumeMounts:
        - mountPath: /srv/data
          name: privatebin-data
          readOnly: False
```

Note that the volume `privatebin-data` has to be a shared, persisted volume across all nodes, i.e. on an NFS share. It is required even when using a database, as some data is always stored in files (server salt, traffic limiters IP hashes, purge limiter time stamp).

## Rolling your own image

To reproduce the image, run:

```bash
docker build -t privatebin/nginx-fpm-alpine .
```

### Behind the scenes

The two processes, Nginx and php-fpm, are started by s6 overlay.

Nginx is required to serve static files and caches them, too. Requests to the index.php (which is the only PHP file exposed in the document root at /var/www) are passed to php-fpm via a socket at /run/php-fpm.sock. All other PHP files and the data are stored under /srv.

The Nginx setup supports only HTTP, so make sure that you run a reverse proxy in front of this for HTTPS offloading and reducing the attack surface on your TLS stack. The Nginx in this image is set up to deflate/gzip text content.

During the build of the image the PrivateBin release archive and the s6 overlay binaries are downloaded from Github. All the downloaded Alpine packages, s6 overlay binaries and the PrivateBin archive are validated using cryptographic signatures to ensure they have not been tempered with, before deploying them in the image.

