#2.安装中文的字体
apt install fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei
apt install locales
dpkg-reconfigure locales
# 选中 zh_CN.UTF-8 UTF-8
# zh_CN.UTF-8作为默认 locale
echo "export LANG=zh_CN.UTF-8" >> ~/.bashrc
echo "export LANGUAGE=zh_CN:zh" >> ~/.bashrc
. ~/.bashrc