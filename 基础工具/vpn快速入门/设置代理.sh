# 下载clash 配置文件xxxxxxx去代理网站去看
 wget -O config.yaml "xxxxxxx"

# 临时设置代理 （clash 代理 ）
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

# 永久设置代理
echo "export http_proxy=http://127.0.0.1:7890" >> ~/.bashrc
echo "export https_proxy=http://127.0.0.1:7890" >> ~/.bashrc

# 查看代理
echo $http_proxy
echo $https_proxy