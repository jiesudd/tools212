#检查系统bug Intel 核心满载可能会出现内存泄漏，导致系统崩溃
dmesg -T | grep -i "sigterm\|sigkill\|segfault"

# 使用top看PID
top

# 查看特定的线程的调度的cpu核心
ps -o pid,psr,comm -p 63481

# 压力测试
# 同时测试CPU和缓存
stress-ng --cpu 1 --cache 1 --taskset 4 -t 100s


mpstat -P ALL 2