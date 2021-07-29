FROM debian:bullseye as builder
LABEL maintainer="PDOK dev <https://github.com/PDOK/mapserver-docker/issues>"

ENV DEBIAN_FRONTEND noninteractive
ENV TZ Europe/Amsterdam

RUN apt-get -y update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gettext \
        xz-utils \
        cmake \
        g++ \
        git \
        libfreetype6-dev \
        libglib2.0-dev \
        libcairo2-dev \
        libtiff5-dev \
        sqlite3 \
        libsqlite3-dev \
        libwebp-dev \
        locales \
        make \
        patch \
        openssh-server \
        protobuf-compiler \
        protobuf-c-compiler \
        software-properties-common \
        curl \
        wget && \
    rm -rf /var/lib/apt/lists/*

RUN update-locale LANG=C.UTF-8

ENV HARFBUZZ_VERSION 2.8.2

RUN cd /tmp && \
        wget https://github.com/harfbuzz/harfbuzz/releases/download/$HARFBUZZ_VERSION/harfbuzz-$HARFBUZZ_VERSION.tar.xz && \
        tar xJf harfbuzz-$HARFBUZZ_VERSION.tar.xz && \
        cd harfbuzz-$HARFBUZZ_VERSION && \
        ./configure && \
        make && \
        make install && \
        ldconfig

ENV PROJ_VERSION="8.1.0"

ENV GDAL_VERSION="3.3.1"

RUN wget https://github.com/OSGeo/PROJ/releases/download/${PROJ_VERSION}/proj-${PROJ_VERSION}.tar.gz

RUN wget https://github.com/OSGeo/gdal/releases/download/v${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz

RUN mkdir /build

# Build proj
RUN tar xzvf proj-${PROJ_VERSION}.tar.gz && \
    cd /proj-${PROJ_VERSION} && \
    TIFF_LIBS="-L/build/lib -ltiff" TIFF_CFLAGS="-O3 -m64 -I/build/include" ./configure --without-curl --prefix=/build && make -j$(nproc) && make install

# Build gdal
RUN tar xzvf gdal-${GDAL_VERSION}.tar.gz && \
    cd /gdal-${GDAL_VERSION} && \
    ./configure --prefix=/build/gdal --with-proj=/build LDFLAGS="-L/build/lib" CPPFLAGS="-I/build/include" \ 
    --prefix=/build --with-threads=yes --with-webp --with-libtiff=internal --disable-debug --disable-static \
    --with-geotiff=internal --with-jpeg12 --with-gif=internal --with-png=internal --with-libz=internal --with-curl=/build/bin/curl-config && \ 
    make -j$(nproc) && make install

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
        libgeos-dev \
        librsvg2-dev \
        libprotobuf-dev \
        libprotobuf-c-dev \
        libprotobuf-c1 \
        libxslt1-dev && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get -y update --fix-missing

RUN git clone --single-branch -b rel-7-6-4 https://github.com/pdok/mapserver/ /usr/local/src/mapserver

RUN mkdir /usr/local/src/mapserver/build && \
    cd /usr/local/src/mapserver/build && \
    cmake ../ \
        -DWITH_PROJ=ON \
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
        -DWITH_GDAL=ON \
        -DWITH_OGR=ON \
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
        -DWITH_SDE_PLUGIN=OFF \
        -DWITH_SDE=OFF \
        -DWITH_EXEMPI=ON \
        -DWITH_XMLMAPFILE=ON \
        -DWITH_V8=OFF \
        -DBUILD_STATIC=OFF \
        -DLINK_STATIC_LIBMAPSERVER=OFF \
        -DWITH_APACHE_MODULE=OFF \          
        -DWITH_POINT_Z_M=ON \
        -DWITH_GENERIC_NINT=OFF \
        -DWITH_PROTOBUFC=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH=/build:/build/proj:/usr/local:/opt -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DPROJ_INCLUDE_DIR=/build/include -DPROJ_LIBRARY=/build/lib/libproj.so \ 
        -DGDAL_INCLUDE_DIR=/build/include -DGDAL_LIBRARY=/build/lib/libgdal.so && \ 
    make && \
    make install && \
    ldconfig

FROM pdok/lighttpd:1.4.59 as service
LABEL maintainer="PDOK dev <https://github.com/PDOK/mapserver-docker/issues>"

ENV DEBIAN_FRONTEND noninteractive
ENV TZ Europe/Amsterdam
ENV PATH="/build/bin:/build/lib:${PATH}"

COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /build /build

RUN apt-get -y update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libpng16-16 \
        python-cairocffi-doc \
        libfreetype6 \
        libjpeg62-turbo \
        libfcgi0ldbl \
        libfribidi0 \
        libgeos-c1v5 \
        libglib2.0-0 \
        libxml2 \
        libxslt1.1 \
        libexempi8 \
        libpq5 \
        libfreetype6 \
        librsvg2-2 \
        libprotobuf23 \
        libprotobuf-c1 \
        libcurl4-gnutls-dev \
        gettext-base \
        wget \
        gnupg && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://cdn.proj.org/nl_nsgi_nlgeo2018.tif -O /build/share/proj/nl_nsgi_nlgeo2018.tif
RUN wget https://cdn.proj.org/nl_nsgi_rdtrans2018.tif -O /build/share/proj/nl_nsgi_rdtrans2018.tif

RUN \
    wget https://github.com/OSGeo/proj-datumgrid/releases/download/1.8/proj-datumgrid-1.8.tar.gz \
    && tar xzvf proj-datumgrid-1.8.tar.gz -C /build/share/proj \
    && rm -f *.tar.gz

COPY etc/lighttpd.conf /lighttpd.conf
COPY etc/filter-map.lua /filter-map.lua

RUN chmod o+x /usr/local/bin/mapserv
RUN apt-get clean

ENV DEBUG 0
ENV MIN_PROCS 1
ENV MAX_PROCS 3
ENV MAX_LOAD_PER_PROC 4
ENV IDLE_TIMEOUT 20

EXPOSE 80

CMD ["lighttpd", "-D", "-f", "/lighttpd.conf"]
