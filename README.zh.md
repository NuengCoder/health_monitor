
## Linux 系统健康监控平台 (System Health Monitor)


一个轻量级、自动化的 Bash 系统健康监控平台。该脚本直接从 Linux 内核的 `/proc` 虚拟文件系统中读取实时的 CPU、内存、磁盘和网络指标，将它们与可配置的阈值进行比较，并输出结构化的 CSV 和 JSON 数据。


### 🚀 核心特性
- **直读内核数据**：不依赖解析带有控制字符的 `top` 命令，而是直接读取 `/proc/stat`、`/proc/meminfo` 等文件，获取最纯净的原始数据。
- **两次采样差值算法**：通过间隔 1 秒的两次采样，精确计算 CPU 和网络在单位时间内的真实使用率。
- **阈值动态告警**：当资源占用超过设定的阈值时，自动将告警信息（含精确时间戳）写入 `logs/alert.log`。
- **标准数据报表**：将采集到的数据以 CSV 格式追加写入 `logs/metrics.csv`，方便导入 Excel 或接入可视化监控系统。
- **零外部依赖**：仅使用系统自带的 `awk`、`df`、`sleep` 等原生命令，无需安装任何第三方包。
- **代码规范**：完全通过 `shellcheck` 静态分析，0 警告。
### 📂 仓库结构

- `health_monitor.sh`: 主项目脚本（期中考核提交版本，基于 Linux）。
- `health_monitor_multi.sh`: 跨平台探索版脚本（支持 macOS 和 Termux）。
- `logs/`: 脚本运行后自动生成的日志目录。
- `README.md` / `README.zh.md`: 双语文档。

### 🛠️ 运行方式
 
chmod +x health_monitor.sh
./health_monitor.sh [-i interval] [-c cpu%] [-m mem%] [-d disk%] [-j]

### 参数说明：
- `-i <秒数>`：采样间隔时间，默认 5 秒。
- `-c <百分比>`：CPU 告警阈值，默认 80%。
- `-m <百分比>`：内存告警阈值，默认 80%。
- `-d <百分比>`：磁盘告警阈值，默认 90%。
- `-j`：每次循环时，在终端额外输出一条 JSON 格式的快照数据。

### 运行示例：
#### 以 3 秒为间隔运行，当 CPU 超过 50% 或内存超过 60% 时触发告警：
```bash
./health_monitor.sh -i 3 -c 50 -m 60
```
#### 📊 输出文件说明
- **`logs/metrics.csv`**：每个采样周期追加一行数据，包含时间戳及各项指标。
- **`logs/alert.log`**：仅在触发阈值时写入，记录具体是哪个指标超标，方便运维人员事后审计。

### 🌍 进阶探索：跨平台支持 (health_monitor_multi.sh)
#### 注意：此为探索性扩展，非期中考核的 Linux 核心提交版本。
#### 该脚本可通过 uname 和 TERMUX_VERSION 自动识别平台并切换采集逻辑：
- **Linux**: 使用 `/proc`。
- **macOS**: 使用 `top -l 1`、`vm_stat` 和 `netstat`。
- **Termux (Android)**: 因 Android 的 SELinux 限制，对受限指标会优雅降级并显示 `N/A`。

### 🧪 测试
  在终端运行 shellcheck health_monitor.sh 可验证代码质量。本项目已在 WSL 及原生 Ubuntu 环境下完成测试。