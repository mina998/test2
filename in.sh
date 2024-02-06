#!/bin/bash

repo=https://raw.githubusercontent.com/mina998/test2/main
# OpenLiteSpeed 默认安装目录
run_path=$(pwd)
ols_root=/usr/local/lsws
apt update -y
#安装所需工具
apt-get install socat cron curl gnupg unzip iputils-ping apt-transport-https ca-certificates software-properties-common -y
#添加存储库
wget -O - https://repo.litespeed.sh | bash
#安装面板
apt install openlitespeed -y
    #获取面板默认安装PHP版本
    local php=$(ls $ols_root | grep -o -m 1 "lsphp[78][0-9]$")
#安装WordPress 的 PHP 扩展
if [ -n "$php" ] ; then
    #删除其他PHP
    [ -f /usr/bin/php ]  && rm -f /usr/bin/php
    #创建PHP软链接
    ln -s $ols_root/$php/bin/php /usr/bin/php
fi
# 安装PHP 和 扩展
apt install lsphp81 lsphp81-common lsphp81-intl lsphp81-curl lsphp81-opcache lsphp81-imagick lsphp81-mysql lsphp81-memcached -y
#添加密钥
apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
#添加仓库
sh -c "echo 'deb https://mirror.rackspace.com/mariadb/repo/11.1/$os_name $os_version main' >>/etc/apt/sources.list"
#开始安装
apt update && apt install mariadb-server -y
#下载phpMyAdmin程序
wget -O phpMyAdmin.zip https://files.phpmyadmin.net/phpMyAdmin/4.9.10/phpMyAdmin-4.9.10-all-languages.zip
#解压文件
unzip phpMyAdmin.zip > /dev/null 2>&1
#移动到指定位置
mv phpMyAdmin-4.9.10-all-languages $ols_root/phpMyAdmin

# ------Mariadb Config------------
cd $ols_root
# 启动数据库服务
systemctl restart mariadb
#创建数据库管理员账号和密码
root_usr=$(tr -dc 'a-zA-Z' </dev/urandom | head -c 8)
root_pwd=$(head -c 12 /dev/urandom | base64 | tr -d '/' | tr -d '=')
#设置账号密码
/usr/bin/mariadb -Nse "GRANT ALL PRIVILEGES ON *.* TO '$root_usr'@'%' IDENTIFIED BY '$root_pwd' WITH GRANT OPTION;"
/usr/bin/mariadb -Nse "flush privileges;"

# -------phpMyAdmin Config-----------------
#创建临时目录 并设置权限
mkdir phpMyAdmin/tmp && chmod 777 phpMyAdmin/tmp
#创建Cookie密钥
keybs=$(head -c 64 /dev/urandom | base64 | tr -d '/' | tr -d '=')
#修改配置文件1
sed -i "/\$cfg\['blowfish_secret'\]/s/''/'$keybs'/" ./phpMyAdmin/config.sample.inc.php
#修改配置文件2
sed -i "/\$cfg\['blowfish_secret'\]/s/''/'$keybs'/" ./phpMyAdmin/libraries/config.default.php
#导入sql文件
mariadb < ./phpMyAdmin/sql/create_tables.sql

# -------LSWS Config----------------
rm -rf $ols_root/Example/
mkdir backup && mkdir conf/listen && mkir conf/vhosts/detail
#下载备份脚本
wget -P backup $repo/github.sh && chmod +x ./backup/github.sh
wget -P backup $repo/local.sh && chmod +x ./backup/local.sh
#下载证书文件
curl -k $repo/httpd/example.crt > ./conf/example.crt
curl -k $repo/httpd/example.key > ./conf/example.key
# 下载配置文件
wget -P conf/listen $repo/listen/80.conf
wget -P conf/listen $repo/listen/443.conf
wget -P conf/listen $repo/listen/8090.conf

wget -P conf/vhosts $repo/httpd/phpmyadmin.conf 
wget -P conf/vhosts/detail $repo/vm/phpmyadmin.conf
# 删除默认配置项
cf_lsws=$ols_root/conf/httpd_config.conf
sed -i '/listener .*{/,/}/d; /virtual[hH]ost Example{/,/}/d' $cf_lsws
# 添加配置项
echo -e "\n" >> $cf_lsws
echo "include $ols_root/conf/listen/*.conf" >> $cf_lsws
echo "include $ols_root/conf/vhosts/*.conf" >> $cf_lsws


# echoGC "MySQL管理员账号密码"
# echoSB "$root_usr / $root_pwd"


