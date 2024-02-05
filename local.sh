#!/bin/bash
if [ -z "$1" ]; then
    echo "站点参数未指定"
    exit 1
fi
site=$1
web_root=/www/$site
doc_folder=public_html
db_back=db.sql
# 生成数据库名
function name_from_str {
    echo "$site" | sed 's/\./_/g' | sed 's/-/_/g'
}
# 切换工作目录
cd $web_root/$doc_folder
db_name=$(name_from_str $site)
function is_db_exist {
    echo $(mariadb -Nse "show DATABASES like '$db_name'")
}
if [ -n "$(is_db_exist $db_name)" ]; then
    #导出MySQL数据库
    /usr/bin/mariadb-dump $db_name > $db_back
fi
# 切换目录
cd $web_root/backup || exit 
# 备份文件列表
backup_files=($(ls -tr *.task.web.tar.gz 2>/dev/null))
# 设置要保留的备份文件数量
keep_count=29
# 计算要删除的备份文件数量
delete_count=$(( ${#backup_files[@]} - $keep_count ))
# 删除多余的备份文件
if [ $delete_count -gt 0 ]; then
    # 删除多余的备份文件
    for ((i = 0; i < $delete_count; i++)); do
        rm "${backup_files[$i]}"
    done
fi
# 备份网站保存名称
web_save_name=$(date +%Y-%m-%d.%H%M%S).task.web.tar.gz
# 打包本地网站数据,这里用--exclude排除文件及无用的目录
tar -C $web_root/$doc_folder -zcf $web_save_name ./
# 删除
rm $web_root/$doc_folder/$db_back
