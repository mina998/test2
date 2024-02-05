# 创建随机字符
function random_str {
    local length=10
    [ -n "$1" ] && length=$1
    echo $(head -c $length /dev/urandom | base64 | tr -d '/' | tr -d '=')
}
# 检测数据库是否存在
function is_db_exist {
    #判断数据库是否存在 
    echo $(mariadb -Nse "show DATABASES like '$1'")
}
# 从网络获取本机IP(防止有些机器无法获取公网IP)  
function query_public_ip {
#    echo $(wget -U Mozilla -qO - http://ip.42.pl/raw)
    echo $(curl -s https://ip.idsss.workers.dev)
}
# 创建防火墙规则
function firewall_rules_create {
    #是否存在iptables
    if [ -z "$(which iptables)" ]; then
        return $?
    fi
    #添加防火墙规则
    cat ./httpd/firewall > /etc/iptables.rules
    #添加重启自动加载防火寺规则
    cat ./httpd/rc.local > /etc/rc.local
    #ssh端口
    local ssh=$(ss -tapl | grep sshd | awk 'NR==1 {print $4}' | cut -f2 -d :)
    [ -n "$ssh" ] && sed -i "s/22,80/$ssh,80/" /etc/iptables.rules
    #添加执行权限
    chmod +x /etc/rc.local
    #启动服务
    systemctl start rc-local
    #
    echoGC "重写防火墙规则完成."
}
# 检测是否安装OLS
function check_ols_exist {
    #判断面板是否安装
    if [ ! -f "$ols_root/bin/lswsctrl" ]; then
        echo "OpenLiteSpeed未安装"
        return $?
    fi
    #判断是否安装过MariaDB
    if [ ! -f "/usr/bin/mariadb" ]; then
        echo "MariaDB未安装"
        return $?
    fi
}
# 生成数据库名
function name_from_str {
    echo "$1" | sed 's/\./_/g' | sed 's/-/_/g'
}
# 验证域名
function verify_domain {
    #接收输入域名
    while true; do
        echo -ne "$BC请输入域名(eg:www.demo.com):$ED "
        read -a input_value
        input_value=$(echo $input_value | tr 'A-Z' 'a-z')
        input_value=$(echo $input_value | awk '/^[a-z0-9][-a-z0-9]{0,62}(\.[a-z0-9][-a-z0-9]{0,62})+$/{print $0}')
        if [ -z "$input_value" ]; then
            echoYC "域名有误,请重新输入!!!"
            continue
        fi
        break
    done
}
# 查询所有虚拟主机
function query_vm_host {
    if [ ! -f $cf_lsws ]; then
        echoCC "未找到服务器配置文件."
        exit 0
    fi
    echo $(grep -i 'virtualHost' $cf_lsws | grep -v 'Example' | awk '{print $2}')
}
# 选择虚拟主机
function display_vm_host {
    local vhost_list=(`query_vm_host`)
    host_name=; i=0
    while [[ $i -lt ${#vhost_list[@]} ]]; do
        echo -e "${CC}${i})${ED} ${vhost_list[$i]}"
        let i++ 
    done
    [ $i -eq 0 ] && echoCC "没有可选站点."
    while [[ $i -gt 0 ]] ; do
        echo -ne "${BC}请选择域名,输入序号:${ED}"
        read -a num
        expr $num - 1 &> /dev/null
        if [ $? -lt 2 ]; then
            [ -n "${vhost_list[$num]}" ] && input_value=${vhost_list[$num]} && break
        fi
        echoYC "输入有误."
    done
}
# 添加一个WordPress网站
function install_wp {
    #安装WP CLI
    if [ ! -e /usr/local/bin/wp ] && [ ! -e /usr/bin/wp ]; then 
        wget -Nq https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        #下载失败 初始化为空站点
        if [ $? -gt 0 ]; then
            echo 'this a temp site.' > index.php
            echoRR "${RC}安装WP CLI失败${ED}, ${CC}初始化成一个空站点."
            return $?
        fi 
        chmod +x wp-cli.phar
        echo $PATH | grep '/usr/local/bin' >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            mv wp-cli.phar /usr/local/bin/wp
        else
            mv wp-cli.phar /usr/bin/wp
        fi
    fi
    #接收用户输入
    echo -ne "$BC请输入站点管理员账号(默认:admin):$ED "
    read -a wp_user; [ -z "$wp_user" ] && wp_user=admin 
    echo -ne "$BC请输入站点管理员密码(默认:admin):$ED "
    read -a wp_pass; [ -z "$wp_pass" ] && wp_pass=admin
    echo -ne "$BC请输入站点管理员邮箱(默认:admin@$input_value):$ED "
    read -a wp_mail; [ -z "$wp_mail" ] && wp_mail="admin@$input_value"
    #下载WP程序 wp core download --locale=zh_CN --allow-root
    wp core download --allow-root
    #添加伪静态规则
    cat $run_path/vm/htaccess > .htaccess
    #把参数转换成变量
    local db_name; local db_user; local db_pass; eval "$1" "$2" "$3"
    local db_prefix=$(random_str 2)_
    #创建数据库配置文件
    wp config create --dbname=$db_name --dbuser=$db_user --dbpass=$db_pass --dbprefix=$db_prefix --allow-root --quiet
    #安装WordPress程序
    wp core install --url="http://$input_value" --title="My Blog" --admin_user=$wp_user --admin_password=$wp_pass --admin_email=$wp_mail --skip-email --allow-root
}
# 删除数据库所有表
function drop_db_tables {
    local db_name=$1
    #数据库是否存在
    if [ ! -n "$(is_db_exist $db_name)" ]; then
        echoCC "数据库不存在."
        return $?
    fi
    conn="mariadb -D$db_name -s -e"
    drop=$($conn "SELECT concat('DROP TABLE IF EXISTS ', table_name, ';') FROM information_schema.tables WHERE table_schema = '${db_name}'")
    $($conn "SET foreign_key_checks = 0; ${drop}")
}
# 查找域名
function query_domain {
    local domain=$1
    local domain_list=$(grep -o 'map.*' $cf_lsws | grep -oE "[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")
    for item in $domain_list; do
        if [ "$domain" = "$item" ]; then
            echo '域名已绑定到其它虚拟机.'
            break
        fi
    done
    echo ''
}
# 获取域名解析结果
function dns_query {
    local vhost=$1
    local local_ip=$(query_public_ip)
    if (ping -c 2 $vhost &>/dev/null); then
        local domain_ip=$(ping $vhost -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
        if [ "$local_ip" != "$domain_ip" ]; then
            echo $domain_ip
        fi
    else
        echo '0.0.0.0'
    fi
}

