<p align="center">
  <b>English</b> | <a href="#中文">中文</a>
</p>


## Linux System Health Monitor
A robust, lightweight, and automated system health monitoring platform written in Bash. It samples real-time CPU, Memory, Disk, and Network metrics directly from the Linux kernel's `/proc` filesystem, evaluates them against configurable thresholds, and outputs data in easily parsable CSV and JSON formats.


### 🚀 Features

- **Direct Kernel Reading**: Bypasses parsing issues of `top` by reading directly from `/proc/stat`, `/proc/meminfo`, and `/proc/net/dev`.
- **Dual-Sampling Logic**: Accurately calculates CPU and Network usage by taking two samples 1 second apart to compute the exact delta.
- **Threshold Alerts**: Automatically logs warnings to `logs/alert.log` if metrics exceed configurable limits.
- **Machine-Readable Output**: Appends clean metrics to `logs/metrics.csv` for historical tracking and analysis.
- **Zero Dependencies**: Relies only on standard POSIX tools (`awk`, `df`, `sleep`, `date`), requiring no external packages.
- **Fully ShellChecked**: Code passes `shellcheck` with 0 warnings.


### 📂 Repository Structure

- `health_monitor.sh`: The primary Linux-based script (Midterm Project submission).
- `health_monitor_multi.sh`: An advanced, cross-platform experimental version supporting macOS and Termux (Android).
- `logs/`: Automatically generated directory containing `metrics.csv` and `alert.log`.
- `README.md`: Bilingual documentation with language switcher.
- `NTCRANFILE.yaml`: Task runner configuration for quick testing.


### 🛠️ Usage
```bash
chmod +x health_monitor.sh
./health_monitor.sh [-i interval] [-c cpu%] [-m mem%] [-d disk%] [-j]
```
// Options:
- `-i <seconds>`: Sampling interval in seconds (default: 5).
- `-c <percent>`: CPU alert threshold (default: 80).
- `-m <percent>`: Memory alert threshold (default: 80).
- `-d <percent>`: Disk alert threshold (default: 90).
- `-j`: Additionally output a JSON snapshot to the console every cycle.


### 📊 Output Files

- **`logs/metrics.csv`**: Appends a new row every cycle. Perfect for importing into Excel, Grafana, or Prometheus.
- **`logs/alert.log`**: Only written to when a threshold is breached, containing the exact timestamp and the offending metrics.

### 🧪 Testing

#### Run `ran checks` (NTC task runner) or `shellcheck health_monitor.sh` to verify code integrity.

---

<br>
<hr>
<br>

<p align="center">
  <a href="#">English</a> | <b>中文</b>
</p>

<a id="中文"></a>

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
- `README.md`: 支持中英文切换的双语文档。
- `NTCRANFILE.yaml`: 用于快速测试的 NTC 任务运行器配置。


### 🛠️ 运行方式
```bash
chmod +x health_monitor.sh
./health_monitor.sh [-i interval] [-c cpu%] [-m mem%] [-d disk%] [-j]
```
// 参数说明：
- `-i <秒数>`：采样间隔时间，默认 5 秒。
- `-c <百分比>`：CPU 告警阈值，默认 80%。
- `-m <百分比>`：内存告警阈值，默认 80%。
- `-d <百分比>`：磁盘告警阈值，默认 90%。
- `-j`：每次循环时，在终端额外输出一条 JSON 格式的快照数据。


### 📊 输出文件说明

- **`logs/metrics.csv`**：每个采样周期追加一行数据，包含时间戳及各项指标。
- **`logs/alert.log`**：仅在触发阈值时写入，记录具体是哪个指标超标，方便运维人员事后审计。


### 🧪 测试

#### 在终端运行 `ran checks`（NTC 任务运行器）或 `shellcheck health_monitor.sh` 可验证代码质量。
