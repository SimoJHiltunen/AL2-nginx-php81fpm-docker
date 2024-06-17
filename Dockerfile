ARG BUILD_FROM=amazonlinux:2
FROM $BUILD_FROM

WORKDIR /var/www

RUN amazon-linux-extras install -y \
    nginx1 \
    php8.1 \
    epel

RUN yum -y update \
    && yum install -y \
        sudo \
        supervisor \
        php-cli \
        php-common \
        php-curl \
        php-intl \
        php-fpm \
        php-zip \
        php-xml \
        php-mbstring
# TODO: log format to json (php-fpm)       
# TODO: timeformat to epoc time for php-fpm 
RUN sed -i "s|;date.timezone =.*|date.timezone = UTC|" /etc/php.ini \
	&& sed -i "s|;date.timezone =.*|date.timezone = UTC|" /etc/php.ini \
    && sed -i "s|soap.wsdl_cache_enabled=1|soap.wsdl_cache_enabled=0|" /etc/php.ini \
	&& echo "daemon off;" >> /etc/nginx/nginx.conf \
	&& sed -i -e "s|;daemonize\s*=\s*yes|daemonize = no|g" /etc/php-fpm.conf \
	&& sed -i "s|;cgi.fix_pathinfo=1|cgi.fix_pathinfo=0|" /etc/php.ini \
	&& sed -i "s|;decorate_workers_output|decorate_workers_output|" /etc/php-fpm.d/www.conf \
	&& sed -i "s|;clear_env|clear_env|" /etc/php-fpm.d/www.conf \
    # set php-fpm socket connection socket and it's owner
    && sed -i "s|listen = /run/php-fpm/www.sock|listen = /run/php/php-fpm.sock|" /etc/php-fpm.d/www.conf \
    && sed -i "s|user = apache|user = nginx|" /etc/php-fpm.d/www.conf \
    && sed -i "s|group = apache|group = nginx|" /etc/php-fpm.d/www.conf \
    # && sed -i "s|;listen.owner = nobody|listen.owner = nginx|" /etc/php-fpm.d/www.conf \
    # && sed -i "s|;listen.group = nobody|listen.group = nginx|" /etc/php-fpm.d/www.conf \
    && sed -i "s|;listen.mode = 0660|listen.mode = 0660|" /etc/php-fpm.d/www.conf \
    # php-fpm status on and ping on
    && sed -i " s|;pm.status_path = /status|pm.status_path = /status|" /etc/php-fpm.d/www.conf \
    && sed -i " s|php_value\[soap.wsdl_cache_dir\]  = /var/lib/php/wsdlcache|;php_value\[soap.wsdl_cache_dir\]  = /var/lib/php/wsdlcache|" /etc/php-fpm.d/www.conf \
    && sed -i " s|;ping.path = /ping|ping.path = /ping|" /etc/php-fpm.d/www.conf \
    # configura php-fpm access log format to json
    && sed -i "s|;catch_workers_output = yes|catch_workers_output = yes|" /etc/php-fpm.d/www.conf \
    && sed -i "s|;access.log = log/\$pool.access.log|access.log = /proc/self/fd/2|" /etc/php-fpm.d/www.conf \
    && echo "access.format='{\"source\":\"php-fpm\",\"time\":%{%s}T,\"request_id\":\"%{HTTP_X_REQUEST_ID}e\",\"protocol\":\"%{SERVER_PROTOCOL}e\",\"method\":\"%m\",\"uri\":\"%{REQUEST_URI}e\",\"status\":\"%s\",\"body_bytes_sent\":\"%l\",\"request_time\":\"%d\",\"user_agent\":\"%{HTTP_USER_AGENT}e\",\"client_ip\":\"%{HTTP_X_FORWARDED_FOR}e\",\"remote_addr\":\"%R\",\"remote_user\":\"%u\",\"http_referrer\":\"%{HTTP_REFERER}e\"}'" >> /etc/php-fpm.d/www.conf \
    # configure nginx access log fromat to json and error log level
    && sed -i "s|log_format  main  '\$remote_addr - \$remote_user \[\$time_local\] \"\$request\" '|log_format main escape=json '\{\"source\":\"nginx\",\"time\":\$msec,\"request_id\":\"\$uuid\",\"host\":\"\$http_host\",\"address\":\"\$remote_addr\",\"method\":\"\$request_method\",\"uri\":\"\$request_uri\",\"status\":\$status,\"resp_body_size\":\$body_bytes_sent,\"request_length\":\$request_length,\"resp_time\": \$request_time,\"user_agent\":\"\$http_user_agent\",\"upstream_addr\":\"\$upstream_addr\"\}';|" /etc/nginx/nginx.conf \
    && sed -i "s|'\$status \$body_bytes_sent \"\$http_referer\" '||" /etc/nginx/nginx.conf \
    && sed -i "s|'\"\$http_user_agent\" \"\$http_x_forwarded_for\"';||" /etc/nginx/nginx.conf \
    && sed -i "s|error_log /var/log/nginx/error.log;|error_log /var/log/nginx/error.log error;|" /etc/nginx/nginx.conf \
    # forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    # forward php-fpm error logs to docker log collector
    # && ln -sf /dev/stdout /var/log/php-fpm/www.access.log \
    && ln -sf /dev/stderr /var/log/php-fpm/error.log

COPY nginx/site.conf /etc/nginx/conf.d/default.conf

ADD supervisor/2-nginx.ini /etc/supervisord.d/2-nginx.ini
ADD supervisor/3-php.ini /etc/supervisord.d/3-php.ini

ENV APP_ENV prod
ENV APP_DEBUG 0

RUN mkdir -p /run/php \
    && touch /run/php/php-fpm.sock \
    && touch /run/php/php-fpm.pid

EXPOSE 80

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]

