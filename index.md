# SysInfo | 系統資訊與硬體檢測腳本

SysInfo 是免費的單一 Bash 腳本，支援 Linux 與 macOS。它會顯示系統與硬體資訊、查詢 CPU、GPU、主機板與 BIOS 型號，並執行 CPU 與磁碟基準測試。在 Linux 上也提供 VPS 超售跡象的輔助檢測；檢測結果受虛擬化環境及權限影響，不能單憑一次輸出判定超售。

## 執行方式

先[閱讀原始碼](https://github.com/Neverwin1337/sysinfo/blob/main/index.html)，再視需要執行：

```bash
curl -fsSL https://sys.nev3rw1n.com/ | bash
```

若要先下載檢查：

```bash
curl -fsSL https://sys.nev3rw1n.com/ -o sysinfo.sh
bash sysinfo.sh
```

根路徑會依 User-Agent 回傳不同內容：一般瀏覽器看到介紹頁，curl/wget 取得腳本。本頁是供閱讀與檢索的 Markdown 摘要，不是可執行腳本。

## 提供的資訊

- 系統：作業系統、核心、架構、負載與虛擬化環境。
- 硬體：CPU 型號與核心、記憶體、磁碟、GPU、主機板及 BIOS；部分 Linux 資訊需 root 或 dmidecode。
- Linux VPS：CPU 快取、steal time、記憶體與 vCPU 超售跡象。
- 基準測試：CPU 使用 sysbench 或 openssl；磁碟測試可能產生大量 I/O，執行前請評估主機負載。

## 更多資訊

- [詳細功能、限制及需求](./README.md)
- [原始碼與維護者 Neverwin1337](https://github.com/Neverwin1337/sysinfo)
- [終端輸出截圖](./screenshot.png)
- [機器可讀摘要](./ai/summary.json)
- [LLM 入口](./llms.txt)

SysInfo 以 MIT License 發布。
