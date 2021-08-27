#!/bin/bash

# Compile nginx va php version moi nhat: nginx (1.21.1), php (8.0.10)
# nginx prefix: /etc/nginx
# php prefix: /usr/local/php

DOWNLOAD_DIR=/source
sudo mkdir $DOWNLOAD_DIR

function compile_nginx(){
     #tat selinux 
     sudo setenforce 0
     sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

     # cai dat cac goi depedencies
     sudo yum update -y

     sudo yum install epel-release -y

     sudo yum install wget vim curl -y

     sudo yum groupinstall -y 'Development Tools'

     sudo yum install -y zlib zlib-devel pcre prce-devel openssl openssl-devel

     sudo yum install perl perl-devel perl-ExtUtils-Embed libxslt libxslt-devel \
     libxml2 libxml2-devel gd gd-devel GeoIP GeoIP-devel -y

  
     # tao user va group nginx
     sudo groupadd nginx
     sudo useradd nginx -g nginx --no-create-home --shell /sbin/nologin

     # tai source nginx
     sudo wget http://nginx.org/download/nginx-1.21.1.tar.gz
     sudo tar -zxf nginx-1.21.1.tar.gz
     cd nginx-1.21.1/

     # compile nginx
     sudo ./configure --user=nginx --group=nginx \
     --sbin-path=/usr/sbin/nginx \
     --error-log-path=/var/log/nginx/error.log \
     --pid-path=/var/run/nginx.pid \
     --lock-path=/var/run/nginx.lock \
     --prefix=/etc/nginx \
     --with-http_ssl_module \
     --with-http_realip_module \
     --with-http_addition_module \
     --with-http_sub_module \
     --with-http_dav_module \
     --with-http_gunzip_module \
     --with-http_gzip_static_module \
     --with-http_random_index_module \
     --with-http_secure_link_module \
     --with-http_stub_status_module \
     --with-file-aio \
     --with-stream \
     --with-http_geoip_module

     sudo make
     sudo make install
     #sudo chown -R nginx:nginx /etc/nginx/

     # systemd nginx.service
sudo su -c 'cat > /etc/systemd/system/nginx.service <<EOF"
 
[Unit]
Description=nginx - high performance web server
Documentation=https://nginx.org/en/docs/
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target
 
[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/conf/nginx.conf
ExecStart=/usr/sbin/nginx -c /etc/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID
 
[Install]
WantedBy=multi-user.target
EOF'

     sudo systemctl daemon-reload
     sudo systemctl start nginx
     sudo systemctl enable nginx


}

function install_php_dependencies(){
     sudo yum install epel-release -y

     yum install oniguruma-devel --enablerepo=epel -y

     sudo yum install autoconf libtool re2c bison libxml2-devel libzip5-devel \
     bzip2-devel libcurl-devel libpng-devel libicu-devel gcc-c++ sqlite-devel \
     libmcrypt-devel libwebp-devel libjpeg-devel openssl-devel libxslt-devel -y

     # install libzib
     sudo rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-7.rpm
     sudo yum remove libzib -y
     yum --enablerepo=remi install libzip5-devel -y
}

function php_compile(){
     # Download the PHP source and extract it to the target directory
     sudo curl -O -L  https://www.php.net/distributions/php-8.0.10.tar.gz
     tar -xzf php-8.0.10.tar.gz
     cd cd php-8.0.10/
     sudo ./buildconf --force
     sudo ./configure --prefix=/usr/local/php  \
     --enable-ctype --enable-dom --enable-fileinfo --enable-filter --enable-gd --with-iconv \
     --enable-json --enable-libxml --with-libxml-dir --enable-mbstring --with-pdo-mysql \
     --enable-phar --enable-simplexml --enable-tokenizer --enable-xml --enable-xmlreader \
     --enable-xmlwriter --with-zip --with-zlib --disable-short-tags --enable-cli --with-openssl \
     --with-pcre-regex --with-pcre-jit --enable-bcmath --with-bz2 --with-curl --enable-exif \
     --enable-intl --with-mysqli --enable-pcntl --enable-soap --enable-sockets --with-xmlrpc \
      --with-jpeg-dir --with-png-dir --enable-hash --with-mcrypt --enable-calendar \
     --with-mhash --with-xsl --with-pear --enable-fpm --enable-sockets

     sudo make clean
     sudo make
     sudo make install


     sudo cp $DOWNLOAD_DIR/php-8.0.10/php.ini-production /usr/local/php/etc/php.ini

     #Add PHP to $PATH
     sudo echo 'pathmunge /usr/local/php/bin' > /etc/profile.d/php.sh
}

function php_fpm(){
     

     sudo cp /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf

     FILE=/usr/local/php/etc/php-fpm.conf
     sudo sed -i 's/;pid = run\/php-fpm.pid/pid = run\/php-fpm.pid/' $FILE
     sudo sed -i 's/;error_log = log\/php-fpm.log/error_log = log\/php-fpm.log/' $FILE
     

     #Cập nhật file thiết lập /usr/local/php/etc/php-fpm.d/www.conf
sudo cat > /usr/local/php/etc/php-fpm.d/www.conf <<EOF

[www]
;listen = /usr/local/php/var/run/www-php-fpm.sock
listen = 127.0.0.1:9000
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = nginx
listen.group = nginx
listen.mode = 0660
user = nginx
group = nginx
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 6
pm.status_path = /status
ping.path = /ping
ping.response = pong
request_terminate_timeout = 100
request_slowlog_timeout = 10s
slowlog = /usr/local/php/var/log/www.log.slow
EOF
     

     # ------ Them dich vu systemd
     sudo cp $DOWNLOAD_DIR/php-8.0.10/sapi/fpm/php-fpm.service /etc/systemd/system
     # Chinh lai quyen de dc ghi file log
     sudo sed -i 's/ProtectSystem=full/ProtectSystem=false/' /etc/systemd/system/php-fpm.service

     sudo chmod +x /etc/systemd/system/php-fpm.service
     sudo systemctl daemon-reload
     sudo systemctl start php-fpm.service
     sudo systemctl enable php-fpm.service
     # -------



     # ------- Config Nginx to use php-fpm


#them cac dong include vao file
sudo cat > /etc/nginx/conf/nginx.conf <<EOF
#user  nobody;
worker_processes  1;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*.conf;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    server {
        listen       80;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        location / {
            root   html;
            index  index.html index.htm;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        
    }

}

EOF

#---------- Tao cac thu muc chua cac file .conf va vhost

     sudo mkdir /etc/nginx/conf.d
     sudo mkdir /etc/nginx/sites-available
     sudo mkdir /etc/nginx/sites-enabled


# them vao file default.conf cac thong tin ve server mac dinh
sudo cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen       80;
    

    root   /etc/nginx/html;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;

    location = /50x.html {
        root /etc/nginx/html;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}

EOF
     # -------
     #sudo chown -R nginx:nginx /etc/nginx/
     sudo systemctl restart php-fpm
     sudo systemctl restart nginx
}





# ----- MAIN ------
compile_nginx
install_php_dependencies
php_compile
#php_fpm  (tu copy dong lenh chay di, chay bash loi )