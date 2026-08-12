#!/bin/bash
# bench.sh - Enhanced system info collector & benchmark
# Usage: bash bench.sh

export LC_ALL=C

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
MAGENTA=$'\033[0;35m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

SEC_COLORS=($CYAN $MAGENTA $YELLOW $BLUE)
SEC_IDX=0
LBL_COLOR=$CYAN

section() {
  LBL_COLOR=${SEC_COLORS[$SEC_IDX]}
  SEC_IDX=$(( (SEC_IDX + 1) % ${#SEC_COLORS[@]} ))
  echo
  echo -e "${BOLD}${LBL_COLOR}========== $1 ==========${NC}"
}
sub()     { echo -e "  ${BOLD}${LBL_COLOR}$1${NC}"; }
kv() {
  local label="$1" val="$2" pad w
  pad=$(printf '%s' "$label" | awk '{n=length($0); na=$0; gsub(/[ -~]/,"",na); a=n-length(na); print a + int(length(na)*2/3)}')
  w=$(( 34 - pad )); [ "$w" -lt 1 ] && w=1
  printf "  ${BOLD}${LBL_COLOR}%s${NC}%*s : ${GREEN}%s${NC}\n" "$label" "$w" "" "$val"
}
ok()      { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
bad()     { echo -e "${RED}[FAIL]${NC} $1"; }
info()    { echo -e "  ${DIM}$1${NC}"; }

pad_label() {
  local s="$1" pad w
  pad=$(printf '%s' "$s" | awk '{n=length($0); na=$0; gsub(/[ -~]/,"",na); a=n-length(na); print a + int(length(na)*2/3)}')
  w=$(( 34 - pad )); [ "$w" -lt 1 ] && w=1
  printf "%s%*s" "$s" "$w" ""
}

has() { command -v "$1" >/dev/null 2>&1; }

PLATFORM=$(uname -s)

detect_virt() {
  if [ "$PLATFORM" != "Linux" ]; then echo "N/A"; return; fi
  if [ -f /proc/1/environ ] && grep -qi 'container=' /proc/1/environ 2>/dev/null; then
    echo "Container"
  elif has systemd-detect-virt; then
    local v; v=$(systemd-detect-virt 2>/dev/null)
    [ -n "$v" ] && echo "$v" || echo "Physical"
  elif grep -qi 'hypervisor' /proc/cpuinfo 2>/dev/null; then
    echo "KVM (likely)"
  elif [ -f /proc/user_beancounters ]; then
    echo "OpenVZ"
  else
    echo "Physical/Unknown"
  fi
}

# ===================== System =====================
section "系統資訊 / System"
kv "主機名 / Hostname" "$(hostname 2>/dev/null)"

if [ "$PLATFORM" = "Linux" ]; then
  OS_NAME=$(awk -F= '/^PRETTY_NAME=/{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null)
  [ -z "$OS_NAME" ] && OS_NAME=$(cat /etc/redhat-release 2>/dev/null)
  kv "作業系統 / OS" "$OS_NAME"
  kv "核心版本 / Kernel" "$(uname -r)"
  kv "架構 / Arch" "$(uname -m)"
  kv "運行時間 / Uptime" "$(uptime -p 2>/dev/null | sed 's/up //')"
  kv "平均負載 / Load" "$(uptime 2>/dev/null | awk -F'load average:' '{print $2}')"
  kv "虛擬化 / Virtualization" "$(detect_virt)"
else
  kv "作業系統 / OS" "$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
  kv "核心版本 / Kernel" "$(uname -r)"
  kv "架構 / Arch" "$(uname -m)"
  kv "運行時間 / Uptime" "$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
  kv "平均負載 / Load" "$(uptime | awk -F'load averages:' '{print $2}')"
  kv "虛擬化 / Virtualization" "N/A"
fi

# ===================== CPU =====================
section "CPU 資訊 / CPU"
if [ "$PLATFORM" = "Linux" ]; then
  CPU_MODEL=$(awk -F: '/model name/{gsub(/^ +/,"",$2); print $2; exit}' /proc/cpuinfo)
  CPU_MODEL=${CPU_MODEL:-"$(lscpu 2>/dev/null | awk -F: '/Model name/{gsub(/^ +/,"",$2); print $2; exit}')"}
  kv "型號 / Model" "$CPU_MODEL"

  SOCKETS=$(lscpu 2>/dev/null | awk -F: '/^Socket\(s\)/{gsub(/ /,"",$2); print $2; exit}')
  CORES_PER_SOCKET=$(lscpu 2>/dev/null | awk -F: '/Core\(s\) per socket/{gsub(/ /,"",$2); print $2; exit}')
  THREADS_PER_CORE=$(lscpu 2>/dev/null | awk -F: '/Thread\(s\) per core/{gsub(/ /,"",$2); print $2; exit}')
  TOTAL_CORES=$(lscpu 2>/dev/null | awk -F: '/^CPU\(s\)/{gsub(/ /,"",$2); print $2; exit}')
  LOGICAL_CORES=$(nproc 2>/dev/null || grep -c processor /proc/cpuinfo)

  if [ -n "$TOTAL_CORES" ]; then kv "vCPU 數 / CPU(s)" "$TOTAL_CORES"; fi
  if [ -n "$SOCKETS" ] && [ -n "$CORES_PER_SOCKET" ]; then
    kv "物理核心 / Physical Cores" "$(( SOCKETS * CORES_PER_SOCKET ))"
  fi
  kv "邏輯核心 / Logical Cores" "$LOGICAL_CORES"
  if [ -n "$THREADS_PER_CORE" ]; then kv "每核執行緒 / Threads per core" "$THREADS_PER_CORE"; fi

  CACHE=$(awk -F: '/cache size/{gsub(/^ +/,"",$2); print $2; exit}' /proc/cpuinfo)
  [ -n "$CACHE" ] && kv "快取 L3/核 / Cache (L3/core)" "$CACHE"
  L1=$(lscpu 2>/dev/null | awk -F: '/^L1d cache/{gsub(/^ +/,"",$2); print $2; exit}')
  L2=$(lscpu 2>/dev/null | awk -F: '/^L2 cache/{gsub(/^ +/,"",$2); print $2; exit}')
  L3=$(lscpu 2>/dev/null | awk -F: '/^L3 cache/{gsub(/^ +/,"",$2); print $2; exit}')
  [ -n "$L1" ] && kv "L1d 快取 / L1d Cache" "$L1"
  [ -n "$L2" ] && kv "L2 快取 / L2 Cache" "$L2"
  [ -n "$L3" ] && kv "L3 快取 / L3 Cache" "$L3"

  CUR_MHZ=$(awk -F: '/cpu MHz/{gsub(/^ +/,"",$2); print $2; exit}' /proc/cpuinfo)
  [ -n "$CUR_MHZ" ] && kv "目前頻率 / Current MHz" "$CUR_MHZ"

  FLAGS=$(awk -F: '/^flags/{$1=""; print; exit}' /proc/cpuinfo)
  FLAG_COUNT=$(echo "$FLAGS" | wc -w)
  kv "指令集數 / Flags Count" "$FLAG_COUNT"
  kv "關鍵指令集 / Key Flags" "$(echo "$FLAGS" | grep -oE '\b(avx2|avx512[a-z]*|aes|vmx|svm|hypervisor)\b' | tr '\n' ' ')"
else
  kv "型號 / Model" "$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
  kv "物理核心 / Physical Cores" "$(sysctl -n hw.physicalcpu 2>/dev/null)"
  kv "邏輯核心 / Logical Cores" "$(sysctl -n hw.ncpu 2>/dev/null)"
  CPUFREQ=$(sysctl -n hw.cpufrequency 2>/dev/null)
  [ -n "$CPUFREQ" ] && kv "頻率 / Frequency (Hz)" "$CPUFREQ"
  kv "快取 L1d/L1i/L2/L3 / Cache" "$(sysctl -n hw.l1dcachesize 2>/dev/null)/$(sysctl -n hw.l1icachesize 2>/dev/null)/$(sysctl -n hw.l2cachesize 2>/dev/null)/$(sysctl -n hw.l3cachesize 2>/dev/null)"
fi

# ===================== Memory =====================
section "記憶體資訊 / Memory"
TOTAL_RAM=0
if [ "$PLATFORM" = "Linux" ]; then
  TOTAL_RAM=$(free -m 2>/dev/null | awk '/Mem:/{print $2}')
  USED_RAM=$(free -m 2>/dev/null | awk '/Mem:/{print $3}')
  FREE_RAM=$(free -m 2>/dev/null | awk '/Mem:/{print $4}')
  AVAIL_RAM=$(free -m 2>/dev/null | awk '/Mem:/{print $7}')
  SWAP_TOTAL=$(free -m 2>/dev/null | awk '/Swap:/{print $2}')
  SWAP_USED=$(free -m 2>/dev/null | awk '/Swap:/{print $3}')
  kv "記憶體總量 / Total RAM" "${TOTAL_RAM} MB"
  kv "已用/可用 / Used / Free" "${USED_RAM} / ${FREE_RAM} MB"
  [ -n "$AVAIL_RAM" ] && kv "可用 / Available" "${AVAIL_RAM} MB"
  kv "交換空間 / Swap" "${SWAP_TOTAL} MB (used ${SWAP_USED})"
else
  TOTAL_RAM=$(( $(sysctl -n hw.memsize 2>/dev/null) / 1024 / 1024 ))
  kv "記憶體總量 / Total RAM" "${TOTAL_RAM} MB"
  if has vm_stat; then
    kv "已用/可用 / Used / Free" "$(vm_stat | awk -v t="$TOTAL_RAM" '
      /page size of/{ps=$8}
      /Pages free/{f=$3}
      /Pages inactive/{i=$3}
      /Pages speculative/{s=$3}
      END{gsub(/\./,"",f); gsub(/\./,"",i); gsub(/\./,"",s);
          free=int((f+i+s)*ps/1024/1024); used=t-free;
          printf "%d / %d MB", used, free}')"
  fi
fi

# ===================== Memory Modules =====================
section "記憶體條 / RAM Modules"
DMIDECODE=""
if [ "$PLATFORM" = "Linux" ]; then
  if has dmidecode; then
    DMIDECODE=$(dmidecode -t memory 2>/dev/null)
    if [ -z "$DMIDECODE" ] && [ "$(id -u)" != "0" ] && has sudo; then
      DMIDECODE=$(sudo -n dmidecode -t memory 2>/dev/null)
    fi
  fi
  if [ -n "$DMIDECODE" ]; then
    echo "$DMIDECODE" | awk '
      function pad(s,  n, na, a, w) {
        n=length(s); na=s; gsub(/[ -~]/,"",na); a=n-length(na)
        w=34-(a+int(length(na)*2/3)); if(w<1) w=1
        return sprintf("%s%*s", s, w, "")
      }
      /Handle .* DMI type 17/ { blk=1; size=""; spd=""; typ=""; man=""; pn=""; loc=""; next }
      /^$/ { flush(); blk=0; next }
      blk && /^\tSize:/ {
        if ($2 ~ /^[0-9]+/) size=$2" "$3
        else size=""
        next
      }
      blk && /^\tSpeed:/    { spd=$2" "$3; next }
      blk && /^\tType:/     { typ=$2; next }
      blk && /^\tManufacturer:/ { man=substr($0, index($0,$2)); next }
      blk && /^\tPart Number:/  { pn=$0; sub(/^.*Part Number:[ \t]*/,"",pn); next }
      blk && /^\tLocator:/  { loc=substr($0, index($0,$2)); next }
      END { flush() }
      function flush(){ if(blk && size!="") printf "  \033[1;33m%s\033[0m : \033[0;32m%s %s %s (%s %s)\033[0m\n", pad(loc), size, typ, spd, man, pn }
    '
    STICK_COUNT=$(echo "$DMIDECODE" | grep -c '^\tSize: [0-9]')
    TOTAL_GB=$(echo "$DMIDECODE" | awk '/^\tSize:/{if($2!="No"){gsub(/[^0-9]/,"",$2); t+=$2}} END{print t+0}')
    kv "已安裝 / Installed" "${STICK_COUNT} 條, 共 ${TOTAL_GB} GB"
  else
    if [ "$(id -u)" = "0" ]; then
      info "未檢測到 dmidecode 或無法讀取記憶體條資訊 (某些虛擬化環境會隱藏)。"
    else
      info "需要 root 權限才能讀取記憶體條資訊。可嘗試: sudo bash bench.sh"
    fi
  fi
else
  if has system_profiler; then
    system_profiler SPMemoryDataType 2>/dev/null | awk '
      function pad(s,  n, na, a, w) {
        n=length(s); na=s; gsub(/[ -~]/,"",na); a=n-length(na)
        w=34-(a+int(length(na)*2/3)); if(w<1) w=1
        return sprintf("%s%*s", s, w, "")
      }
      /^[[:space:]]*(BANK|DIMM)/ { loc=$0; sub(/^ +/,"",loc); gsub(/:/,"",loc); got=1; next }
      got && /Size:/  { size=substr($0,index($0,$2)) }
      got && /Type:/  { typ=substr($0,index($0,$2)) }
      got && /Speed:/ { spd=substr($0,index($0,$2)) }
      got && /Manufacturer:/ { man=substr($0,index($0,$2)) }
      got && /Status:/ {
        printf "  \033[1;33m%s\033[0m : \033[0;32m%s %s %s (%s)\033[0m\n", pad(loc), size, typ, spd, man
        n++; loc=""; size=""; typ=""; spd=""; man=""; got=0
      }
      /Memory:[ \t]+[0-9]/ { agg=$0; sub(/^[ \t]*Memory:[ \t]*/,"",agg) }
      !got && /Type:/  { at=substr($0,index($0,$2)) }
      !got && /Manufacturer:/ { am=substr($0,index($0,$2)) }
      END {
        if (n==0 && agg!="") {
          line=agg" "at
          if (am!="") line=line" ("am")"
          printf "  \033[1;33m%s\033[0m : \033[0;32m%s\033[0m\n", pad("記憶體 / Memory"), line
        }
      }
    '
  fi
fi

# ===================== Disk =====================
section "磁碟資訊 / Disk"
if [ "$PLATFORM" = "Linux" ]; then
  df -h / 2>/dev/null | awk '
    function pad(s,  n, na, a, w) {
      n=length(s); na=s; gsub(/[ -~]/,"",na); a=n-length(na)
      w=34-(a+int(length(na)*2/3)); if(w<1) w=1
      return sprintf("%s%*s", s, w, "")
    }
    NR==1{printf "  \033[1;33m%s\033[0m : \033[0;32m%s\033[0m\n", pad("分割區 / Partition"), $0}
    NR==2{printf "  \033[1;33m%s\033[0m : \033[0;32m%s\033[0m\n", pad("(根目錄 / root)"), $0}
  '
  if has lsblk; then
    sub "磁碟列表 / Block Devices:"
    lsblk -d -o NAME,SIZE,MODEL,ROTA 2>/dev/null | head -n 8 | sed "s/^/    ${GREEN}/; s/$/${NC}/"
    ROTA=$(lsblk -d -o ROTA -n 2>/dev/null | head -n1)
    MODEL=$(lsblk -d -o MODEL -n 2>/dev/null | head -n1)
    case "$ROTA" in
      0) kv "磁碟類型 / Disk Type" "SSD / NVMe" ;;
      1) kv "磁碟類型 / Disk Type" "HDD (機械盤)" ;;
    esac
    [ -n "$MODEL" ] && kv "磁碟型號 / Disk Model" "$MODEL"
  fi
else
  df -h / 2>/dev/null | awk '
    function pad(s,  n, na, a, w) {
      n=length(s); na=s; gsub(/[ -~]/,"",na); a=n-length(na)
      w=34-(a+int(length(na)*2/3)); if(w<1) w=1
      return sprintf("%s%*s", s, w, "")
    }
    NR==1{printf "  \033[1;33m%s\033[0m : \033[0;32m%s\033[0m\n", pad("分割區 / Partition"), $0}
    NR==2{printf "  \033[1;33m%s\033[0m : \033[0;32m%s\033[0m\n", pad("(根目錄 / root)"), $0}
  '
  if has diskutil; then
    kv "磁碟類型 / Disk Type" "$(diskutil info / 2>/dev/null | awk -F: '/Protocol/{gsub(/^ +/,"",$2); print $2}')"
    kv "磁碟名稱 / Media Name" "$(diskutil info / 2>/dev/null | awk -F: '/Media Name/{gsub(/^ +/,"",$2); print $2}')"
    kv "SSD? / Solid State" "$(diskutil info / 2>/dev/null | awk -F: '/Solid State/{gsub(/^ +/,"",$2); print $2}')"
  fi
fi

# ===================== Hardware Devices =====================
section "硬體設備 / Hardware Devices"
if [ "$PLATFORM" = "Linux" ]; then
  sub "網路介面 / Network Interfaces:"
  FOUND=0
  for iface in /sys/class/net/*; do
    [ -e "$iface" ] || continue
    FOUND=1
    name=$(basename "$iface")
    mac=$(cat "$iface/address" 2>/dev/null)
    ip=$(ip -4 -o addr show "$name" 2>/dev/null | awk '{print $4}' | head -n1 | cut -d/ -f1)
    state=$(cat "$iface/operstate" 2>/dev/null)
    stcolor=$GREEN; [ "$state" = "down" ] && stcolor=$RED
    np=$(pad_label "$name")
    printf "  ${BOLD}${LBL_COLOR}%s${NC} : IP=${CYAN}%-16s${NC} MAC=${YELLOW}%s${NC}" \
      "$np" "${ip:-none}" "$mac"
    [ -n "$state" ] && printf "  ${stcolor}($state)${NC}"
    echo
  done
  [ "$FOUND" = "0" ] && info "無法讀取網路介面"
  echo
  if has lspci; then
    sub "顯示卡 / GPU:"
    GPU=$(lspci 2>/dev/null | grep -iE 'vga|3d|display controller')
    if [ -n "$GPU" ]; then
      echo "$GPU" | sed "s/^/    ${MAGENTA}/; s/$/${NC}/"
    else
      info "    (無)"
    fi
  else
    info "未安裝 lspci, 無法列出顯示卡資訊。"
  fi
else
  sub "網路介面 / Network Interfaces:"
  FOUND=0
  for name in $(ifconfig -l 2>/dev/null); do
    case "$name" in lo0|lo|gif*|stf*|utun*|awdl*|llw*|anpi*|ap[0-9]*) continue;; esac
    mac=$(ifconfig "$name" 2>/dev/null | awk '/ether/{print $2; exit}')
    ip=$(ifconfig "$name" 2>/dev/null | awk '/inet /{print $2; exit}')
    [ -n "$mac" ] || [ -n "$ip" ] || continue
    FOUND=1
    state=$(ifconfig "$name" 2>/dev/null | awk '/status:/{print $2; exit}')
    stcolor=$GREEN; [ "$state" = "inactive" ] && stcolor=$RED
    np=$(pad_label "$name")
    printf "  ${BOLD}${LBL_COLOR}%s${NC} : IP=${CYAN}%-16s${NC} MAC=${YELLOW}%s${NC}" \
      "$np" "${ip:-none}" "$mac"
    [ -n "$state" ] && printf "  ${stcolor}($state)${NC}"
    echo
  done
  [ "$FOUND" = "0" ] && info "無法讀取網路介面"
  echo
  sub "主機資訊 / Hardware:"
  if has system_profiler; then
    system_profiler SPHardwareDataType 2>/dev/null | grep -E "Model Name|Model Identifier|Chip|Processor Name|Processor Speed|Memory|Serial" | sed "s/^/    ${MAGENTA}/; s/$/${NC}/"
  fi
  echo
  sub "顯示卡 / GPU:"
  if has system_profiler; then
    system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Chipset Model|VRAM|Metal" | sed "s/^/    ${MAGENTA}/; s/$/${NC}/"
  fi
fi

# ===================== Brand & Model =====================
section "品牌型號 / Brand & Model"
if [ "$PLATFORM" = "Linux" ]; then
  kv "CPU 廠商 / Vendor" "$(awk -F: '/^vendor_id/{gsub(/^ +/,"",$2); print $2; exit}' /proc/cpuinfo)"
  kv "CPU 型號 / Model" "${CPU_MODEL:-N/A}"
  CPU_VER=$(lscpu 2>/dev/null | awk -F: '
    /^CPU family:/{gsub(/ /,"",$2); f=$2}
    /^Model:/{gsub(/ /,"",$2); m=$2}
    /^Stepping:/{gsub(/ /,"",$2); s=$2}
    /^Microcode:/{gsub(/ /,"",$2); u=$2}
    END{out=""; if(f!="")out=out"Fam"f; if(m!="")out=out" Mdl"m; if(s!="")out=out" Stepp" s; if(u!="")out=out" ucode "u; print out}')
  [ -n "$CPU_VER" ] && kv "CPU 版本 / Version" "$CPU_VER"

  if has lspci; then
    GPU_RAW=$(lspci 2>/dev/null | grep -iE 'vga|3d|display controller' | head -n1)
    if [ -n "$GPU_RAW" ]; then
      GPU_DEV=$(echo "$GPU_RAW" | sed -E 's/^[0-9a-f:.]+ //; s/ \([^)]*\)//g')
      kv "GPU 型號 / Model" "$GPU_DEV"
    fi
  fi

  DMI_FULL=""
  if has dmidecode; then
    DMI_FULL=$(dmidecode 2>/dev/null)
    if [ -z "$DMI_FULL" ] && [ "$(id -u)" != "0" ] && has sudo; then
      DMI_FULL=$(sudo -n dmidecode 2>/dev/null)
    fi
  fi

  if [ -n "$DMI_FULL" ]; then
    MB=$(echo "$DMI_FULL" | awk '
      /Base Board Information/ {b=1; next}
      b && /Manufacturer:/ {gsub(/^.*Manufacturer:[ \t]*/,""); m=$0}
      b && /Product Name:/  {gsub(/^.*Product Name:[ \t]*/,""); p=$0}
      b && /Version:/       {gsub(/^.*Version:[ \t]*/,""); v=$0}
      /^$/ && b {print m" "p" ("v")"; exit}
    ')
    [ -n "$MB" ] && kv "主機板 / Motherboard" "$MB"

    BIO=$(echo "$DMI_FULL" | awk '
      /BIOS Information/ {b=1; next}
      b && /Vendor:/       {gsub(/^.*Vendor:[ \t]*/,""); v=$0}
      b && /Version:/      {gsub(/^.*Version:[ \t]*/,""); p=$0}
      b && /Release Date:/ {gsub(/^.*Release Date:[ \t]*/,""); d=$0}
      /^$/ && b {print v" "p" ("d")"; exit}
    ')
    [ -n "$BIO" ] && kv "BIOS / 韌體" "$BIO"
  else
    info "需要 dmidecode (root) 才能讀取主機板 / BIOS 資訊。可嘗試: sudo bash bench.sh"
  fi

  if [ -n "$DMIDECODE" ]; then
    RAM_SPD=$(echo "$DMIDECODE" | awk '
      /^\tSpeed:/ {
        s=$0; gsub(/^.*Speed:[ \t]*/,"",s)
        if (s!="Unknown" && s!="") cnt[s]++
      }
      END { for(k in cnt) printf "%d x %s ", cnt[k], k }
    ')
    [ -n "$RAM_SPD" ] && kv "記憶體頻率 / RAM Speed" "$RAM_SPD"
  fi
else
  SPHW=$(system_profiler SPHardwareDataType 2>/dev/null)
  CHIP=$(echo "$SPHW" | awk -F: '/Chip:|Processor Name:/{gsub(/^ +/,"",$2); print $2; exit}')
  MNAME=$(echo "$SPHW" | awk -F: '/Model Name:/{gsub(/^ +/,"",$2); print $2; exit}')
  MID=$(echo "$SPHW" | awk -F: '/Model Identifier:/{gsub(/^ +/,"",$2); print $2; exit}')
  FW=$(echo "$SPHW" | awk -F: '/System Firmware Version:/{gsub(/^ +/,"",$2); print $2; exit}')
  [ -n "$CHIP" ] && kv "CPU 晶片 / Chip" "$CHIP"
  [ -n "$MNAME$MID" ] && kv "機型 / Model" "$MNAME ($MID)"

  SPDISP=$(system_profiler SPDisplaysDataType 2>/dev/null)
  GCHIP=$(echo "$SPDISP" | awk -F: '/Chipset Model:/{gsub(/^ +/,"",$2); print $2; exit}')
  GVEND=$(echo "$SPDISP" | awk -F: '/Vendor:/{gsub(/^ +/,"",$2); print $2; exit}')
  [ -n "$GCHIP" ] && kv "GPU 型號 / Model" "$GCHIP${GVEND:+ ($GVEND)}"

  [ -n "$FW" ] && kv "韌體版本 / Firmware" "$FW"

  SPMEM=$(system_profiler SPMemoryDataType 2>/dev/null)
  MTYPE=$(echo "$SPMEM" | awk -F: '/Type:/{gsub(/^ +/,"",$2); print $2; exit}')
  MSPD=$(echo "$SPMEM" | awk -F: '/Speed:/{gsub(/^ +/,"",$2); print $2; exit}')
  [ -n "$MTYPE" ] && kv "記憶體型別 / Type" "$MTYPE"
  [ -n "$MSPD" ] && kv "記憶體速度 / Speed" "$MSPD"
fi

# ===================== Oversell Detection =====================
section "超開檢測 / Oversell Detection"
if [ "$PLATFORM" != "Linux" ]; then
  info "超開檢測目前僅支援 Linux。"
else
  ISSUES=0

  CACHE_SIZE=$(awk -F: '/cache size/{gsub(/ /,"",$2); print $2; exit}' /proc/cpuinfo 2>/dev/null)
  if [ -n "$CACHE_SIZE" ]; then
    kv "CPU 快取 / CPU Cache (per core)" "$CACHE_SIZE"
    CACHE_NUM=$(echo "$CACHE_SIZE" | grep -oE '[0-9]+' | head -n1)
    if [ -z "$CACHE_NUM" ] || [ "$CACHE_NUM" = "0" ]; then
      bad "CPU 快取大小為 0 -> 強烈暗示 CPU 被超開 (常見於超售 VPS)"
      ISSUES=$((ISSUES+2))
    else
      ok "CPU 快取正常 ($CACHE_SIZE)"
    fi
  else
    info "無法讀取 CPU 快取資訊"
  fi

  s1=$(awk '/^cpu /{s=$9;t=0;for(i=2;i<=11;i++)t+=$i; print s" "t}' /proc/stat 2>/dev/null)
  sleep 1
  s2=$(awk '/^cpu /{s=$9;t=0;for(i=2;i<=11;i++)t+=$i; print s" "t}' /proc/stat 2>/dev/null)
  if [ -n "$s1" ] && [ -n "$s2" ]; then
    ps=$(echo "$s1" | awk '{print $1}'); pt=$(echo "$s1" | awk '{print $2}')
    cs=$(echo "$s2" | awk '{print $1}'); ct=$(echo "$s2" | awk '{print $2}')
    steal_pct=$(awk -v a="$cs" -v b="$ps" -v c="$ct" -v d="$pt" 'BEGIN{dt=c-d; if(dt<=0){print 0;exit} printf "%.1f",(a-b)*100/dt}')
    kv "vCPU Steal / Steal (1s)" "$steal_pct%"
    steal_int=$(printf "%.0f" "$steal_pct" 2>/dev/null)
    if [ "$steal_int" -ge 20 ] 2>/dev/null; then
      bad "Steal 時間 >= 20% -> CPU 嚴重超開 / 鄰居佔用過高"
      ISSUES=$((ISSUES+3))
    elif [ "$steal_int" -ge 10 ] 2>/dev/null; then
      warn "Steal 時間 10~20% -> CPU 可能被超開"
      ISSUES=$((ISSUES+2))
    elif [ "$steal_int" -ge 5 ] 2>/dev/null; then
      warn "Steal 時間 5~10% -> CPU 存在輕度競爭"
      ISSUES=$((ISSUES+1))
    else
      ok "Steal 時間 < 5% -> CPU 無顯著競爭"
    fi
  fi

  if [ -n "$DMIDECODE" ]; then
    PHYS_GB=$(echo "$DMIDECODE" | awk '/^\tSize:/{if($2!="No"){gsub(/[^0-9]/,"",$2); t+=$2}} END{print t+0}')
    ALLOC_GB=$(( TOTAL_RAM / 1024 ))
    kv "物理記憶體 / Physical (dmi)" "${PHYS_GB} GB"
    kv "分配記憶體 / Allocated (sys)" "${ALLOC_GB} GB"
    if [ -n "$PHYS_GB" ] && [ "$PHYS_GB" -gt 0 ] 2>/dev/null && [ "$ALLOC_GB" -gt "$PHYS_GB" ] 2>/dev/null; then
      bad "系統可用記憶體大於偵測到的物理記憶體 -> 記憶體可能被超開"
      ISSUES=$((ISSUES+2))
    else
      ok "記憶體分配與物理記憶體一致"
    fi
  fi

  if [ -n "$TOTAL_CORES" ] && [ -n "$SOCKETS" ] && [ -n "$CORES_PER_SOCKET" ] && [ -n "$THREADS_PER_CORE" ]; then
    PHYS_CORES=$(( SOCKETS * CORES_PER_SOCKET ))
    if [ "$TOTAL_CORES" -gt $(( PHYS_CORES * THREADS_PER_CORE )) ] 2>/dev/null; then
      warn "vCPU ($TOTAL_CORES) 超過物理核心 x 執行緒數 ($PHYS_CORES x $THREADS_PER_CORE) -> 可能存在 CPU 超開"
      ISSUES=$((ISSUES+1))
    else
      ok "vCPU 數量與物理核心比例正常"
    fi
  fi

  if [ -f /proc/user_beancounters ]; then
    info "偵測到 OpenVZ (user_beancounters):"
    awk 'NR>2{if($3~/[0-9]/&&$4~/[0-9]/&&$5~/[0-9]/){n++; if($5>$4) o++}} END{print "   限制項: "n"  超限(held>max): "o}' /proc/user_beancounters 2>/dev/null
  fi

  echo
  case "$ISSUES" in
    0) ok "整體未發現明顯超開跡象。";;
    1|2) warn "存在輕度超開風險 ($ISSUES 項指標)。";;
    *) bad "存在明顯超開跡象 ($ISSUES 項指標)! 請謹慎評估該主機。";;
  esac
