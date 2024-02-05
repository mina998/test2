# 以root身份运行
[ $(id -u) -gt 0 ] && echoCC "请以root身份运行." && exit 0
vhs_root=/home
run_path=$(pwd)
# OpenLiteSpeed 默认安装目录
ols_root=/usr/local/lsws
# 站点文档目录
doc_folder=public_html
#数据库备份名称
db_back=db.sql
# 面板配置文件
cf_lsws=$ols_root/conf/httpd_config.conf
# 输入的值
input_value=''
# 切换目录
cd $run_path
