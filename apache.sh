#!/bin/bash

function install_apache(){
     
}
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