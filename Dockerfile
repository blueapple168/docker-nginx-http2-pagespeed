# https://www.openssl.org/source/
# http://nginx.org/en/CHANGES
# https://github.com/pagespeed/ngx_pagespeed/releases
# http://nginx.org/en/docs/configure.html
# https://www.nginx.com/resources/admin-guide/installing-nginx-open-source/
# https://www.nginx.com/resources/wiki/start/topics/tutorials/installoptions/
# http://siawyoung.com/coding/sysadmin/nginx/downloading-and-installing-nginx.html
# https://n0where.net/how-to-enable-http2-in-nginx/
# https://www.nginx.com/blog/nginx-dynamic-modules-how-they-work/

FROM debian:stretch-slim

MAINTAINER df1228@gmail.com

ENV OPENSSL_VERSION 1.1.0f
ENV NGINX_VERSION 1.13.3
ENV NPS_VERSION 1.12.34.2-stable

RUN apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
        ca-certificates build-essential wget libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev

RUN cd && wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
    && tar -xvzf openssl-${OPENSSL_VERSION}.tar.gz \
    && cd openssl-${OPENSSL_VERSION} \
    && ./config \
      --prefix=/usr/local \
      --openssldir=/usr/local/ssl \
    && make \
    && make install \
    && make clean

RUN cd \
    && wget https://github.com/pagespeed/ngx_pagespeed/archive/v${NPS_VERSION}.tar.gz \
    && tar -xvzf v${NPS_VERSION}.tar.gz \
    && cd ngx_pagespeed-${NPS_VERSION}/ \
    && [ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL) \
    && wget ${psol_url} \
    && tar -xvzf $(basename ${psol_url})  # extracts to psol/


RUN cd \
    && wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar -xzvf nginx-${NGINX_VERSION}.tar.gz \
    && cd nginx-${NGINX_VERSION} \
    && ./configure \
        --prefix=/usr/local/nginx \
        --user=nginx \
        --group=nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --with-pcre-jit \
        --with-threads \
        --with-http_gzip_static_module \
        --with-http_ssl_module \
        --with-openssl=$HOME/openssl-${OPENSSL_VERSION} \
        --with-http_v2_module \
        --with-http_stub_status_module \
        --add-dynamic-module=$HOME/ngx_pagespeed-${NPS_VERSION} \
    && make \
    && make install

RUN rm -rf $HOME
RUN apt-get purge build-essential -y \
    && apt-get autoremove -y

RUN useradd --system --no-create-home --user-group nginx

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/var/cache/nginx"]

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
