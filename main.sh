
# 创建站点
function create_site {
    #验证域名
    verify_domain
    #检测LSWS配置文件
    if [ ! -f $cf_lsws ]; then
        echoRC "服务器致命错误."
        exit 0
    fi
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
    #定义站点根
    local site_root=$vhs_root/$input_value
    #创建网站目录
    mkdir -p $site_root/{backup,logs,cert,$doc_folder}
    #添加SSL
    cat ./httpd/example.crt > $site_root/cert/ssl.crt
    cat ./httpd/example.key > $site_root/cert/ssl.key
    #创建网站配置目录
    local cf_vhost=$ols_root/conf/vhosts/${input_value}.conf
    #创建虚拟主机配置文件
    cat ./vm/default | sed "s/replace_path/$input_value/" > $cf_vhost
    #添加网站端口
    sed -i "/listener HTTPs* {/a map        $input_value $input_value" ./conf/listen/80.conf
    sed -i "/listener HTTPs* {/a map        $input_value $input_value" ./conf/listen/443.conf
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
        cd $site_root/$doc_folder
        install_wp "db_name=$db_name" "db_user=$db_user" "db_pass=$db_pass"
    else
        echo 'This a Temp Site.' >  $site_root/$doc_folder/index.php
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
    chown $ug_user:$ug_user $site_root
    chmod 711 $site_doc_root
    #修改所有者
    chown -R $ug_user:$group $site_root/$doc_folder/
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
        echo -e "${YC}1${ED}.${LG}添加一个站点${ED}"
        echo -e "${YC}2${ED}.${LG}常用站点指令${ED}"
        echo -e "${YC}3${ED}.${LG}重置面板用户密码${ED}"
        echo -e "${YC}4${ED}.${LG}重置数据库管理员密码${ED}"
        echo -e "${YC}5${ED}.${LG}临时开放数据库远程访问端口${ED}[${PC}重启服务器失效${ED}]"
        echo -e "${YC}6${ED}.${LG}添加GITHUB账号${ED}"
        echo -e "${YC}e${ED}.${LG}退出${ED}"
        echo -ne "${BC}请选择: ${ED}"
        read -a num
        case $num in
            1) create_site ;;
            2) site_cmd ;;
            3) reset_ols_user_password ;;
            4) reset_db_admin_password ;;
            5) iptables -A INPUT -p tcp --dport 3306 -j ACCEPT ;;
            6) github_token ;;
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
