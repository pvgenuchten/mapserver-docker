FROM debian:buster@sha256:66d2008f31f5ad6fdbe094fc7bb45315dc75687a10c611f64eeef2675051518e as builder
# Note: This image will implement libproj13:amd64 5.2.0-1
ENV DEBIAN_FRONTEND noninteractive
ENV TZ Europe/Amsterdam
ENV MS_VERSION rel-7-6-4
ENV HARFBUZZ_VERSION 2.8.2

RUN apt-get -y update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gettext \
        xz-utils \
        cmake \
        gcc \
        g++ \
        libfreetype6-dev \
        libglib2.0-dev \
        libcairo2-dev \
        git \        
        locales \
        make \
        patch \
        protobuf-compiler \
        protobuf-c-compiler \
        software-properties-common \
        wget && \
    rm -rf /var/lib/apt/lists/*

RUN update-locale LANG=C.UTF-8

RUN cd /tmp && \
        wget https://github.com/harfbuzz/harfbuzz/releases/download/$HARFBUZZ_VERSION/harfbuzz-$HARFBUZZ_VERSION.tar.xz && \
        tar xJf harfbuzz-$HARFBUZZ_VERSION.tar.xz && \
        cd harfbuzz-$HARFBUZZ_VERSION && \
        ./configure && \
        make && \
        make install && \
        ldconfig

RUN apt-get -y update && \
    apt-get install -y --no-install-recommends \
        libcurl4-gnutls-dev \
        libfribidi-dev \
        libgif-dev \
        libjpeg-dev \
        libpq-dev \
        librsvg2-dev \      
        libpng-dev \
        libfreetype6-dev \
        libjpeg-dev \
        libexempi-dev \
        libfcgi-dev \
        libgdal-dev \
        libgeos-dev \
        libproj-dev \
        librsvg2-dev \
        libprotobuf-dev \
        libprotobuf-c-dev \
        libprotobuf-c1 \
        libxslt1-dev && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get -y update --fix-missing

RUN git clone --depth=1 --single-branch -b $MS_VERSION https://github.com/mapserver/mapserver/ /usr/local/src/mapserver

RUN mkdir /usr/local/src/mapserver/build && \
    cd /usr/local/src/mapserver/build && \
    cmake ../ \
        -DCMAKE_C_FLAGS="-O2" \
        -DCMAKE_CXX_FLAGS="-O2" \
        -DWITH_XMLMAPFILE=OFF \
        -DWITH_KML=OFF \
        -DWITH_SOS=OFF \
        -DWITH_WMS=ON \
        -DWITH_FRIBIDI=ON \
        -DWITH_HARFBUZZ=ON \
        -DWITH_ICONV=ON \
        -DWITH_CAIRO=ON \
        -DWITH_SVGCAIRO=OFF \
        -DWITH_RSVG=ON \
        -DWITH_MYSQL=OFF \
        -DWITH_FCGI=ON \
        -DWITH_GEOS=ON \
        -DWITH_POSTGIS=ON \
        -DWITH_CURL=ON \
        -DWITH_CLIENT_WMS=ON \
        -DWITH_CLIENT_WFS=ON \
        -DWITH_WFS=ON \
        -DWITH_WCS=ON \
        -DWITH_LIBXML2=ON \
        -DWITH_THREAD_SAFETY=OFF \
        -DWITH_GIF=ON \
        -DWITH_PYTHON=OFF \
        -DWITH_PHP=OFF \
        -DWITH_PERL=OFF \
        -DWITH_RUBY=OFF \
        -DWITH_JAVA=OFF \
        -DWITH_CSHARP=OFF \
        -DWITH_ORACLESPATIAL=OFF \
        -DWITH_ORACLE_PLUGIN=OFF \
        -DWITH_MSSQL2008=OFF \
        -DWITH_EXEMPI=ON \
        -DWITH_XMLMAPFILE=ON \
        -DWITH_V8=OFF \
        -DBUILD_STATIC=OFF \
        -DLINK_STATIC_LIBMAPSERVER=OFF \
        -DWITH_APACHE_MODULE=OFF \          
        -DWITH_POINT_Z_M=ON \
        -DWITH_GENERIC_NINT=OFF \
        -DWITH_PROTOBUFC=ON \
        -DCMAKE_PREFIX_PATH=/opt/gdal && \
    make && \
    make install && \
    ldconfig

FROM pdok/lighttpd:1.4.65-buster@sha256:4e17f4043110cd13c446447c50b5663c7f0c40799959bddf527911db1dd2dad0
LABEL maintainer="ISRIC - World Soil Information"

ENV DEBIAN_FRONTEND noninteractive
ENV TZ Europe/Amsterdam
ENV DEBUG 2
ENV MS_DEBUGLEVEL 4
ENV MS_ERRORFILE "stderr"

ENV MIN_PROCS 1
ENV MAX_PROCS 4
ENV MAX_LOAD_PER_PROC 4
ENV IDLE_TIMEOUT 20
ENV LIGHT_CONF_DIR "/opt/lighttpd"
ENV LIGHT_ROOT_DIR "/srv/data"

EXPOSE 8080
ENV TINI_VERSION v0.19.0

COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/lib /usr/local/lib

USER root
RUN echo 'deb http://deb.debian.org/debian buster contrib non-free'  >>  /etc/apt/sources.list
RUN echo 'deb http://security.debian.org/debian-security buster/updates contrib non-free'  >>  /etc/apt/sources.list
RUN echo 'deb http://deb.debian.org/debian buster-updates contrib non-free'  >>  /etc/apt/sources.list

RUN apt-get -y update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libpng16-16 \
        python-cairocffi-doc \
        libfreetype6 \
        libjpeg62-turbo \
        libfcgi0ldbl \
        libfribidi0 \
        libgdal20 \
        libgeos-c1v5 \
        libglib2.0-0 \
        libproj13 \
        libxml2 \
        libxslt1.1 \
        libexempi8 \
        libpq5 \
        libfreetype6 \
        librsvg2-2 \
        libprotobuf17 \
        libprotobuf-c1 \
        fonts-opensymbol \
# Note: ttf-mscorefonts-installer takes alot of time to install
#        ttf-mscorefonts-installer \
        gettext-base \
        wget \
        gnupg && \
    rm -rf /var/lib/apt/lists/*

# Install tini
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

RUN mkdir -p /opt/lighttpd/
COPY etc/lighttpd.conf /opt/lighttpd/lighttpd.conf
COPY etc/filter-map.lua /opt/lighttpd/filter-map.lua
COPY etc/*.inc /opt/lighttpd/
COPY etc/*.list /opt/lighttpd/
RUN chown -R www-data:www-data  /opt/lighttpd/
# Add some common missing projections 
RUN echo '# Goode Homolosine\n<152160> +proj=igh +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0 <>'  >>  /usr/share/proj/epsg
RUN echo '# LAEA for Africa\n<152161> +proj=laea +lat_0=5 +lon_0=20 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs <>'  >>  /usr/share/proj/epsg
RUN echo '# Mollweide\n<54009> +proj=moll +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs <>'  >>  /usr/share/proj/epsg
RUN echo '# Eckert IV projection\n<54012> +proj=eck4 +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs <>'  >>  /usr/share/proj/epsg 
RUN echo '# Google mercator\n<900913> +proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +over +nadgrids=@null +no_defs <>'  >>  /usr/share/proj/epsg 

RUN chmod o+x /usr/local/bin/mapserv
RUN apt-get clean

USER www-data

EXPOSE 8080

ENTRYPOINT ["/tini","-g","--"]
CMD /usr/local/sbin/lighttpd -D -f $LIGHT_CONF_DIR/lighttpd.conf