fi

# ===================== CPU Benchmark =====================
section "CPU 基準測試 / CPU Benchmark"
if has sysbench; then
  info "使用 sysbench (${LOGICAL_CORES:-$(nproc)} 執行緒, 10s)..."
  SYSBENCH_OUT=$(sysbench cpu --threads="${LOGICAL_CORES:-1}" --time=10 --cpu-max-prime=20000 run 2>/dev/null)
  kv "執行緒 / Threads" "${LOGICAL_CORES:-1}"
  kv "事件/秒 / Events/sec" "$(echo "$SYSBENCH_OUT" | awk '/events per second/{print $4}')"
  kv "總事件 / Total Events" "$(echo "$SYSBENCH_OUT" | awk '/total number of events/{print $NF}')"
elif has openssl; then
  info "未安裝 sysbench, 改用 openssl speed 測試..."
  OSPEED_OUT=$(openssl speed -multi "${LOGICAL_CORES:-$(nproc)}" -seconds 3 sha256 2>/dev/null | \
    awk '/^sha256[[:space:]]/{printf "  \033[1;33m%-34s\033[0m : \033[0;32m%s\033[0m\n","sha256 (KB/s)",$NF}')
  [ -n "$OSPEED_OUT" ] && echo "$OSPEED_OUT"
  GCM_OUT=$(openssl speed -multi "${LOGICAL_CORES:-$(nproc)}" -seconds 3 -evp aes-128-gcm 2>/dev/null | \
    awk '/^AES-128-GCM[[:space:]]/{printf "  \033[1;33m%-34s\033[0m : \033[0;32m%s\033[0m\n","AES-128-GCM (KB/s)",$NF}')
  [ -n "$GCM_OUT" ] && echo "$GCM_OUT"
