#!/bin/bash
github=/root/.lsws/github
# 未传变量不执行
if [ -z "$1" ] || [ -z "$2" ]; then
    exit 1
fi
# 站点参数域名 *
site=$1
# GITHUB仓库名 *
repo=$2
# 远程分支
branch=main
# GITHUB用户名 *
user=$(awk -F@ '{print $1}' $github)
# GITHUB TOKEN *
token=$(awk -F@ '{print $2}' $github)
# 生成数据库名
db_name=$(echo "$site" | sed 's/\./_/g' | sed 's/-/_/g')
# 数据库SQL文件名
db_back=db.sql
# 日志文件
log_file=$web_root/github/error.log
# 创建工作路径
work_path="/www/${site}/github"
[ ! -d $work_path  ] && mkdir -p $work_path
# 获取当前时间
function data2 {
    echo $(date +'%Y-%m-%d %H:%M:%S')
}
# 站点文档目录
doc_root="/www/${site}/public_html"
if [ ! -d $doc_root ]; then
    echo "[$(data2)]($site): 站点不存在" >> $log_file
    exit 0
fi
# 生成私密仓库可访问地址
repo_address="https://${user}:${token}@github.com/${user}/${repo}.git"
# 检测git是否安装
if [ ! -e /usr/bin/git ]; then
    apt install git -y
fi
# 检测zip是否安装
if [ ! -x /usr/bin/7z ]; then
    apt install p7zip-full -y
fi
# 配置git用户
git config --global user.email "$user@qq.com"
git config --global user.name "$user"
# 删除临时仓库
rm -rf $work_path/temp
# 切换路径
cd $work_path
# 克隆仓库
git clone -b $branch --single-branch $repo_address temp
# 克隆失败
if [ ! -d "${work_path}/temp" ]; then
    echo "[$(data2)]($site): 克隆仓库失败" >> $log_file
    exit 0
fi
# 切换工作路径
cd temp
# 设置为安全路径
git config --global --add safe.directory ./
# 定义版本
tag="v.$(date +'%Y.%m%d.%H%M%S')"
# 数据库存在就导出
if [ -n $(mariadb -Nse "show DATABASES like '$db_name'") ]; then
    /usr/bin/mariadb-dump $db_name > $doc_root/$db_back
fi
# 分卷打包压缩
echo "$tag" > $doc_root/release.version
# zip -9qs 45m -r web.zip $web_doc_root
7z a web.7z $doc_root -v46m #-bd
# 打包完后清理
rm -f $doc_root/$db_back
rm -f $doc_root/release.version
# 写入站点名称
echo $site > site
# 开始上传
ls -al
git add -A
git commit -am "update $site"
git tag -a $tag -m "$site $tag"
git push origin $tag
# 删除所有文件
rm -rf $work_path/temp
