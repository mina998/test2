source ./colors.sh
source ./defined.sh
source ./utils.sh
source ./sitecmd.sh
# 安装面板
function install_ols {
    cd $run_path
    #判断面板是否安装
    if [ -f "$ols_root/bin/lswsctrl" ]; then
        echoCC "检测到OpenLiteSpeed已安装"
        return $?
    fi
    #检测虚拟机保存目录
    if [ -d $vhs_root ]; then
        echoCC "请确保没有${vhs_root}文件夹"
        return $?
    fi
    #创建防火墙规则
    firewall_rules_create
    apt update -y
    #安装所需工具
    apt-get install socat cron curl gnupg unzip iputils-ping apt-transport-https ca-certificates software-properties-common -y
    #创建所有站点保存目录
    mkdir -p $vhs_root
    #添加存储库
    wget -O - https://repo.litespeed.sh | bash
    #安装面板
    apt install openlitespeed -y
    #获取面板默认安装PHP版本
    local php=$(ls $ols_root | grep -o -m 1 "lsphp[78][0-9]$")
    #安装WordPress 的 PHP 扩展
    if [ -n "$php" ] ; then
        #wordpress 必须组件 lsphp74-redis lsphp74-memcached
        apt install ${php}-imagick ${php}-curl ${php}-intl ${php}-opcache -y
        #删除其他PHP
        [ -f /usr/bin/php ]  && rm -f /usr/bin/php
        #创建PHP软链接
        ln -s $ols_root/$php/bin/php /usr/bin/php
    fi
    # 安装PHP 和 扩展
    # apt install lsphp74 lsphp74-common lsphp74-intl lsphp74-curl lsphp74-opcache lsphp74-imagick lsphp74-mysql -y 
    apt install lsphp81 lsphp81-common lsphp81-intl lsphp81-curl lsphp81-opcache lsphp81-imagick lsphp81-mysql lsphp81-memcached -y
    #添加监听器
    cat ./httpd/listener >> $ols_root/conf/httpd_config.conf
    #添加SSL证书
    cat ./httpd/example.crt > $ols_root/conf/example.crt
    cat ./httpd/example.key > $ols_root/conf/example.key
    # 备份默认站点 安全问题
    mv $ols_root/Example/html $ols_root/Example/html.bak
    # 重建一个空目录 防止服务器读取配置文件出错
    mkdir $ols_root/Example/html
    #下载自动备份脚本
    mkdir -p $ols_root/backup
    mv ./vm/github.sh $ols_root/backup/
    mv ./vm/local.sh $ols_root/backup/
    #安装 MariaDB
    install_maria_db
    #重新加载配置
    service lsws force-reload
    echoGC '面板管理账号/密码'
    echo -ne "$SB"
    cat $ols_root/adminpasswd | grep -oE admin.*
    echo -ne "$ED"
    echoGC '面板地址'
    echoSB "https://$(query_public_ip):7080"
}
# 安装MariaDB
function install_maria_db {
    cd $run_path
    #判断是否安装过MariaDB
    if [ -f "/usr/bin/mariadb" ]; then
        echoCC "检测到MariaDB已安装"
        return $?
    fi
    #添加密钥
    apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    #添加仓库
    sh -c "echo 'deb https://mirror.rackspace.com/mariadb/repo/11.1/$os_name $os_version main' >>/etc/apt/sources.list"
    #开始安装
    apt update && apt install mariadb-server -y
    #重启防止出错
    systemctl restart mariadb
    #创建数据库管理员账号和密码
    local root_usr=$(tr -dc 'a-zA-Z' </dev/urandom | head -c 8)
    local root_pwd=$(random_str 12)
    #设置账号密码
    /usr/bin/mariadb -Nse "GRANT ALL PRIVILEGES ON *.* TO '$root_usr'@'%' IDENTIFIED BY '$root_pwd' WITH GRANT OPTION;"
    /usr/bin/mariadb -Nse "flush privileges;"
    echoGC "MySQL管理员账号密码"
    echoSB "$root_usr / $root_pwd"
    # 开启远程访问
    sed -i 's/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
    systemctl restart mariadb
}
# 安装PHPMyAdmin
function install_php_my_admin {
    #判断面板是否安装
    local ols=$(check_ols_exist)
    if [ -n "$ols" ]; then
        echoCC $ols
        return $?
    fi
    #切换工作目录
    local example=$ols_root/Example
    cd $example
    if [ -d "phpMyAdmin" ]; then
        echoCC '检测到phpMyAdmin已安装!'
        return $?
    fi
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
    mariadb < $example/phpMyAdmin/sql/create_tables.sql
    #添加访问路径
    cat $run_path/vm/context | sed s/context_path/phpMyAdmin/g >> $ols_root/conf/vhosts/Example/vhconf.conf
    #重新加载
    service lsws force-reload
    #systemctl restart lsws
    #写入安装信息
    echoGC "phpMyAdmin安装完成."
    echoSB "phpMyAdmin地址: http://$(query_public_ip):8088/phpMyAdmin"
    cd $run_path
}
# 创建站点
function create_site {
    cd $run_path
    #判断面板是否安装
    local ols=$(check_ols_exist)
    if [[ -n $ols ]]; then
        echoCC $ols
        return $?
    fi
    #验证域名
    verify_domain
    #检测LSWS配置文件
    [ ! -f $cf_lsws ] && echoRC "服务器致命错误." && exit 0
    #域名是否绑定到其他站点
    local is_domain=$(query_domain "$input_value")
    if [ -n "$is_domain" ]; then
        echoCC "$is_domain"
        return $?
    fi
    #站点是否存在
    if [ -d "$vhs_root/$input_value" ]; then
        echoCC "[$input_value]站点已存在."
        return $?
    fi
    #设置数据库变量
    local db_name=$(name_from_str $input_value)
    local ug_user=$db_name
    local db_user=$db_name
    local db_pass=$(random_str 10)
    #数据库是否存在
    if [ -n "$(is_db_exist $db_name)" ]; then
        echoCC "数据库已存在."
        return $?
    fi
    #定义站点文档根
    local site_doc_root=$vhs_root/$input_value
    #创建网站目录
    mkdir -p $site_doc_root/{backup,logs,cert,$doc_folder}
    #添加SSL
    cat ./httpd/example.crt > $site_doc_root/cert/ssl.crt
    cat ./httpd/example.key > $site_doc_root/cert/ssl.key
    #创建网站配置目录
    local vhost_path=$ols_root/conf/vhosts/$input_value
    mkdir -p $vhost_path
    #创建虚拟主机配置文件
    cat ./vm/default | sed "s/replace_path/$input_value/" > $vhost_path/default
    cat ./vm/vhconf.81 | sed "s/replace_path/$input_value/" | sed "s/php_ext_user/$ug_user/g" > $vhost_path/vhconf.81
    #在主配置文件中指定虚拟主机配置信息
    cat ./httpd/vhost | sed "s/\$host_name/$input_value/" | sed "s/\$VH_NAME/$input_value/g" >> $cf_lsws
    #添加网站端口
    sed -i "/listener HTTPs* {/a map        $input_value $input_value" $cf_lsws
    #设置权限
    chown -R lsadm:$group $vhost_path
    #创建数据库和用户
    mariadb -Nse "create database $db_name"
    mariadb -Nse "grant all privileges on $db_name.* to '$db_user'@'localhost' identified by '$db_pass'"
    mariadb -Nse "flush privileges"
    #安装WordPress
    echo -ne "$BC是否安装WordPrss(y/N):$ED "
    read -a iswp
    if [ "$iswp" = "y" -o "$iswp" = "Y" ]; then
        cd $site_doc_root/$doc_folder
        install_wp "db_name=$db_name" "db_user=$db_user" "db_pass=$db_pass"
    else
        echo 'This a Temp Site.' >  $site_doc_root/$doc_folder/index.php
    fi
    #创建用户组
    if ! getent group $db_name >/dev/null; then
        groupadd $db_name
    fi
    #创建用户
    if ! id $db_name >/dev/null 2>&1; then
        useradd -M -g $db_name $db_name
    fi
    #修改所有者
    chown $ug_user:$ug_user $site_doc_root
    chmod 711 $site_doc_root
    #切换工作目录
    cd $site_doc_root
    #修改所有者
    chown -R $ug_user:$group $doc_folder/
    #修改目录权限
    find $doc_folder/ -type d -exec chmod 750 {} \;
    #修改文件权限
    find $doc_folder/ -type f -exec chmod 640 {} \;
    cd $run_path
    systemctl restart lsws
    clear
    echoGC "站点安装完成, ${CC}以下信息只显示一次."
    echoSB "地址: http://$input_value"
    if [ -n "$wp_user" ]; then
        echoSB "账号: $wp_user"
        echoSB "密码: $wp_pass"
    fi
    echoGC "数据库信息"
    echoSB "名称: ${db_name}"
    echoSB "账号: ${db_user}"
    echoSB "密码: ${db_pass}"
    input_value=''
}
# 重置面板账号密码
function reset_ols_user_password {
    if [ ! -d $ols_root ]; then
        echoCC "未安装OpenLiteSpeed"
        return $?
    fi
    echoCC "面板用户密码重置成功后.原有的所有用户将删除."
    local user; local pass1; local pass2
    while true; do
        echo -ne "${BC}输入账号(默认:admin): ${ED}"
        read -a user
        [ -z "$user" ] && user=admin
        [ $(expr "$user" : '.*') -ge 5 ] && break
        echoCC "账号长度不能小于5位."
    done
    while true; do
        echo -ne "${BC}输入密码: ${ED}"
        read -a pass1
        if [ `expr "$pass1" : '.*'` -lt 6 ]; then
            echoCC "密码长度不能小于6位."
            continue
        fi
        echo -ne "${BC}密码确认: ${ED}" 
        read -a pass2
        if [ "$pass1" != "$pass2" ]; then
            echoCC "密码不匹配,再试一次."
            continue
        fi
        break
    done
    cd $ols_root/admin/fcgi-bin
    local encrypt_pass=$(./admin_php -q ../misc/htpasswd.php $pass1)
    echo "$user:$encrypt_pass" > ../conf/htpasswd
    cd $run_path
    echoGC "面板用户密码重置完成."
}
# 重置数据库管理员密码
function reset_db_admin_password {
    local user=$(mariadb -Nse 'select user from mysql.user where host="%";')
    echoSB "数据库管理员账号: $user"
    echo -ne "${BC}请输入密码(长度不能小于6): ${ED}"
    read -a password2
    if [ "${#password2}" -lt 5 ]; then
        echoCC "密码长度不能小于5"
        return $?
    fi
    mariadb -Nse "ALTER USER '$user'@'%' IDENTIFIED BY '$password2';"
    mariadb -Nse "flush privileges;"
    echoCC "密码修改完成"
    echoGC "你的密码是: $password2"
}
# 切换PHP版本
function switch_php_version {
    echo -e "${CC}0. ${LG}默认版本 ${CC}1. ${LG}PHP8.1${ED}"
    echo -ne "${BC}请选择(直接回车退出): ${ED}"
    read -a version_php_no
    if [ -z "$version_php_no" ]; then
        echoCC "已退出"
        return $?
    fi
    # 切换到默认版本
    if [ "$version_php_no" == "0" ]; then
        sed -i "s/\($input_value\/\).*\.81/\1default/" $cf_lsws
    fi
    # 切换到PHP81版本
    if [ "$version_php_no" == "1" ]; then
        sed -i "s/\($input_value\/\)default/\1vhconf.81/" $cf_lsws
    fi
    systemctl restart lsws
    echoGC 'PHP版本切换完成.'
}
# GITHUB
function github_token {
    local github=/root/.lsws/github
    if [ -f $github ]; then
        echoGC $(cat $github)
    else
        mkdir -p /root/.lsws
        echoGC "未添加"
    fi
    echo -e "${BC}格式: user@token${ED} [${PC}错误信息备份时将影响性能${ED}]"
    read -a token2
    if [ -z "$token2" ]; then 
        echoCC "输入为空."
    else
        echo $token2 > $github
        echoCC "Github: $token2"
    fi
}
# 常用站眯指令
function site_cmd {
    cd $run_path
    #判断面板是否安装
    local ols=$(check_ols_exist)
    if [[ -n $ols ]]; then
        echoCC $ols
        return $?
    fi
    #查看所有站点
    display_vm_host
    [ -z "$input_value" ] && echoPC "获取站点信息失败." && return $?
    #定义站点根目录
    web_root=$vhs_root/$input_value
    while true; do
        #显示菜单
        echo -e "${YC}1${ED}.${LG}备份${ED}"
        echo -e "${YC}2${ED}.${LG}还原${ED}"
        echo -e "${YC}3${ED}.${LG}删除备份${ED}"
        echo -e "${YC}4${ED}.${LG}删除站点${ED}"
        echo -e "${YC}5${ED}.${LG}切换PHP版本${ED}"
        echo -e "${YC}6${ED}.${LG}定时备份到本机${ED}"
        echo -e "${YC}a${ED}.${LG}定时备份到GITHUB${ED}"
        echo -e "${YC}d${ED}.${LG}追加域名${ED}"
        echo -e "${YC}f${ED}.${LG}安装证书${ED}"
        echo -e "${YC}e${ED}.${LG}返回${ED}"
        echo -ne "${BC}请选择: ${ED}"
        read -a num2
        case $num2 in 
            1) backup2 ;;
            2) restore2 ;;
            3) del_backup_file ;;
            4) delete_site ;;
            5) switch_php_version ;;
            6) scheduled_tasks_backup_to_local $input_value ;;
            a) scheduled_tasks_backup_to_github $input_value ;;
            d) domain_add ;;
            f) cert_ssl_install ;;
            e) break ;;
            *) echoCC '输入有误.'
        esac
        continue
    done
    input_value=''
    cd $run_path
}
# 设置菜单
function menu {
    while true; do
        echo -e "${YC}1${ED}.${LG}安装面板和数据库${ED}[${PC}必须${ED}]"
        echo -e "${YC}2${ED}.${LG}安装PHPMyAdmin${ED}"
        echo -e "${YC}3${ED}.${LG}添加一个站点${ED}"
        echo -e "${YC}4${ED}.${LG}常用站点指令${ED}"
        echo -e "${YC}5${ED}.${LG}重置面板用户密码${ED}"
        echo -e "${YC}6${ED}.${LG}重置数据库管理员密码${ED}"
        echo -e "${YC}7${ED}.${LG}临时开放数据库远程访问端口${ED}[${PC}重启服务器失效${ED}]"
        echo -e "${YC}8${ED}.${LG}添加GITHUB账号${ED}"
        echo -e "${YC}e${ED}.${LG}退出${ED}"
        echo -ne "${BC}请选择: ${ED}"
        read -a num
        case $num in
            1) install_ols ;;
            2) install_php_my_admin ;;
            3) create_site ;;
            4) site_cmd ;;
            5) reset_ols_user_password ;;
            6) reset_db_admin_password ;;
            7) iptables -A INPUT -p tcp --dport 3306 -j ACCEPT ;;
            8) github_token ;;
            e) exit 0 ;;
            *) clear
        esac
        continue
    done
    clear
}
# echoGC "WordPress外贸建站学习QQ群:783107859"
echoCC "仅支持Debian[9, 10, 11] 和 Ubuntu[18.04, 20.04]"
menu
