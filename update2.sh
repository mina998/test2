#!/bin/bash
RC="\033[38;5;196m"; ED="\033[0m";

apt update -y
# 安装PHP 和 扩展
apt install lsphp74 lsphp74-common lsphp74-intl lsphp74-curl lsphp74-opcache lsphp74-imagick lsphp74-mysql -y 
apt install lsphp81 lsphp81-common lsphp81-intl lsphp81-curl lsphp81-opcache lsphp81-imagick lsphp81-mysql lsphp81-memcached -y

# OpenLiteSpeed 默认安装目录
ols_root=/usr/local/lsws
# 面板配置文件
cf_lsws=$ols_root/conf/httpd_config.conf
# 下载文件基础URL
repo=https://raw.githubusercontent.com/mina998/lswp/new
install_path='/usr/local/bin'
vm2=$install_path/vm
httpd2=$install_path/httpd

cd $install_path

rm $httpd2/vhost
wget -P httpd $repo/httpd/vhost
wget -P vm $repo/vm/default
wget -P vm $repo/vm/vhconf.81
#下载自动备份脚本
wget -P vm $repo/github.sh && chmod +x $vm2/github.sh
wget -P vm $repo/local.sh && chmod +x $vm2/local.sh

rm lswp
wget $repo/lswp
chmod +x lswp

#下载自动备份脚本
mkdir -p $ols_root/backup
mv ./vm/github.sh $ols_root/backup/
mv ./vm/local.sh $ols_root/backup/

# 开启数据库远程访问
sed -i 's/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
# 重置数据库管理员密码
db_admin_user=$(mariadb -Nse 'select user from mysql.user where host="%";')
if [ -z "$db_admin_user" ]; then
    #创建数据库管理员账号和密码
    db_root_usr=$(tr -dc 'a-zA-Z' </dev/urandom | head -c 8)
    #设置账号密码
    /usr/bin/mariadb -Nse "GRANT ALL PRIVILEGES ON *.* TO '$db_root_usr'@'%' IDENTIFIED BY '$db_root_usr' WITH GRANT OPTION;"
    /usr/bin/mariadb -Nse "flush privileges;"
fi

# 生成数据库名
function name_from_str {
    echo "$1" | sed 's/\./_/g' | sed 's/-/_/g'
}

# 操作站点
cd /www
# 删除所有虚拟机配置
for folder in */; do
    site=$(echo "$folder" | sed 's/\///')
    sed -i "/virtual[hH]ost\s*$site\s*{/,/}/d" $cf_lsws
done

for folder in */; do
    site=$(echo "$folder" | sed 's/\///')

    ug_user=$(name_from_str $site)
    vhost_path=$ols_root/conf/vhosts/$site
    #创建虚拟主机配置文件
    cat "$vm2/default" | sed "s/replace_path/$site/" > $vhost_path/default
    cat "$vm2/vhconf.81" | sed "s/replace_path/$site/" | sed "s/php_ext_user/$ug_user/g" > $vhost_path/vhconf.81

    #在主配置文件中指定虚拟主机配置信息
    cat $httpd2/vhost | sed "s/\$host_name/$site/" | sed "s/\$VH_NAME/$site/g" >> $cf_lsws

    #创建用户组
    if ! getent group $ug_user >/dev/null; then
        groupadd $ug_user
    fi
    #创建用户
    if ! id $ug_user >/dev/null 2>&1; then
        useradd -M -g $ug_user $ug_user
    fi

    site_doc_root=/www/$site
    #修改所有者
    chown $ug_user:$ug_user $site_doc_root
    chmod 711 $site_doc_root
    chown -R $ug_user:nogroup $site_doc_root/public_html/
    
done

