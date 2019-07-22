FROM alpine:3.8
MAINTAINER Friday Godswill <friday@hotels.ng>

#Some weird variables 
ENV php_conf /etc/php7/php.ini
ENV fpm_conf /etc/php7/php-fpm.d/www.conf


# trust this project public key to trust the packages.
ADD https://dl.bintray.com/php-alpine/key/php-alpine.rsa.pub /etc/apk/keys/php-alpine.rsa.pub

# make sure you can use HTTPS
RUN apk --update add ca-certificates

#Install Basic Requirements for life
RUN apk --update add supervisor bash nano nginx &&\
	mkdir -p /etc/nginx && \
    mkdir -p /run/nginx && \
    mkdir -p /etc/nginx/sites-available && \
    mkdir -p /etc/nginx/sites-enabled && \
    mkdir -p /var/log/supervisor && \
    rm -Rf /var/www/* 


# add the repository, make sure you replace the correct versions if you want.
RUN echo "@php https://dl.bintray.com/php-alpine/v3.8/php-7.3" >> /etc/apk/repositories

# install php and some extensions
# notice the @php is required to avoid getting default php packages from alpine instead.
RUN apk add --update php@php
RUN apk add --update php-mbstring@php php-fpm@php php-openssl@php php-phar@php php-json@php php-session@php
RUN apk add --update php-bcmath@php php-pdo@php php-gd@php php-pdo_mysql@php 

#Add other Junk as suggested by @fisayoafolayan
RUN apk add --update php-bz2@php php-calendar@php php-ctype@php php-curl@php php-dba@php \
 php-dom@php php-embed@php php-enchant@php php-exif@php php-ftp@php \
 php-gettext@php php-gmp@php php-iconv@php php-imap@php php-intl@php php-json@php \
 php-ldap@php php-litespeed@php php-mbstring@php php-mysqli@php \
 php-mysqlnd@php php-odbc@php php-opcache@php php-pcntl@php \
 php-pdo_dblib@php php-pdo_pgsql@php php-pdo_sqlite@php \
 php-pear@php php-pgsql@php php-phpdbg@php php-posix@php php-pspell@php \
 php-shmop@php php-snmp@php php-soap@php php-sockets@php php-sqlite3@php \
 php-sysvmsg@php php-sysvsem@php php-sysvshm@php php-tidy@php php-wddx@php php-xml@php \
 php-xmlreader@php php-xsl@php php-zip@php php-zlib@php php-xmlrpc@php

#Install Composer 
RUN php7 -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
php7 composer-setup.php --install-dir=/usr/bin --filename=composer && \
php7 -r "unlink('composer-setup.php');"

#Make php7 available as 'php'
RUN  ln -s /usr/bin/php7 /usr/bin/php 

#Configure Nginx to look at the correct directory for settings
RUN sed -ie "s/conf.d/sites-enabled/g" /etc/nginx/nginx.conf

#Configure php increase upload limits and stuff
RUN sed -i \
        -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" \
        -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" \
        -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" \
        -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" \
        ${php_conf} && \
    sed -i \
        -e "s/;daemonize\s*=\s*yes/daemonize = no/g" \
        -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
        -e "s/pm.max_children = 4/pm.max_children = 4/g" \
        -e "s/pm.start_servers = 2/pm.start_servers = 3/g" \
        -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" \
        -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" \
        -e "s/pm.max_requests = 500/pm.max_requests = 200/g" \
        -e "s/user = nobody/user = nginx/g" \
        -e "s/group = nobody/group = nginx/g" \
        -e "s/;listen.mode = 0660/listen.mode = 0666/g" \
        -e "s/;listen.owner = nobody/listen.owner = nginx/g" \
        -e "s/;listen.group = nobody/listen.group = nginx/g" \
        -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" \
        -e "s/^;clear_env = no$/clear_env = no/" \
        ${fpm_conf} && \
    ln -s /etc/php7/php.ini /etc/php7/conf.d/php.ini && \
    find /etc/php7/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;


EXPOSE 443 80

#remove default configs and replace 
RUN rm /etc/nginx/nginx.conf 

ADD init.sh /init.sh
ADD conf/supervisord.conf /etc/supervisord.conf
ADD conf/nginx.conf /etc/nginx/nginx.conf
ADD conf/nginx-site.conf /etc/nginx/sites-available/default.conf
ADD conf/start.sh /start.sh
RUN chmod 755 /start.sh

WORKDIR /var/www

CMD ["/init.sh"]
