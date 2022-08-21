# Mapserver docker

## Introduction

The project is a fork from [PDOK/mapserver-docker](https://github.com/PDOK/mapserver-docker), read more about the capabilities at their [README.md](https://github.com/PDOK/lighttpd-docker/blob/master/README.md).

In `26-07-2022`, PDOK implements: debian-oldstable (`debian-buster`), gdal `2.4.0` and libproj `5.2.0-1`

This repo adds the following aspects:

- add favicon.ico, index.html and robots.txt
- ability to select a mapfile via a path variable
- default symbols and template file

mapfiles should be placed in a (mounted) folder `/srv/data`
run local as:

```bash
docker build . -t isric/mapserver-core
docker run -p 8080:8080  -v `pwd`/example:/srv/data isric/mapserver-core
```

2 env variables: `ENV LIGHT_CONF_DIR` and `ENV LIGHT_ROOT_DIR`, can be used to define folder options on `lighttpd`:

- `ENV LIGHT_CONF_DIR`: Folder with `lighttpd.conf`, lua scripts and templates e.g: "/opt/lighttpd".
- `ENV LIGHT_ROOT_DIR`: Lightttpd document root folder, data folder, e.g: "/srv/data"

Mapfile parsing errors do not end up in logs.

Test your mapfile by entering the pod and use:

```bash
/usr/local/bin/shp2img -m /srv/data/example.map -l example -o output.png
```

Core image implements the following debug:

```bash
#mapserver
ENV DEBUG 2
ENV MS_DEBUGLEVEL 4
ENV MS_ERRORFILE stderr

# light
ENV MIN_PROCS 1
ENV MAX_PROCS 3
ENV MAX_LOAD_PER_PROC 4
ENV IDLE_TIMEOUT 20
```

Using `MS_ERRORFILE stderr` dumps the errors into supporting server.

NOTE: Implement light debug on prod

- ENV DEBUG 0
- ENV MS_DEBUGLEVEL 0

## Passing env variables to mapserver

To pass any env variables to mapserver it is only possible to use `setenv.add-environment`, the default way using [bin-environment(https://redmine.lighttpd.net/boards/2/topics/3656), doesn't seem to work.

For example passing S3 bucket env variables, to be used on mapserver as data source

```bash
# Mapserver: DATA "/vsis3/ws-obs/output/mapserver/soc_0-5cm_uncertainty_europe.tif"
# using direct file access.
$HTTP["url"] =~ "^/sld($|/)" { 
    server.dir-listing = "enable"
} else {
    magnet.attract-raw-url-to = (env.LIGHT_CONF_DIR + "/filter-map.lua")
    setenv.add-environment = ( 
          "AWS_S3_ENDPOINT" => env.AWS_S3_ENDPOINT,
          "AWS_DEFAULT_REGION" => env.AWS_DEFAULT_REGION,
          "AWS_ACCESS_KEY_ID" => env.AWS_ACCESS_KEY_ID,
          "AWS_SECRET_ACCESS_KEY" => env.AWS_SECRET_ACCESS_KEY )
    fastcgi.server = (
    "/" => (
    "mapserver" => (
      "socket" => "/tmp/mapserver-fastcgi.socket",
      "check-local" => "disable",
      "bin-path" => "/usr/local/bin/mapserv",
      "min-procs" => env.MIN_PROCS,
      "max-procs" => env.MAX_PROCS,
      "max-load-per-proc" => env.MAX_LOAD_PER_PROC,
      "idle-timeout" => env.IDLE_TIMEOUT
    )
  )
)
```

## File content folder (e.g sld)

On [lightttpd.conf](etc/lighttpd.conf#L37) around line 37, we have the `server.dir-listing` implementation that will map the a `sld` request to the filesystem folder.

On local docker run with `example-volume`: `http://localhost:8080/sld`

## Dynamic server deployment

Mapserver reqeuires a `ows_onlineresource` parameter on `web > metadata` in order to advertise the proper service url on getcapabilities.
You can hardcode the value on the mapfile, but it will change when you move the mapfile to alternate servers (in that case always use the prod service url).

The image provides a mechanism to fetch the url (and mapfile) dynamically:

Add this section to the mapfile:

```mapfile
WEB
    VALIDATION
      "ows_url" "(\b(https?|ftp|file)://)?[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]"
    END
    
    METADATA
      "ows_onlineresource"               "%ows_url%"
    END
END
```

The LUA url rewrite script will add &ows_url=, with the current request url as GET parameter to the request.
