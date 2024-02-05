# 备份站点
function backup2 {
    #切换工作目录
    cd $web_root/$doc_folder
    if [ -z "$input_value" ]; then
        echoCC "输入有误."
        return $?
    fi
    local db_name=$(name_from_str $input_value)
    if [ ! -n "$(is_db_exist $db_name)" ]; then
        echoCC "数据库不存在."
        return $?
    fi
    #导出MySQL数据库
    /usr/bin/mariadb-dump $db_name > $db_back
    #测数据库是否导出成功
    if [ ! -f $db_back ]; then
        echoCC '备份数据库失败'
        return $?
    fi
    #切换目录
    cd $web_root/backup
    #备份网站保存名称
    local web_save_name=$(date +%Y-%m-%d.%H%M%S).web.tar.gz
    #打包本地网站数据,这里用--exclude排除文件及无用的目录
    tar -C $web_root/$doc_folder -zcf $web_save_name ./
    #测数网站是否备份成功
    if [ ! -f $web_save_name ]; then
        echoCC '网站备份失败'
        return $?
    fi
    #删除
    rm $web_root/$doc_folder/$db_back
    echoSB "备份文件列表, 总容量: $(du -sh)"
    #查看备份
    ls -ghGA | awk 'BEGIN{OFS="\t"} NR > 1 {print $3, $7}'
    echoGC "备份完成."
}
# 恢复站点
function restore2 {
    #切换工作目录
    cd $web_root/backup
    if [ $(ls | wc -l) -eq 0 ]; then
        echoCC '没有备份文件'
        return $?
    fi
    #查看备份
    echo -e "${SB}文件总大小:$ED $(du -sh)"
    #查看备份 ls -lrthgG
    ls -ghGA | awk 'BEGIN{OFS="\t"} NR > 1 {print $3, $7}'
    #接收用户输入
    echo -ne "$BC请输入要还原的文件名: $ED"
    read -a site_backup_file
    #检查文件是否存在
    if [ -z $site_backup_file ] || [ ! -f $site_backup_file ]; then
        echoCC "$site_backup_file指定文件不存在"
        return $?
    fi
    #检测文件格式
    if [[ ! $site_backup_file =~ .*\.tar\.gz$ ]]; then
        echoCC "[$site_backup_file]非指定的压缩格式"
        return $?
    fi
    #判断临时目录
    if [ -d temp ] ; then
        rm -rf temp
    fi
    #创建临时目录
    mkdir temp
    #解压备份文件
    tar -zxf $site_backup_file -C ./temp
    #
    cd temp
    #判断数据库文件是否存在
    if [ ! -f $db_back ]; then
        echoCC '找不到SQL文件'
        return $?
    fi
    local db_name=$(name_from_str $input_value)
    local db_user=$db_name
    local ug_user=$db_name
    #删除数据库中的所有表
    drop_db_tables "$db_name"
    #导入备份数据
    mariadb "$db_name" < $db_back
    #删除SQL
    rm $db_back
    #替换数据库信息
    sed -i -r "s/DB_NAME',\s*'(.+)'/DB_NAME', '$db_name'/" wp-config.php
    sed -i -r "s/DB_USER',\s*'(.+)'/DB_USER', '$db_user'/" wp-config.php
    #定义WordPress配置文件位置
    local wp_config=$web_root/$doc_folder/wp-config.php
    if [ -f "$wp_config" ]; then
        #获取原数据库信息
        #local old_db_name=$(grep -oE "DB_NAME.*[\"\']" $wp_config | sed -r '{s/.*,\s*//}' | sed s/[\'\"]*//g)
        #local old_db_user=$(grep -oE "DB_USER.*[\"\']" $wp_config | sed -r '{s/.*,\s*//}' | sed s/[\'\"]*//g)
        local old_db_pass=$(grep -oE "DB_PASSWORD.*[\"\']" $wp_config | sed -r '{s/.*,\s*//}' | sed s/[\'\"]*//g)
        #local table_prefix=$(grep -o "\$table_prefix[^;]*" $wp_config |tr -d "'" |tr -d '"' |tr -d ' ' |awk -F= '{print $2}')
        sed -i -r "s/DB_PASSWORD',\s*'(.+)'/DB_PASSWORD', '$old_db_pass'/" wp-config.php
    fi
    #删除网站文件
    rm -rf $web_root/$doc_folder/{.[!.],}*
    #还原备份文件
    mv ./{.[!.],}* $web_root/$doc_folder/ > /dev/null 2>&1
    #删除临时目录
    cd .. && rm -rf temp
    #切换工作目录
    cd $web_root
    #修改所有者
    chown -R $ug_user:$group $doc_folder/
    #修改目录权限
    find $doc_folder/ -type d -exec chmod 750 {} \;
    #修改文件权限
    find $doc_folder/ -type f -exec chmod 640 {} \;
    #重载配置
    service lsws force-reload
    echoGC '操作完成.'
}
# 删除指定备份文件
function del_backup_file {
    cd $web_root/backup
    #获取文件数
    if [ $(ls | wc -l) -eq 0 ]; then
        echoCC "没有备份文件."
        return $?
    fi
    echo -e "${SB}文件总大小:$ED $(du -sh)"
    #查看备份 ls -lrthgG
    ls -ghGA | awk 'BEGIN{OFS="\t"} NR > 1 {print $3, $7}'
    #接收文件名
    echo -ne "$BC请输入要删除的完整文件名: $ED"; 
    read -a backup_file_name
    rm $backup_file_name
    echoGC "文件删除成功."
}
# 完全删除站点
function delete_site {
    echoCC "请把文件备份到本地,将删除站点[$input_value]全部资料"
    echo -ne "${BC}确认完全删除站点,输入大写Y: ${ED}"; read -a ny1
    echo -ne "${BC}确认完全删除站点,输入小写y: ${ED}"; read -a ny2
    if [ "$ny2" != "y" -o "$ny1" != "Y" ]; then
        echoCC "已退出删除操作."
        return $?
    fi
    #删除虚拟机配置
    sed -i "/virtual[hH]ost\s*$input_value\s*{/,/}/d" $cf_lsws
    #删除虚拟机端口
    sed -i -r "/map\s+$input_value/d" $cf_lsws
    #删除所有空行
    sed -i "/^$/d" $cf_lsws
    #删除站点配置文件目录
    rm -rf $ols_root/conf/vhosts/$input_value
    echoGC "站点配置文件删除完成."
    #删除虚拟主机空间目录
    rm -rf $web_root
    echoGC "站点所有文件删除完成."
    #定义数据库名
    local db_name=$(name_from_str $input_value)
    local ug_user=$db_name
    #删除用户和组 db_name 和 db_user 是同一个
    pkill -u $ug_user
    #删除用户
    if id $ug_user >/dev/null 2>&1; then
        userdel $ug_user
    fi
    #删除计划任务
    crontab -l | grep -v "$ols_root/backup/local.sh $input_value" | crontab -
    crontab -l | grep -v "$ols_root/backup/github.sh $input_value" | crontab -
    #删除用户组
    if getent group $ug_user >/dev/null; then
        groupdel $ug_user
    fi
    #删除数据库相关
    if [ -n $(is_db_exist "$db_name") ]; then
        #查询数据库相关用户
        local db_user=$(mariadb -Nse "select distinct user from mysql.db where db = '$db_name';")
        if [ -n "$db_user" ]; then
            mariadb -e "drop user '$db_user'@'localhost';"
        fi
        #删除数据库
        mariadb -e "drop database $db_name;"
        echoGC "网站数据库已删除完成."
    else
        echoYC "[$db_name]数据库删除失败:不存在"
    fi
    menu && return $?
}
# 添加域名
function domain_add {
    if [ -z "$input_value" ]; then
        echoRC '接收主机名失败.'
        return $?
    fi
    #获取虚拟机绑定域名列表
    local domain_list=$(grep map.*$input_value $cf_lsws | awk 'NR==1 {print}' | sed "{s/map\s*$input_value//;s/^[[:space:]]*//}")
    echo -ne "${SB}已绑定域名列表: ${ED}"
    echoYC "$domain_list"
    #原变量
    local old_input_value=$input_value
    #接收域名 原变量被修改
    verify_domain
    #查找是否绑定
    local temp=$(echo $domain_list | sed 's/,/ /g')
    for item in $temp; do
        if [ "$item" = "$input_value" ]; then
            echoCC "已绑定: $input_value"
            input_value=$old_input_value
            return $?
        fi
    done
    #域名是否绑定到其他站点
    local is_domain=$(query_domain "$input_value")
    if [ -n "$is_domain" ]; then
        echoCC "$is_domain"
        input_value=$old_input_value
        return $?
    fi
    #修改OpenLiteSpeed 配置文件
    sed -i "s/map\(.*\)$old_input_value.*/map\1 $domain_list, $input_value/" $cf_lsws
    #重新获取列表 
    domain_list=$(grep map.*$old_input_value $cf_lsws | awk 'NR==1 {print}' | sed "{s/map\s*$old_input_value//;s/^[[:space:]]*//}")
    echoCC "绑定成功: $domain_list"
    #重置变量
    input_value=$old_input_value
    #重新加载配置
    service lsws force-reload
}
# 安装证书
function cert_ssl_install {
    if [ -z "$input_value" ]; then
        echoRC '接收主机名失败.'
        return $?
    fi
    #证书保存路径
    local cert_path=$web_root/cert
    if [ ! -d $cert_path ]; then
        mkdir -p $cert_path
    fi 
    #下载安装证书签发程序
    if [ ! -f "/root/.acme.sh/acme.sh" ] ; then 
        curl https://get.acme.sh | sh -s email=admin@$input_value
        #重新设置CA账户
        /root/.acme.sh/acme.sh --register-account -m admin@$input_value >/dev/null 2>&1
        #更改证书签发机构
        /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt >/dev/null 2>&1
    fi
    #获取绑定域名列表
    local vm_bind_domains=$(grep map.*$input_value $cf_lsws | awk 'NR==1 {print}' | sed "{s/map\s*$input_value//;s/^[[:space:]]*//}" | sed 's/,//g')
    echoCC "将为以下域名申请SSL证书:"
    echoSB "$vm_bind_domains"
    #解析成功列表
    local dns_domain_list=()
    #判断是否解析
    for item in $vm_bind_domains; do
        local dns_ip=$(dns_query "$item")
        if [ -n "$dns_ip" ]; then
             echoRR "[$item -> $dns_ip]:解析失败,该域名无法申请证书."
        else
            dns_domain_list[${#dns_domain_list[*]}]=$item
        fi
    done
    #判断是否有域名解析成功
    if [ ${#dns_domain_list[*]} -eq 0 ]; then
        echoCC '没有域名解析成功.'
        return $?
    fi
    #组装参数
    local domain_list="-d $(echo ${dns_domain_list[@]} | sed 's/ / -d /g')"
    #开使申请证书
    /root/.acme.sh/acme.sh --issue $domain_list --webroot $web_root/$doc_folder
    #copy/安装 证书
    /root/.acme.sh/acme.sh --install-cert $domain_list --cert-file $cert_path/cert.pem --key-file $cert_path/ssl.key --fullchain-file $cert_path/ssl.crt --reloadcmd "service lsws force-reload"
    echo -e "${GC}证书文件:${ED} ${SB}$cert_path/cert.pem ${ED}"
    echo -e "${GC}私钥文件:${ED} ${SB}$cert_path/ssl.key ${ED}"
    echo -e "${GC}证书全链:${ED} ${SB}$cert_path/ssl.crt ${ED}"
}
# 定时备份GITHUB
function scheduled_tasks_backup_to_github {
    # 备份间隔天数
    local day=2
    # 获取github token
    local github=/root/.lsws/github
    if [ -f $github ]; then
        local username=$(awk -F@ '{print $1}' $github)
        local token=$(awk -F@ '{print $2}' $github)
    else
        echoRC "GITHUB账号未添加."
        return $?
    fi
    # 定义变量
    local temp_str="$ols_root/backup/github.sh $1"
    crontab -l | grep "$temp_str" > /dev/null
    if [ $? -eq 0 ]; then
        echo -ne "${LG}"
        crontab -l | grep "$temp_str"
        echo -ne "${ED}"
    else
        echoCC "未开启"
    fi
    local m=$(random_number 60)
    local h=$(random_number 12)
    echo -ne "$BC站点自动备份GITHUB[回车退出](y/n):$ED "
    read -a site_backup_auto_git_on
    # 如果没有输入就退出
    if [ -z "$site_backup_auto_git_on" ]; then
        echoGC "输入为空. 退出编辑任务模式"
        return $?
    fi
    if [ "$site_backup_auto_git_on" = "y" ]; then
        echo -ne "$BC请输入GITHUB仓库名:$ED "
        read -a repo_name
        if [ -z "$repo_name" ]; then 
            echoCC "输入为空. 退出编辑任务模式"
            return $?
        fi
        # 删除指定任务并导出(不导出不行呀,没找出其他方法)
        crontab -l | grep -v "$temp_str" > .crontab
        echo "$m $h */$day * * $temp_str $repo_name" >> .crontab
        # 添加新的任务
        crontab .crontab
        rm .crontab
        echoGC "$m $h */$day * * $temp_str $repo_name"
    else
        crontab -l | grep -v "$temp_str" | crontab -
        echoGC "自动备份已关闭"
    fi
}
# 获取0-max之前的随机数
function random_number {
    local max_number=$1
    local random=$((RANDOM % $1))
    echo $random
}
# 定时备份LOCAL
function scheduled_tasks_backup_to_local {
    # 备份间隔天数
    local day=4
    local temp_str="$ols_root/backup/local.sh $1"
    crontab -l | grep "$temp_str" > /dev/null
    if [ $? -eq 0 ]; then
        echo -ne "${LG}"
        crontab -l | grep "$temp_str"
        echo -ne "${ED}"
        echoGC "只保留最近30次备份数据"
    else
        echoCC "未开启"
    fi
    local m=$(random_number 60)
    local h=$(random_number 12)
    echo -ne "$BC站点自动备份(y/n):$ED "
    read -a site_backup_auto_on
    # 如果没有输入就退出
    if [ -z "$site_backup_auto_on" ]; then
        echoGC "已退出编辑任务模式"
        return $?
    fi
    if [ "$site_backup_auto_on" = "y" ]; then
        # 删除指定任务并导出(不导出不行呀,没找出其他方法)
        crontab -l | grep -v "$temp_str" > .crontab
        echo "$m $h */$day * * $temp_str" >> .crontab
        crontab .crontab
        rm .crontab
        echoLG "$m $h */$day * * $temp_str"
        echoGC "只保留最近30次备份数据"
    else
        crontab -l | grep -v "$temp_str" | crontab -
        echoGC "自动备份关闭"
    fi
}
