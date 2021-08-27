#!/bin/bash


function compile_apache(){
#tat selinux 
sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

sudo yum update -y
sudo yum install epel-release -y
sudo yum install vim wget -y

#Installation procedure
sudo yum groupinstall " Development Tools"  -y
sudo yum install expat-devel pcre pcre-devel openssl-devel -y




#Download the Apache source code along with apr and apr-util

sudo wget https://github.com/apache/httpd/archive/refs/tags/2.4.48.tar.gz -O httpd-2.4.48.tar.gz

sudo wget https://github.com/apache/apr/archive/refs/tags/1.7.0.tar.gz -O apr-1.7.0.tar.gz

sudo wget https://github.com/apache/apr-util/archive/refs/tags/1.6.1.tar.gz -O apr-util-1.6.1.tar.gz


sudo tar -xzf httpd-2.4.48.tar.gz
sudo tar -xzf apr-1.7.0.tar.gz
sudo tar -xzf apr-util-1.6.1.tar.gz


#place apr and apr-util directory inside srclib directory which is located under HTTPD directory
sudo mv apr-1.7.0 httpd-2.4.48/srclib/apr
sudo mv apr-util-1.6.1 httpd-2.4.48/srclib/apr-util


#Now move to HTTPD directory
cd httpd-2.4.48

#Compilation of Apache source
sudo ./buildconf
sudo ./configure --enable-ssl --enable-so --with-mpm=event --with-included-apr --prefix=/usr/local/apache2

sudo make
sudo make install

#Create a script file for httpd command under /etc/profile.d/ directory
sudo echo "pathmunge /usr/local/apache2/bin" > /etc/profile.d/httpd.sh


# Create dedicated user and group for Apache
sudo groupadd apache
sudo useradd apache -g apache --no-create-home --shell /sbin/nologin

# change config file httpd.conf
FILE=/usr/local/apache2/conf/httpd.conf
sudo sed -i 's/User daemon/User apache/' $FILE
sudo sed -i 's/Group daemon/Group apache/' $FILE



#httpd service init script
sudo cat > /etc/systemd/system/httpd.service <<EOF

[Unit]
Description=The Apache HTTP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/apache2/bin/apachectl -k start
ExecReload=/usr/local/apache2/bin/apachectl -k graceful
ExecStop=/usr/local/apache2/bin/apachectl -k graceful-stop
PIDFile=/usr/local/apache2/logs/httpd.pid
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start httpd
sudo systemctl enable httpd
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
     sudo curl -O -L  https://github.com/php/php-src/archive/refs/tags/php-7.4.22.tar.gz
     tar -xzf php-7.4.22.tar.gz
     cd php-src-php-7.4.22
     sudo ./buildconf --force
     sudo ./configure --prefix=/usr/local/php --with-apxs2=/usr/local/apache2/bin/apxs \
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


     sudo cp /home/centos/php-src-php-7.4.22/php.ini-development /usr/local/php/etc/php.ini

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
listen.owner = apache
listen.group = apache
listen.mode = 0660
user = apache
group = apache
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
     sudo cp /home/centos/php-src-php-7.4.22/sapi/fpm/php-fpm.service /etc/systemd/system
     # Chinh lai quyen de dc ghi file log
     sudo sed -i 's/ProtectSystem=full/ProtectSystem=false/' /etc/systemd/system/php-fpm.service

     sudo chmod +x /etc/systemd/system/php-fpm.service
     sudo systemctl daemon-reload
     sudo systemctl start php-fpm.service
     sudo systemctl enable php-fpm.service
     # -------



     # ------- Config Apache to use php-fpm, uncomment cac dong sau
     FILE=/usr/local/apache2/conf/httpd.conf
     sudo sed -i 's/#LoadModule proxy_module modules\/mod_proxy.so/LoadModule proxy_module modules\/mod_proxy.so/' $FILE
     sudo sed -i 's/#LoadModule proxy_fcgi_module modules\/mod_proxy_fcgi.so/LoadModule proxy_fcgi_module modules\/mod_proxy_fcgi.so/' /$FILE

#Them doan nay vao cuoi FILE
sudo cat >> $FILE <<EOF
<FilesMatch \.(php|phar)>
SetHandler "proxy:fcgi://127.0.0.1:9000"
</FilesMatch>
EOF
     # -------

     sudo systemctl restart php-fpm
     sudo systemctl restart httpd
}




# ------ MAIN -------
compile_apache
install_php_dependencies
php_compile
php_fpm

