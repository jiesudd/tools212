docker run -d --name=wz_dev_300i \
  -p 19520:22 \
  -p 19521:8000 \
  -p 19522:8001 \
  --privileged \
  --shm-size 40g \
  --security-opt seccomp=unconfined \
  -v /data:/data \
  -v /usr/local/Ascend:/usr/local/Ascend:ro \
  -v /etc/ascend_install.info:/etc/ascend_install.info:ro \
  -v /sys/kernel/debug:/sys/kernel/debug:rw \
  --device=/dev/davinci0 \
  --device=/dev/davinci1 \
  --device=/dev/davinci2 \
  --device=/dev/davinci3 \
  --device=/dev/davinci_manager \
  --device=/dev/hisi_hdc \
  arm64v8/ubuntu:20.04 \
  tail -f /dev/null 

# apt update
# apt install net-tools -y
# apt install gdb -y
# git config --global credential.helper store
# git config --global user.name ycwb4884
# git config --global user.email ycwb4884@cloudwalk.com
# apt install openssh-server
# echo "/etc/init.d/ssh restart" >> ~/.bashrc
# source ~/.bashrc
# passwd


# vim /etc/ssh/sshd_config
# LogLevel DEBUG2
# PermitRootLogin yes
# PasswordAuthentication yes
# Subsystem sftp /usr/lib/openssh/sftp-server