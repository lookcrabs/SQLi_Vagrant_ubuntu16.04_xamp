#!/bin/bash
PHP_FPM_PATH_INI='/etc/php/7.0/fpm/php.ini'
PHP_FPM_POOL_CONF='/etc/php/7.0/fpm/pool.d/www.conf'
MYSQL_ROOT_PW='zxc098$'
###purely for documentation reasons. have to manually change throughout the doc
MYSQL_USR_NAME='Steeef'
MYSQL_USR_PASS='orange-45'


install_base() {
    add-apt-repository -y ppa:nginx/stable
    sudo apt-get update
    sudo apt-get dist-upgrade -y
    sudo apt-get install -y nginx mariadb-server mariadb-client php php-common php-cgi php-fpm php-gd php-cli php-pear php-mcrypt php-mysql php-gd git vim
}


config_mysql(){
    mysqladmin -u root password "${MYSQL_ROOT_PW}"
    ##config the mysql config file for root so it doesn't prompt for password. Also sets pw in plain text for easy access.  
    ## Don't forget to change the password here!! 

cat <<EOF > /root/.my.cnf
[client]
user="root"
password="${MYSQL_ROOT_PW}"
EOF
    service mysql restart


cat <<EOF >> /etc/mysql/mariadb.conf.d/50-server.cnf
general-log
general-log-file = /var/log/mysql/queries.log
log-output=file
EOF

}


config_nginx(){

cat << 'EOF' > /etc/nginx/sites-enabled/default
server
{
    listen  80;
    root /var/www/html;
    index index.php index.html index.htm;
    #server_name localhost
    location "/"
    {
        index index.php index.html index.htm;
        #try_files $uri $uri/ =404;
    }

    location ~ \.php$
    {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $request_filename;
    }
}
EOF

    systemctl restart nginx
}

config_php(){
    ##Config PHP FPM INI to disable some security settings
    
    sed -i 's/^;cgi.fix_pathinfo.*$/cgi.fix_pathinfo = 0/g' ${PHP_FPM_PATH_INI}
    sed -i 's/allow_url_include = Off/allow_url_include = On/g' ${PHP_FPM_PATH_INI}
    sed -i 's/allow_url_fopen = Off/allow_url_fopen = On/g' ${PHP_FPM_PATH_INI}
    sed -i 's/safe_mode = On/safe_mode = Off/g' ${PHP_FPM_PATH_INI}
    echo "magic_quotes_gpc = Off" >> ${PHP_FPM_PATH_INI}
    sed -i 's/display_errors = Off/display_errors = On/g' ${PHP_FPM_PATH_INI}

    ##explicitly set pool options (these are defaults in ubuntu 16.04 so i'm commenting them out. If they are not defaults for you try uncommenting these
    #sed -i 's/^;security.limit_extensions.*$/security.limit_extensions = .php .php3 .php4 .php5 .php7/g' /etc/php/7.0/fpm/pool.d/www.conf
    #sed -i 's/^listen.owner.*$/listen.owner = www-data/g' /etc/php/7.0/fpm/pool.d/www.conf
    #sed -i 's/^listen.group.*$/listen.group = www-data/g' /etc/php/7.0/fpm/pool.d/www.conf
    #sed -i 's/^;listen.mode.*$/listen.mode = 0660/g' /etc/php/7.0/fpm/pool.d/www.conf


    systemctl restart php7.0-fpm
}

install_sqli_site() {

    ## setup the database. you obviously don't need N here. force of habit. 
     mysql -BNe "DROP DATABASE IF EXISTS butts;"
     mysql -BNe "CREATE DATABASE butts;"
     mysql -BNe "CREATE TABLE butts.blog ( id int(11) DEFAULT NULL, content varchar(100) DEFAULT NULL );"
     mysql -BNe "INSERT INTO butts.blog VALUES (1,'What...is your name?');"
     mysql -BNe "INSERT INTO butts.blog VALUES (2,'What...is your quest?')"
     mysql -BNe "INSERT INTO butts.blog VALUES (3,'What...is your favorite color?')"
     mysql -BNe "INSERT INTO butts.blog VALUES (4,'What...is the capital of Assyria?')"
     mysql -BNe "INSERT INTO butts.blog VALUES (5,'What...goes black, white, black, white, black, white?')"
     mysql -BNe "INSERT INTO butts.blog VALUES (6,'What...is the airspeed velocity of an unladen swallow?')"
     mysql -BNe "GRANT ALL ON *.* TO '"${MYSQL_USR_NAME}"'@'localhost' IDENTIFIED BY '"${MYSQL_USR_PASS}"';"

cat <<'EOF' > /var/www/html/index.php
<?php

if (!$link = new mysqli('localhost', 'Steeef', 'orange-45', 'butts')) {
    echo 'Could not connect to mysql';
    exit;
}

if (isset($_GET['id'])) {
    $id = $_GET['id'];
} else {
    $id = 1;
}


$sql    = "SELECT * FROM blog where id = '$id'";
$result = $link->query($sql);

if (!$result) {
    echo "DB Error, could not query the database\n";
    echo 'MySQL Error: ' . mysql_error();
    exit;
}

while ($row = $result->fetch_assoc()) {
    echo $row['content'];
}

$result->free();
$link->close();

?>
EOF
    chown www-data. /var/www/html/index.php

}


install_base
config_mysql
config_nginx
config_php
install_sqli_site
