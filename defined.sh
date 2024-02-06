# 以root身份运行
[ $(id -u) -gt 0 ] && echoCC "请以root身份运行." && exit 0
# OpenLiteSpeed 默认安装目录
run_path=$(pwd)
# OpenLiteSpeed 默认安装目录
ols_root=/usr/local/lsws
# 虚拟机保存目录
vhs_root=/www
# 网站权限用户
user=nobody
# 用户所属组
group=nogroup
# 站点文档目录
doc_folder=public_html
#数据库备份名称
db_back=db.sql
# 面板配置文件
cf_lsws=$ols_root/conf/httpd_config.conf
# 输入的值
input_value=''
# 定义系统版本
debian='9 10 11'
ubuntu='18.04 20.04'
# 获取系统名称
os_name=$(cat /etc/os-release | grep ^ID= | cut -d = -f 2)
if [ -z "$os_name" ]; then
    echoCC '不支持的系统类型'
    exit 0
fi
# 获取系统版本
if [ -v $os_name ]; then
    if [ "$os_name" = "debian" ]; then
        os_version=$(cat /etc/os-release | grep VERSION_CODENAME= | cut -d = -f 2)
    else
        os_version=$(cat /etc/os-release | grep ^UBUNTU_CODENAME= | cut -d = -f 2)
    fi
else
    echoCC '不支持的系统类型'
    exit 0
fi
# 切换目录
cd $run_path
