source ./colors.sh
source ./defined.sh
source ./utils.sh
source ./sitecmd.sh
# 安装面板
function install_ols {
    # 生成密码
    local passwd=$(random_str)
    local ip=$(query_public_ip)
    # 安装OpenLiteSpeed
    bash <(curl -k https://raw.githubusercontent.com/litespeedtech/ols1clk/master/ols1clk.sh) --lsphp 81 --adminpassword $passwd --mariadbver 10.7 --dbrootpassword $passwd --owasp-enable --verbose
    # 安装PHP 和 扩展
    # apt install lsphp74 lsphp74-common lsphp74-intl lsphp74-curl lsphp74-opcache lsphp74-imagick lsphp74-mysql -y 
    apt install lsphp81 lsphp81-common lsphp81-intl lsphp81-curl lsphp81-opcache lsphp81-imagick lsphp81-mysql lsphp81-memcached -y
    # 备份默认站点 安全问题
    rm -rf $ols_root/Example
    # 删除默认配置项
    sed -i '/listener .*{/,/}/d; /virtualHost Example{/,/}/d' $cf_lsws
    # 添加配置项
    echo "\n" >> $cf_lsws
    echo "include $ols_root/conf/listen/*.conf" >> $cf_lsws
    echo "include $ols_root/conf/vhosts/*.conf" >> $cf_lsws
    # 安装phpMyAdmin
    install_php_my_admin
    #下载自动备份脚本
    mkdir -p $ols_root/backup
    mv ./vm/github.sh $ols_root/backup/
    mv ./vm/local.sh $ols_root/backup/
    echoGC "面板管理账号: admin"
    echoGC "面板管理密码: $passwd"
    echoGC "面板管理地址: https://$ip:7080"
    #写入安装信息
    echoSB "phpMyAdmin地址: http://$ip:8088/phpMyAdmin"
}
# 安装PHPMyAdmin
function install_php_my_admin {
    cd $ols_root
    #下载phpMyAdmin程序
    wget -O phpMyAdmin.zip https://files.phpmyadmin.net/phpMyAdmin/4.9.10/phpMyAdmin-4.9.10-all-languages.zip
    #解压文件
    unzip phpMyAdmin.zip > /dev/null 2>&1
    #删除文件
    rm phpMyAdmin.zip
    #重命名文件夹
    mv phpMyAdmin-4.9.10-all-languages phpMyAdmin
    #切换目录
    cd phpMyAdmin
    #创建临时目录 并设置权限
    mkdir tmp && chmod 777 tmp
    #创建Cookie密钥
    keybs=$(random_str 64)
    #修改配置文件1
    sed -i "/\$cfg\['blowfish_secret'\]/s/''/'$keybs'/" config.sample.inc.php
    #切换目录
    cd libraries
    #修改配置文件2
    sed -i "/\$cfg\['blowfish_secret'\]/s/''/'$keybs'/" config.default.php
    #导入sql文件
    mariadb < ./phpMyAdmin/sql/create_tables.sql
    mv ./httpd/phpMyAdmin.conf $ols_root/conf/vhosts/
    mkdir $ols_root/conf/vhosts/detial/
    cd $run_path
    mv ./vm/phpmyadmin.conf $ols_root/conf/vhosts/detial/
    #重新加载
    service lsws force-reload
    #systemctl restart lsws
}

install_ols
