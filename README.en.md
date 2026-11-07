
##  Linux System Health Monitor


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
- `README.md` / `README.zh.md`: Documentation files.


### 🛠️ Usage

```bash
chmod +x health_monitor.sh
./health_monitor.sh [-i interval] [-c cpu%] [-m mem%] [-d disk%] [-j]
```

### Options:
- `-i <seconds>`: Sampling interval in seconds (default: 5).
- `-c <percent>`: CPU alert threshold (default: 80).
- `-m <percent>`: Memory alert threshold (default: 80).
- `-d <percent>`: Disk alert threshold (default: 90).
- `-j`: Additionally output a JSON snapshot to the console every cycle.

### Example:
#### Run the script with a 3-second interval, and alert if CPU > 50% or Memory > 60%:
```bash
./health_monitor.sh -i 3 -c 50 -m 60
```

### 📊 Output Files

- **`logs/metrics.csv`**: Appends a new row every cycle. Perfect for importing into Excel, Grafana, or Prometheus.
- **`logs/alert.log`**: Only written to when a threshold is breached, containing the exact timestamp and the offending metrics.


### 🌍 Advanced: Cross-Platform Support (health_monitor_multi.sh)

#### Note: This is an experimental extension not included in the primary Linux submission.
#### It detects the OS (Linux, Darwin/macOS, or Termux/Android) and switches its data collection methods:
- **Linux**: Uses `/proc`.
- **macOS**: Uses `top -l 1`, `vm_stat`, and `netstat`.
- **Termux**: Gracefully degrades, reporting `N/A` for restricted kernel metrics due to Android SELinux.

### 🧪 Testing
   Run `shellcheck health_monitor.sh` to verify code integrity. 
   The project was tested under WSL (Windows Subsystem for Linux) and standard Ubuntu environments.
