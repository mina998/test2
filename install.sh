# 下载文件基础URL
repo=https://raw.githubusercontent.com/mina998/lswp/new

install_path='/usr/local/bin'
vm2=$install_path/vm
httpd2=$install_path/httpd

cd $install_path
if [ ! -d httpd ]; then
    mkdir -p $httpd2
else
    echo '目录已存在.'
    exit 0
fi
if [ ! -d vm ]; then
    mkdir -p $vm2
else
    echo '目录已存在.'
    exit 0
fi

apt update -y 
apt install wget -y

echo -ne "\033[38;5;208m" 
echo "开始下载配置文件"
echo -ne "\033[0m"

wget -P httpd $repo/httpd/example.crt
wget -P httpd $repo/httpd/example.key
wget -P httpd $repo/httpd/firewall
wget -P httpd $repo/httpd/listener
wget -P httpd $repo/httpd/rc.local
wget -P httpd $repo/httpd/vhost

wget -P vm $repo/vm/context
wget -P vm $repo/vm/htaccess
wget -P vm $repo/vm/upload
wget -P vm $repo/vm/default
wget -P vm $repo/vm/vhconf.81
#下载自动备份脚本
wget -P vm $repo/github.sh && chmod +x $vm2/github.sh
wget -P vm $repo/local.sh && chmod +x $vm2/local.sh

wget $repo/lswp
chmod +x lswp

echo -ne "\033[38;5;208m"
echo "安装完成"
echo -ne "\033[38;5;45m"
echo 'lswp 为面板指令'
echo -ne "\033[0m"
