#!/bin/zsh
# build_all.sh — 一键清理重建全部工程 + 自检
#
# 用法：
#   ./build_all.sh          # 清理重建 7 个工程（ESP32/STC32G 自动跑 verify）
#   ./build_all.sh -q       # 同上，但只显示每个工程的最终结果
#
# 任何一个工程失败立即停止并保留失败工程的编译输出，方便排查。
# STM32/Pico 用 arm-none-eabi，ESP32 用 riscv/xtensa，STC32G 用 sdcc-c251，
# 全部走工程内 Makefile 的绝对路径配置，无需设置 PATH。
# Pico 的 Makefile 是 CMake 薄封装，首次构建会调用 CMake 配置 SDK。

set -e
cd "$(dirname "$0")/.."

PROJECTS=(
  projects/stm32/f1xx/stm32f103-blink
  projects/stm32/f4xx/stm32f407-blink
  projects/stm32/h7xx/stm32h743-blink
  projects/esp32/esp32c3-blink
  projects/esp32/esp32s3-blink
  projects/stc32/stc32g144k246-blink
  projects/pico/rp2040/pico-blink
)

QUIET=0
[ "$1" = "-q" ] && QUIET=1

for p in $PROJECTS; do
  echo "===== $p ====="
  if [ "$QUIET" = 1 ]; then
    ( cd "$p" && make -s clean && make -s > /dev/null && make -s size )
  else
    ( cd "$p" && make -s clean && make -s && make -s size )
  fi
  echo ""
done

# STC32G 工程额外跑静态自检
( cd projects/stc32/stc32g144k246-blink && make -s verify > /dev/null )

echo "全部 7 个工程构建成功 ✅"
echo "STM32：build/*.{elf,hex,bin}；ESP32：build/*.{elf,bin,esp.bin}；STC32G：build/*.{ihx,hex,bin}；Pico：build/*.{uf2,elf,bin,hex}"