else
  info "未找到 sysbench / openssl, 跳過 CPU 基準測試。"
fi

# ===================== Disk I/O Benchmark =====================
section "磁碟 I/O 基準測試 / Disk I/O"
if [ "$PLATFORM" = "Linux" ]; then
  IO_FILE=/tmp/.bench_io_test.$$
  info "寫入測試 (1G, direct)..."
  WRESULT=$(dd if=/dev/zero of="$IO_FILE" bs=1M count=1024 oflag=direct conv=fdatasync 2>&1)
  WSPEED=$(echo "$WRESULT" | awk -F'[,=]' '/copied/{gsub(/ /,"",$4); print $4}')
  kv "寫入速度 / Write Speed" "$WSPEED"
  info "讀取測試 (1G, direct)..."
  echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
  RRESULT=$(dd if="$IO_FILE" of=/dev/null bs=1M count=1024 iflag=direct 2>&1)
  RSPEED=$(echo "$RRESULT" | awk -F'[,=]' '/copied/{gsub(/ /,"",$4); print $4}')
  kv "讀取速度 / Read Speed" "$RSPEED"
  rm -f "$IO_FILE"
  IO_NUM=$(echo "$WSPEED" | grep -oE '[0-9.]+' | head -n1)
  if [ -n "$IO_NUM" ] && awk -v n="$IO_NUM" 'BEGIN{exit !(n<50)}'; then
    warn "寫入速度 < 50 MB/s -> 磁碟可能為共享/超開磁碟"
  else
    ok "磁碟寫入效能正常"
  fi
else
  info "macOS 上使用 dd 直接測試可能影響系統, 已跳過。"
fi


echo
echo -e "${BOLD}${CYAN}===== 測試完成 / Done =====${NC}"
echo -e "${DIM}數據僅供參考, 超開檢測結果受虛擬化技術與檢測權限影響。${NC}"
