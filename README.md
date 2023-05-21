# PrivateBin on Nginx, php-fpm & Alpine

**PrivateBin** is a minimalist, open source online [pastebin](https://en.wikipedia.org/wiki/Pastebin) where the server has zero knowledge of pasted data. Data is encrypted and decrypted in the browser using 256bit AES in [Galois Counter mode](https://en.wikipedia.org/wiki/Galois/Counter_Mode).

This repository contains the Dockerfile and resources needed to create a docker image with a pre-installed PrivateBin instance in a secure default configuration. The images are based on the docker hub Alpine image, extended with the GD module required to generate discussion avatars and the Nginx webserver to serve static JavaScript libraries, CSS & the logos. All logs of php-fpm and Nginx (access & errors) are forwarded to docker logs.

## Image variants

This is the all-in-one image ([Docker Hub](https://hub.docker.com/r/privatebin/nginx-fpm-alpine/) / [GitHub](https://github.com/orgs/PrivateBin/packages/container/package/nginx-fpm-alpine)) that can be used with any storage backend supported by PrivateBin - file based storage, databases, Google Cloud or S3 Storage. We also offer dedicated images for each backend:
- [Image for file based storage (Docker Hub](https://hub.docker.com/r/privatebin/fs) / [GitHub](https://github.com/orgs/PrivateBin/packages/container/package/fs))
- [Image for PostgreSQL, MariaDB & MySQL (Docker Hub](https://hub.docker.com/r/privatebin/pdo) / [GitHub](https://github.com/orgs/PrivateBin/packages/container/package/pdo))
- [Image for Google Cloud Storage (Docker Hub](https://hub.docker.com/r/privatebin/gcs) / [GitHub](https://github.com/orgs/PrivateBin/packages/container/package/gcs))
- [Image for S3 Storage (Docker Hub](https://hub.docker.com/r/privatebin/s3) / [GitHub](https://github.com/orgs/PrivateBin/packages/container/package/s3))

## Image tags

All images contain a release version of PrivateBin and are offered with the following tags:
- `latest` is an alias of the latest pushed image, usually the same as `nightly`, but excluding `edge`
- `nightly` is the latest released PrivateBin version on an upgraded Alpine release image, including the latest changes from the docker image repository
- `edge` is the latest released PrivateBin version on an upgraded Alpine edge image
- `stable` contains the latest PrivateBin release on the latest tagged release of the [docker image git repository](https://github.com/PrivateBin/docker-nginx-fpm-alpine) - gets updated when important security fixes are released for Alpine or upon new Alpine releases
- `1.5.1` contains PrivateBin version 1.5.1 on the latest tagged release of the [docker image git repository](https://github.com/PrivateBin/docker-nginx-fpm-alpine) - gets updated when important security fixes are released for Alpine or upon new Alpine releases, same as stable
- `1.5.1-...` are provided for selecting specific, immutable images

If you update your images automatically via pulls, the `stable`, `nightly` or `latest` are recommended. If you prefer to have control and reproducability or use a form of orchestration, the numeric tags are probably preferable. The `edge` tag offers a preview of software in future Alpine releases and serves as an early warning system to detect image build issues in these.

## Image registries

These images are hosted on the Docker Hub and the GitHub container registries:
- [Images on Docker Hub](https://hub.docker.com/u/privatebin), which are prefixed `privatebin` or `docker.io/privatebin`
- [Images on GitHub](https://github.com/orgs/PrivateBin/packages), which are prefixed `ghcr.io/privatebin`

## Running the image

Assuming you have docker successfully installed and internet access, you can fetch and run the image from the docker hub like this:

```console
$ docker run -d --restart="always" --read-only -p 8080:8080 -v $PWD/privatebin-data:/srv/data privatebin/nginx-fpm-alpine
```

The parameters in detail:

- `-v $PWD/privatebin-data:/srv/data` - replace `$PWD/privatebin-data` with the path to the folder on your system, where the pastes and other service data should be persisted. This guarantees that your pastes aren't lost after you stop and restart the image or when you replace it. May be skipped if you just want to test the image or use database or Google Cloud Storage backend.
- `-p 8080:8080` - The Nginx webserver inside the container listens on port 8080, this parameter exposes it on your system on port 8080. Be sure to use a reverse proxy for HTTPS termination in front of it in production environments.
- `--read-only` - This image supports running in read-only mode. Using this reduces the attack surface slightly, since an exploit in one of the images services can't overwrite arbitrary files in the container. Only /tmp, /var/tmp, /var/run & /srv/data may be written into.
- `-d` - launches the container in the background. You can use `docker ps` and `docker logs` to check if the container is alive and well.
- `--restart="always"` - restart the container if it crashes, mainly useful for production setups

> Note that the volume mounted must be owned by UID 65534 / GID 82. If you run the container in a docker instance with "userns-remap" you need to add your subuid/subgid range to these numbers.

### Custom configuration

In case you want to use a customized [conf.php](https://github.com/PrivateBin/PrivateBin/blob/master/cfg/conf.sample.php) file, for example one that has file uploads enabled or that uses a different template, add the file as a second volume:

```console
$ docker run -d --restart="always" --read-only -p 8080:8080 -v $PWD/conf.php:/srv/cfg/conf.php:ro -v $PWD/privatebin-data:/srv/data privatebin/nginx-fpm-alpine
```

Note: The `Filesystem` data storage is supported out of the box. The image includes PDO modules for MySQL and PostgreSQL, required for the `Database` one, but you still need to keep the /srv/data persisted for the server salt and the traffic limiter when using a release before 1.4.0.

### Adjusting nginx or php-fpm settings

You can attach your own `php.ini` or nginx configuration files to the folders `/etc/php/conf.d/` and `/etc/nginx/http.d/` respectively. This would for example let you adjust the maximum size these two services accept for file uploads, if you need more then the default 10 MiB.

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
      securityContext:
        runAsUser: 65534
        runAsGroup: 82
        fsGroup: 82
      containers:
      - name: privatebin
        image: privatebin/nginx-fpm-alpine:stable
        ports:
        - containerPort: 8080
        env:
        - name: TZ
          value: Antarctica/South_Pole
        - name: PHP_TZ
          value: Antarctica/South_Pole
        securityContext:
          readOnlyRootFilesystem: true
          privileged: false
          allowPrivilegeEscalation: false
        livenessProbe:
          httpGet:
            path: /
            port: 8080
        readinessProbe:
          httpGet:
            path: /
            port: 8080
        volumeMounts:
        - mountPath: /srv/data
          name: privatebin-data
          readOnly: False
        - mountPath: /run
          name: run
          readOnly: False
        - mountPath: /tmp
          name: tmp
          readOnly: False
        - mountPath: /var/lib/nginx/tmp
          name: nginx-cache
          readOnly: False
  volumes:
    - name: run
      emptyDir:
        medium: "Memory"
    - name: tmp
      emptyDir:
        medium: "Memory"
    - name: nginx-cache
      emptyDir: {}
```

Note that the volume `privatebin-data` has to be a shared, persisted volume across all nodes, i.e. on an NFS share. As of PrivateBin 1.4.0 it is no longer required, when using a database or Google Cloud Storage.

## Running administrative scripts

The image includes two administrative scripts, which you can use to migrate from one storage backend to another, delete pastes by ID, removing empty directories when using the Filesystem backend, to purge all expired pastes and display statistics. These can be executed within the running image or by running the commands as alternative entrypoints with the same volumes attached as in the running service image, the former option is recommended.

```console
# assuming you named your container "privatebin" using the option: --name privatebin

$ docker exec -t privatebin administration --help
Usage:
  administration [--delete <paste id> | --empty-dirs | --help | --purge | --statistics]

Options:
  -d, --delete      deletes the requested paste ID
  -e, --empty-dirs  removes empty directories (only if Filesystem storage is
                    configured)
  -h, --help        displays this help message
  -p, --purge       purge all expired pastes
  -s, --statistics  reads all stored pastes and comments and reports statistics

docker exec -t privatebin migrate --help
migrate - Copy data between PrivateBin backends

Usage:
  migrate [--delete-after] [--delete-during] [-f] [-n] [-v] srcconfdir
          [<dstconfdir>]
  migrate [-h|--help]

Options:
  --delete-after   delete data from source after all pastes and comments have
                   successfully been copied to the destination
  --delete-during  delete data from source after the current paste and its
                   comments have successfully been copied to the destination
  -f               forcefully overwrite data which already exists at the
                   destination
  -h, --help       displays this help message
  -n               dry run, do not copy data
  -v               be verbose
  <srcconfdir>     use storage backend configration from conf.php found in
                   this directory as source
  <dstconfdir>     optionally, use storage backend configration from conf.php
                   found in this directory as destination; defaults to:
                   /srv/bin/../cfg/conf.php
```

Note that in order to migrate between different storage backends you will need to use the all-in-one image called `privatebin/nginx-fpm-alpine`, as it comes with all the drivers and libraries for the different supported backends. When using the variant images, you will only be able to migrate within two backends of the same storage type, for example two filesystem paths or two database backends.

## Rolling your own image

To reproduce the image, run:

```console
$ docker build -t privatebin/nginx-fpm-alpine .
```

### Behind the scenes

The two processes, Nginx and php-fpm, are started by s6.

Nginx is required to serve static files and caches them, too. Requests to the index.php (which is the only PHP file exposed in the document root at /var/www) are passed to php-fpm via a socket at /run/php-fpm.sock. All other PHP files and the data are stored under /srv.

The Nginx setup supports only HTTP, so make sure that you run a reverse proxy in front of this for HTTPS offloading and reducing the attack surface on your TLS stack. The Nginx in this image is set up to deflate/gzip text content.

During the build of the image, the PrivateBin release archive is downloaded from Github. All the downloaded Alpine packages and the PrivateBin archive are validated using cryptographic signatures to ensure they have not been tempered with, before deploying them in the image.
