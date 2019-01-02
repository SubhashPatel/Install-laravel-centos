#!/bin/bash

#######################################
# Bash script to install an Laravel PHP Framework in ubuntu
# Do not run scripat as a root user
# Author: Subhash (serverkaka.com)

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Check port 80 is Free or Not
netstat -ln | grep ":80 " 2>&1 > /dev/null
if [ $? -eq 1 ]; then
     echo go ahead
else
     echo Port 80 is allready used
     exit 1
fi

# Ask value for mysql root password
read -p 'db_root_password [secretpasswd]: ' db_root_password
echo

# Prerequisite
yum install wget zip unzip -y

# Install Apache
yum install httpd -y
systemctl start httpd
systemctl enable httpd

# Install PHP
yum install epel-release -y
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
yum repolist
yum install php71w php71w-common php71w-gd php71w-phar php71w-xml php71w-cli php71w-mbstring php71w-tokenizer php71w-openssl php71w-pdo -y

# Install MySQl
# Removing previous mysql server installation
systemctl stop mysqld.service && yum remove -y mysql-community-server && rm -rf /var/lib/mysql && rm -rf /var/log/mysqld.log && rm -rf /etc/my.cnf

# Installing mysql server (community edition)'
yum localinstall -y https://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm
yum install -y mysql-community-server

# Starting mysql server (first run)'
systemctl enable mysqld.service
systemctl start mysqld.service
tempRootDBPass="`grep 'temporary.*root@localhost' /var/log/mysqld.log | tail -n 1 | sed 's/.*root@localhost: //'`"

# Setting up new mysql server root password'
systemctl stop mysqld.service
rm -rf /var/lib/mysql/*logfile*
wget -O /etc/my.cnf "https://my-site.com/downloads/mysql/512MB.cnf"
systemctl start mysqld.service
mysqladmin -u root --password="$tempRootDBPass" password "$db_root_password"
mysql -u root --password="$db_root_password" -e <<-EOSQL
    DELETE FROM mysql.user WHERE User='';
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    DELETE FROM mysql.user where user != 'mysql.sys';
    CREATE USER 'root'@'%' IDENTIFIED BY '${mysqlRootPass}';
    GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
EOSQL
systemctl status mysqld.service

# Download Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
/usr/local/bin/composer create-project laravel/laravel /var/www/html/laravel

# Set the correct DocumentRoot And Configure VHost
cd /etc/httpd/conf/
rm -f httpd.conf
wget https://s3.amazonaws.com/serverkaka-pubic-file/laravel/httpd.conf

# Restart Apache
systemctl restart httpd

# Set the Permissions
chown -R apache:apache /var/www/html/laravel
chmod -R 755 /var/www/html/laravel/storage
setenforce 0

# Adjust firewall
firewall-cmd –permanent –add-port=80/tcp
firewall-cmd –permanent –add-port=443/tcp
firewall-cmd --reload

echo Laravel installation completed.
