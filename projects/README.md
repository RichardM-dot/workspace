# projects — STM32 + ESP32 + Pico 多芯片裸机 / FreeRTOS 工程集

> 7 个工程覆盖 **ARM Cortex-M3 / M4F / M7 / M0+（双核）+ RISC-V RV32IMC + Xtensa LX7 + 80251** 七种内核/架构。
> STM32 / ESP32 / STC32G 工程**自包含**（库文件在工程内），Pico 工程使用工作区共享的
> **Pico SDK 2.3.1**；全部**全中文注释**，构建入口统一为 `make`。
> 4 套本地编译器 + CMake / Pico SDK 工具，未装 esptool / ESP-IDF 全家桶，未 fork 任何仓库。

---

## 目录

- [1. 项目总览](#1-项目总览)
- [2. 目录结构](#2-目录结构)
- [3. 工具链](#3-工具链)
- [4. 七个工程详解](#4-七个工程详解)
  - [4.1 stm32f103-blink](#41-stm32f103-blink)
  - [4.2 stm32f407-blink](#42-stm32f407-blink)
  - [4.3 stm32h743-blink](#43-stm32h743-blink)
  - [4.4 esp32c3-blink](#44-esp32c3-blink)
  - [4.5 esp32s3-blink](#45-esp32s3-blink)
  - [4.6 stc32g144k246-blink](#46-stc32g144k246-blink)
  - [4.9 pico-blink](#49-pico-blink)
- [5. 编译命令](#5-编译命令)
- [6. 自检命令](#6-自检命令)
- [7. 固件烧录](#7-固件烧录)
- [8. 维护操作](#8-维护操作)
- [9. 故障排查](#9-故障排查)
- [10. 脚本清单](#10-脚本清单)
- [11. 快速参考表](#11-快速参考表)

---

## 1. 项目总览

| # | 工程 | 内核/架构 | 芯片 | 时钟 | LED | RTOS | 固件 |
|---|---|---|---|---|---|---|---|
| 1 | `stm32f103-blink` | Cortex-M3 | STM32F103C8T6 | HSI/2×16 = 64 MHz | PC13（低电平亮） | FreeRTOS `ARM_CM3` | elf/hex/bin |
| 2 | `stm32f407-blink` | Cortex-M4F | STM32F407VGT6 | HSI÷16×336÷2 = 168 MHz | PD12（Discovery） | FreeRTOS `ARM_CM4F` | elf/hex/bin |
| 3 | `stm32h743-blink` | Cortex-M7 | STM32H743ZIT6 | HSI 64 MHz | PB0（Nucleo 绿灯） | FreeRTOS `ARM_CM7/r0p1` | elf/hex/bin |
| 4 | `esp32c3-blink` | RISC-V RV32IMC | ESP32-C3 | 160 MHz（tick 用 16 MHz SYSTIMER） | GPIO8 | FreeRTOS（单核，自定义 RISC-V port） | elf/bin/esp.bin |
| 5 | `esp32s3-blink` | Xtensa LX7 call0 | ESP32-S3 | 40 MHz（CCOMPARE0 tick） | GPIO48（bank1 bit16） | FreeRTOS SMP（双核，自定义 Xtensa port） | elf/bin/esp.bin |
| 6 | `stc32g144k246-blink` | Intel MCS-251（80251） | STC32G144K246 | 24 MHz HIRC（可调，最高 120 MHz） | P0.0（低电平亮）+ P4.1 电源使能 | 裸机 | ihx/hex/bin |
| 7 | `pico-blink` | 双核 Cortex-M0+ | RP2040（Raspberry Pi Pico） | 125 MHz（SDK 默认，最高 133） | GP25（高电平亮） | 裸机（Pico SDK） | uf2/elf/bin/hex |

> **ESP32 FreeRTOS 状态（2026-11）**：C3 与 S3 都已把内核、port、配置、启动和 tick 完整接入 `make`，
> 并增加了 `make verify` 静态自检。C3 是单核 RISC-V；S3 是双核 SMP（S32C1I 自旋锁 +
> FROM_CPU IPI + 每核 CCOMPARE0 tick）。两个工程都**尚未上板实测**，验证边界见第 4.7 节。
>
> **Pico 状态（2026-11）**：`pico-blink` 用 Pico SDK 2.3.1 + CMake 构建，产出 UF2/ELF/BIN/HEX，
> 板载 GP25 LED 500 ms 翻转，stdio 同时开 USB CDC 与 UART0。**编译 / 链接与上板实测均已通过**
> （2026-11-20，RP2040 B2；picotool 烧录+校验 OK，BOOTSEL+UF2 拷贝也可用，USB CDC banner/心跳正常）。

### 共性设计

- **库的来源**：STM32/ESP32 工程把厂商库复制进 `Drivers/` + `Middlewares/`；Pico 工程通过 `PICO_SDK_PATH` 共享 `libraries/pico/pico-sdk`，不重复 vendoring
- **构建入口指向本地工具链**，绝对路径，不依赖 `PATH`；Pico 的 `Makefile` 是 CMake 薄封装
- **统一目标**：STM32/ESP32/STC32G 为 `all`（默认）、`size`、`dis`、`symbols`、`clean`；ESP32 另有 `verify`；Pico 为 `all`、`size`、`flash`、`flash-uf2`、`debug`、`clean`
- **中文注释**：所有新增的 `main.c`、`Makefile`、`CMakeLists.txt`、`FreeRTOSConfig.h`、`startup`、`ld` 均含中文说明
- **逆向自检**：ESP32 工程自带 `tools/verify.py`（`make verify`）；STM32 用第 6.1 节的 `nm`/`xxd` 命令；Pico 用第 6.6 节的 UF2/向量表自检

---

## 2. 目录结构

```
/Users/theo-richard/workspace/
├── toolchains/                               # 全部交叉编译工具链
│   ├── arm-none-eabi/                        # ARM 工具链（STM32/Pico 用），GCC 15.3.1
│   ├── xtensa-esp-elf/                       # Xtensa 工具链（S3 用），esp-14.2.0_20241119
│   ├── riscv32-esp-elf/                      # RISC-V 工具链（C3 用），esp-14.2.0_20241119
│   ├── sdcc-c251/                            # SDCC MCS-251 分支（STC32G）
│   ├── cmake/                                # CMake 3.31.6（Pico 构建）
│   └── pico-sdk-tools/                       # pioasm / picotool 2.3.1
│
├── libraries/                                # 官方库 / 第三方库（只读参考，按芯片族分目录）
│   ├── stm32/
│   │   ├── STM32F1/{cmsis-device-f1, stm32f1xx-hal-driver}/
│   │   ├── STM32F4/cmsis-device-f4/          # F407 设备包
│   │   ├── STM32F411/stm32f4xx-hal-driver/   # F407 复用此 HAL
│   │   ├── STM32H7/{cmsis-device-h7, stm32h7xx-hal-driver}/
│   │   └── cmsis*/                           # CMSIS Core / F4 设备包
│   ├── esp32/esp-idf/                        # IDF 稀疏克隆（soc/hal/esp_common/esp_rom/…）
│   ├── freertos/FreeRTOS-Kernel/             # FreeRTOS 内核上游源
│   ├── display/oledlib/                      # OLED 显示库（Keil 工程，含 STM32F10x FWLib）
│   ├── pico/pico-sdk/                        # Pico SDK 2.3.1（含 TinyUSB/lwIP/mbedTLS/BTstack）
│   └── stc/                                  # STC 官方库（待放置，见 libraries/stc/README.md）
│
├── projects/
│   ├── README.md                             # 本文档
│   ├── stm32/
│   │   ├── f1xx/stm32f103-blink/             # FreeRTOS ARM_CM3
│   │   ├── f4xx/{stm32f411-blink, stm32f407-blink}/   # ★ f411 为原模板工程
│   │   └── h7xx/stm32h743-blink/             # FreeRTOS ARM_CM7/r0p1
│   ├── pico/rp2040/pico-blink/               # Pico SDK + CMake，GP25 blink
│   └── esp32/
│       ├── esp32c3-blink/
│       │   ├── Drivers/FreeRTOS/             # 内核 + baremetal/port（RISC-V 单核）
│       │   ├── main/main.c                   # FreeRTOS LED 任务
│       │   ├── startup/startup_c3.S          # mtvec + FreeRTOS trap handler
│       │   ├── ld/esp32c3.ld                 # 0x40380000 / 0x3FC80000，别名跳过
│       │   ├── tools/{mkimage.py, verify.py} # ELF → ESP 镜像 / 29 项自检
│       │   └── Makefile
│       └── esp32s3-blink/
│           ├── Drivers/FreeRTOS/             # 内核 + baremetal/port（Xtensa call0 SMP）
│           ├── main/{main.c,uart.c,uart.h}   # 双核心跳 + UART0 输出
│           ├── startup/startup_s3.S          # VECBASE + bss 清零
│           ├── ld/esp32s3.ld                 # 0x4037C000 / 0x3FC88000，别名跳过
│           ├── tools/{mkimage.py, verify.py} # ELF → ESP 镜像 / 38 项自检
│           └── Makefile
│
├── scripts/
│   └── build_all.sh                          # 一键清理重建 7 工程 + 自检
│
├── references/                               # 学习用完整仓库（RTOS/文件系统/图形/项目实战）
│   ├── rtos/                                 # FreeRTOS / Zephyr / NuttX / ThreadX / RIOT
│   ├── filesystems/                          # littlefs / FlashDB / SFUD / EasyFlash
│   ├── graphics/                             # LVGL / u8g2
│   └── firmware/                             # OV-Watch、micropython 等实战仓库
│
└── docs/knowledge-base/                      # 源码精读知识库（INDEX.md 总索引）
```

> 一键重建脚本在 `scripts/build_all.sh`；每个工程自带 `make` / `make verify` 与
> `README.md`，ESP32 头文件维护按需手动复制（见 8.1）。

---

## 3. 工具链

### 3.1 ARM 工具链（STM32 / Pico）

- **路径**：`toolchains/arm-none-eabi/bin/arm-none-eabi-*`
- **版本**：15.3.1（原生 arm64）
- **前缀**：`arm-none-eabi-`
- **用途**：STM32 全系；Pico（RP2040/RP2350）也使用同一套 `arm-none-eabi-gcc`

### 3.2 Xtensa 工具链（ESP32-S3）

- **路径**：`toolchains/xtensa-esp-elf/bin/xtensa-esp-elf-*`
- **版本**：crosstool-NG `esp-14.2.0_20241119`（Apple Silicon）
- **前缀**：`xtensa-esp-elf-`
- **来源**：https://github.com/espressif/crosstool-NG/releases

### 3.3 RISC-V 工具链（ESP32-C3）

- **路径**：`toolchains/riscv32-esp-elf/bin/riscv32-esp-elf-*`
- **版本**：crosstool-NG `esp-14.2.0_20241119`（Apple Silicon）
- **前缀**：`riscv32-esp-elf-`

### 3.4 SDCC MCS-251 工具链（STC32G）

- **路径**：`toolchains/sdcc-c251/bin/sdcc`
- **版本**：SDCC `4.6.0` 的社区 MCS-251 分支（`-mmcs251`，GPL-2.0）
- **来源**：https://github.com/zevorn/sdcc-c251
- **说明**：STC 官方只有 Windows 版 Keil C251；上游 SDCC 不支持 251 内核，
  所以 STC32G 工程必须用这个分支。安装方法见 `libraries/stc/README.md` 第 10 节。

### 3.5 CMake 与 Pico SDK 工具（Pico）

- **CMake**：`toolchains/cmake/bin/cmake`，版本 **3.31.6**
- **Pico SDK**：`libraries/pico/pico-sdk`，版本 **2.3.1**
- **pioasm / picotool**：`toolchains/pico-sdk-tools/{pioasm,picotool}`，版本 **2.3.1**
- **说明**：Pico 工程用 CMake 组织构建，根目录 `Makefile` 只是薄封装；
  SDK 不复制进工程，升级 SDK 只需替换 `libraries/pico/pico-sdk`。

### 3.6 版本验证

```bash
/Users/theo-richard/workspace/toolchains/arm-none-eabi/bin/arm-none-eabi-gcc --version | head -1
/Users/theo-richard/workspace/toolchains/xtensa-esp-elf/bin/xtensa-esp-elf-gcc --version | head -1
/Users/theo-richard/workspace/toolchains/riscv32-esp-elf/bin/riscv32-esp-elf-gcc --version | head -1
/Users/theo-richard/workspace/toolchains/sdcc-c251/bin/sdcc --version | head -1
/Users/theo-richard/workspace/toolchains/cmake/bin/cmake --version | head -1
/Users/theo-richard/workspace/toolchains/pico-sdk-tools/picotool/picotool version
```

---

## 4. 七个工程详解

### 4.1 stm32f103-blink

| 项 | 值 |
|---|---|
| 路径 | `projects/stm32/f1xx/stm32f103-blink/` |
| 芯片 | STM32F103C8T6（64K Flash / 20K RAM） |
| 内核 | Cortex-M3 |
| 时钟 | HSI/2 × 16 = 64 MHz，2 WS，APB1 ÷2 |
| LED | PC13，低电平亮 |
| RTOS 端口 | `Middlewares/Third_Party/FreeRTOS/portable/GCC/ARM_CM3` |
| FreeRTOS 堆 | **8KB**（20K RAM 装不下 32K 堆） |
| HAL 时基 | TIM3 |
| 启动文件 | `startup_stm32f103xb.s`（3 向量已改为 `vPortSVCHandler`/`xPortPendSVHandler`/`xPortSysTickHandler`） |
| 链接脚本 | `STM32F103XB_FLASH.ld` |
| 编译选项 | `-mcpu=cortex-m3 -mthumb -DUSE_HAL_DRIVER -DSTM32F103xB` |

### 4.2 stm32f407-blink

| 项 | 值 |
|---|---|
| 路径 | `projects/stm32/f4xx/stm32f407-blink/` |
| 芯片 | STM32F407VGT6（1024K Flash / 128K RAM + 64K CCM） |
| 内核 | Cortex-M4F（FPv4-SP） |
| 时钟 | HSI÷16 × 336 ÷ 2 = 168 MHz，5 WS |
| LED | PD12（Discovery 板） |
| RTOS 端口 | `ARM_CM4F` |
| FreeRTOS 堆 | 32KB |
| HAL 时基 | TIM3 |
| 启动文件 | `startup_stm32f407xx.s` |
| 链接脚本 | `STM32F407VGTx_FLASH.ld`（手写） |
| 编译选项 | `-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard -DSTM32F407xx` |

### 4.3 stm32h743-blink

| 项 | 值 |
|---|---|
| 路径 | `projects/stm32/h7xx/stm32h743-blink/` |
| 芯片 | STM32H743ZIT6（2048K Flash / 128K DTCM@0x20000000 + 512K AXI） |
| 内核 | Cortex-M7（FPv5-D16，双精度） |
| 时钟 | HSI 64 MHz，0 WS，开 I/D-Cache |
| LED | PB0（Nucleo 绿灯） |
| RTOS 端口 | `ARM_CM7/r0p1` |
| FreeRTOS 堆 | 32KB |
| HAL 时基 | TIM3 |
| 启动文件 | `startup_stm32h743xx.s` |
| 链接脚本 | `STM32H743ZITx_FLASH.ld`（手写，DTCM 为主 RAM） |
| 编译选项 | `-mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard -DSTM32H743xx` |

### 4.4 esp32c3-blink

| 项 | 值 |
|---|---|
| 路径 | `projects/esp32/esp32c3-blink/` |
| 芯片 | ESP32-C3 |
| 架构 | RISC-V RV32IMC（`-march=rv32imc_zicsr_zifencei -mabi=ilp32 -mcmodel=medany`） |
| RTOS | FreeRTOS 单核（IDF 内核源码 + `Drivers/FreeRTOS/baremetal/port` 自定义 RISC-V port） |
| tick | SYSTIMER unit0 target0 周期模式，16 MHz / 1 kHz，CPU 中断 6 |
| trap | `freertos_risc_v_trap_handler` @ 0x40380040，`mtvec` 直接模式 |
| FreeRTOS 配置 | 160 MHz、1 kHz、64 KB heap、`configNUMBER_OF_CORES = 1` |
| LED | GPIO8 |
| 内存布局 | IRAM 0x40380000..0x403CE710 / DRAM 0x3FC80000..0x3FCCE710；**0x4037C000..0x40380000 是 16 KB 指令 cache，不能放代码** |
| 别名关系 | DRAM = IRAM − 0x700000；`.dram_skip` 先跳过整个 IRAM 镜像别名区，再放 `.bss` |
| 栈 | DRAM 顶部 16 KB（`_stack_bottom.._stack_top`） |
| 启动入口 | `_start` @ 0x40380000（`startup/startup_c3.S`） |
| 寄存器访问 | `soc/gpio_struct.h` → `GPIO->enable_w1ts.val` / `out_w1tc.val` / `out_w1ts.val` |
| 镜像格式 | 自定义 `tools/mkimage.py`：magic=0xE9, chip_id=0x0005, DIO/40 MHz/4 MB, wp_pin=0xEE, SHA256 |
| 固件 | `build/esp32c3-blink.esp.bin`（约 6912 B，entry=0x40380000） |
| 自检 | `make verify`：29 项（入口、cache 区、别名、`.bss`/栈、镜像） |

### 4.5 esp32s3-blink

| 项 | 值 |
|---|---|
| 路径 | `projects/esp32/esp32s3-blink/` |
| 芯片 | ESP32-S3 |
| 架构 | Xtensa LX7 call0 ABI（`-mlongcalls -mabi=call0 -mtext-section-literals`） |
| RTOS | FreeRTOS SMP，双核（IDF 内核源码 + `Drivers/FreeRTOS/baremetal/port` 自定义 Xtensa port） |
| 调度 | S32C1I 自旋锁 + 递归计数；FROM_CPU source0→core1、source1→core0；每核独立 CCOMPARE0 tick |
| tick / IPI | CPU 中断 6 / 7，均为 level 1，共用 0x340 向量，由 `xt_tick_handler_c()` 读 INTERRUPT 分发 |
| 上下文 | 96 字节完整帧（a0–a15、SAR、EPC、PS、SCOMPARE1、LBEG/LEND/LCOUNT） |
| core1 启动 | `ets_set_appcpu_boot_addr(0x40000720)` + `SYSTEM_CORE_1_CONTROL_0` 时钟/复位；core1 就绪握手后才启动 core0 首任务 |
| FreeRTOS 配置 | 40 MHz、1 kHz、64 KB heap、`configNUMBER_OF_CORES = 2` |
| LED | GPIO48（bank1，bit = 48−32 = 16） |
| 内存布局 | IRAM 0x4037C000..0x403C0000 / DRAM 0x3FC88000..0x3FCD0000 |
| 别名关系 | DRAM = IRAM − 0x6F0000；`.dram_skip` 先跳过整个 IRAM 镜像别名区，再放 `.bss` |
| 栈 | 0x3FCC9000..0x3FCCD000（16 KB） |
| 启动入口 | `_start` @ 0x4037C3D4；向量表 @ 0x4037C000；0x340 槽位 → `_xt_lowint1` |
| UART | UART0（GPIO43，115200，ROM 已初始化），双核各一个任务打印心跳 |
| 镜像格式 | `tools/mkimage.py`：magic=0xE9, chip_id=0x0009, DIO/40 MHz/4 MB, wp_pin=0xEE, SHA256 |
| 固件 | `build/esp32s3-blink.esp.bin`（约 10464 B，entry=0x4037C3D4） |
| 自检 | `make verify`：38 项（向量表、0x340 跳转、别名、`.bss`/栈、初始 PS、镜像） |

### 4.6 stc32g144k246-blink

| 项 | 值 |
|---|---|
| 路径 | `projects/stc32/stc32g144k246-blink/` |
| 芯片 | STC32G144K246（LQFP100，246KB Flash / 16K edata + 128K xdata + 4K RAM） |
| 内核 | Intel MCS-251（80251），兼容 1T 8051 |
| 工具链 | `toolchains/sdcc-c251/bin/sdcc`（SDCC 4.6.0 的 MCS-251 分支） |
| 代码模型 | `--model-small --code-loc 0xFF0000 --iram-size 0x4000` |
| 时钟 | 默认 HIRC 24MHz（ISP 下载时选择；48MHz 时改 `MAIN_Fosc`） |
| LED | **P0.0** 强推挽输出，低电平点亮；**P4.1** 低电平使能 LED 电源 |
| 启动 | sdcc 运行时在 `FF:0000` 放 `LJMP 0x0003; EJMP 0xFF000D`，`s_HOME=0xFF0000` |
| 固件 | `build/stc32g144k246-blink.{ihx,hex,bin}`，当前 ROM **255 B** |
| 自检 | `make verify`：16 项（地址段、复位跳转、符号、ROM、bin、SFR 初始化） |
| 文档 | `README.md` + **`PIN_GUIDE.md`（LQFP100 全部 100 脚 + 706 条复用功能）** |

> STC 官方没有 macOS 编译器，上游 SDCC 也不支持 251 内核；本工程用社区分支
> `zevorn/sdcc-c251`（GPL-2.0）编译。官方例程包/头文件放在
> `libraries/stc/STC32G144K246/DEMO-CODE/`，官方原版头文件在
> `Drivers/STC32G/Inc/STC32G144K246.H`（Keil 语法，只作参考）。
> **OpenOCD 不支持 STC 烧录**，烧录用 AiCube-ISP（Windows/Wine）或 stcgal。

### 4.7 ESP32 FreeRTOS 实现与验证边界

**C3（单核）**

- `Makefile` 从工程内 `Drivers/FreeRTOS/` 完整编译内核（tasks/queue/list/timers/event_groups/stream_buffer）+ `baremetal/heap_4.c` + `baremetal/port`，不依赖 IDF 构建系统。
- 启动：`startup_c3.S` 设 `sp`、把 `mtvec` 指向 `freertos_risc_v_trap_handler`、清 bss，再调 `main()`。
- tick：port 直接配置 SYSTIMER unit0 target0 周期模式（16 MHz / 1 kHz），CPU 中断 6 进入 trap handler，调用 `xTaskIncrementTick()`。
- 关键符号（当前镜像）：`_start` 0x40380000、trap handler 0x40380040、`vTaskStartScheduler` 0x40381150、`pxCurrentTCBs` 0x3FC91C20。

**S3（双核 SMP）**

- 一个内核、两个核：`pxCurrentTCBs[2]`，每核独立临界区嵌套计数、CCOMPARE0 tick、FROM_CPU IPI 通道。
- 启动：core0 的 `xPortStartScheduler()` 安装向量/使能 IPI 和 tick，然后用 `ets_set_appcpu_boot_addr(0x40000720)` + `SYSTEM_CORE_1_CONTROL_0` 释放 core1；core1 在独立引导栈上设置自己的 VECBASE、IPI、tick，置 `xCore1Ready` 后进入自己的首个任务；core0 等待该标志后才启动首任务。
- 中断：tick（CPU int 6）与 IPI（int 7）都是 level 1，共用 0x340 用户向量；`_xt_lowint1` 保存 96 字节上下文，`xt_tick_handler_c()` 读 `INTERRUPT` 分发。ISR 退出时把 SP 写回 TCB 并调用 `vTaskSwitchContext()`。
- 同步：S32C1I 自旋锁（owner = core+1，支持同核递归）；`portYIELD_WITHIN_API()` 用自发 IPI 把切换延迟到临界区退出后；跨核 `portYIELD_CORE()` 用 source0/source1 定向触发。
- 已修复的致命问题：
  1. **IRAM/DRAM 别名重叠**（`.text` 0x4037C000 与 `.bss` 0x3FC80000 物理重叠，清 bss 会擦掉代码）；
  2. 初始任务 PS=0（首次 `rfe` 异常）；
  3. ISR 退出只重载当前 TCB、不调用 `vTaskSwitchContext`（tick 永不切换）；
  4. `xPortInIsrContext()` 用 `PS.INTLEVEL` 误判任务临界区；
  5. IPI 被错误规划到 level-2 的 0x180 向量。
- 关键符号（当前镜像）：`_vector_table` 0x4037C000、`_start` 0x4037C3D4、`_xt_lowint1` 0x4037C410、`core1_entry` 0x4037C640、`vTaskStartScheduler` 0x4037DF90、`pxCurrentTCBs` 0x3FC9FA50。

**共同的验证边界**

- 目前所有结论来自 `make`、`nm`、`objdump`、`readelf` 和镜像 SHA256 自检；**没有上板实测**（本机无串口设备、无 esptool）。
- 已知限制：
  - S3 的 tick 按 `configCPU_CLOCK_HZ = 40 MHz` 估算；若实际主频不同，tick 会等比例偏差。
  - 两工程都未保存 FPU/coprocessor 上下文（当前 demo 不用浮点）。
  - ISR 直接使用被打断任务的栈，没有独立中断栈。
  - S3 的 `vPortYield()` 是直接保存上下文后调度，未使用 IDF 的 software-interrupt 帧。
- 上板验证方法：烧到 **0x0**（ROM 直接启动），S3 用 UART0（GPIO43，115200）看 `[core0]/[core1] tick` 心跳；C3 看 GPIO8 LED（500 ms 翻转）。

### 4.8 工程目录结构（STM32 / ESP32 / STC32G）

**STM32 工程（以 stm32f103-blink 为例）：**
```
stm32f103-blink/
├── Core/
│   ├── Inc/
│   │   ├── main.h
│   │   └── stm32f1xx_hal_conf.h
│   └── Src/
│       ├── main.c                     # 时钟 + GPIO + RTOS 任务（中文注释）
│       ├── stm32f1xx_it.c
│       ├── stm32f1xx_hal_msp.c
│       └── system_stm32f1xx.c
├── Config/
│   ├── FreeRTOSConfig.h               # 堆 8KB / CPU 64MHz
│   └── stm32f1xx_hal_timebase.c       # TIM3 作 HAL 时基
├── Drivers/
│   ├── CMSIS/
│   │   ├── Device/ST/STM32F1xx/Include/    # 设备包头
│   │   └── Include/                        # CMSIS 核心头
│   └── STM32F1xx_HAL_Driver/
│       ├── Inc/
│       └── Src/
├── Middlewares/Third_Party/FreeRTOS/
│   ├── Source/                        # FreeRTOS 内核 + heap_4.c
│   └── portable/GCC/ARM_CM3/          # CM3 端口
├── startup_stm32f103xb.s
├── STM32F103XB_FLASH.ld
├── Makefile
└── build/                             # 编译产物
```

**ESP32 工程（以 esp32c3-blink 为例）：**
```
esp32c3-blink/
├── Drivers/
│   ├── idf/
│   │   ├── soc_c3/
│   │   │   ├── include/               # soc.h, soc_caps.h, gpio_pins.h, ...
│   │   │   └── register/soc/          # gpio_struct.h, uart_struct.h, i2c_struct.h, ...
│   │   ├── soc_shared/include/
│   │   ├── hal_c3/include/
│   │   ├── hal_shared/include/
│   │   ├── esp_common/include/
│   │   ├── esp_rom_c3/include/
│   │   ├── esp_rom_shared/include/
│   │   ├── esp_hal_uart-c3/hal/       # uart_types.h, uart_hal.h, ...
│   │   └── esp_hal_gpio-c3/hal/       # gpio_types.h, gpio_hal.h, ...
│   └── FreeRTOS/
│       ├── FreeRTOS-Kernel/           # tasks/queue/list/timers/event_groups/stream_buffer
│       ├── esp_additions/             # IDF 的 tasks.c 附加实现
│       └── baremetal/                 # FreeRTOSConfig.h + heap_4.c + port/
│           └── port/                  # port.c, portasm.S, portmacro.h（芯片专用）
├── main/main.c                        # FreeRTOS LED 任务（中文注释）
├── startup/startup_c3.S               # mtvec + bss + main
├── ld/esp32c3.ld                      # 0x40380000 / 0x3FC80000，别名跳过
├── tools/mkimage.py                   # ELF → ESP 官方镜像（零依赖）
├── tools/verify.py                    # 29 项静态自检
├── Makefile
└── build/
```

**STC32G 工程（stc32g144k246-blink）：**
```
stc32g144k246-blink/
├── Config/
│   └── stc32g144k246_conf.h           # 主频/LED 引脚/闪烁周期
├── Core/
│   ├── Inc/delay.h
│   └── Src/{main.c,delay.c}           # 时钟/GPIO 初始化 + 主循环 + 软件延时
├── Drivers/STC32G/
│   ├── Inc/STC32G144K246.H            # 官方原版头（Keil 语法，参考）
│   ├── Inc/stc32g144k246_regs.h       # SDCC 兼容 SFR 定义（工程使用）
│   └── README.md
├── tools/verify.py                    # 16 项静态自检
├── Makefile
├── README.md
├── PIN_GUIDE.md                       # LQFP100 全部 100 脚 + 复用功能
└── build/
```

---

### 4.9 pico-blink

| 项 | 值 |
|---|---|
| 路径 | `projects/pico/rp2040/pico-blink/` |
| 芯片 / 板型 | RP2040（Raspberry Pi Pico，2 MB Flash / 264 KB SRAM） |
| 内核 | 双核 Cortex-M0+，SDK 默认 125 MHz（芯片最高 133 MHz） |
| LED | **GP25**，高电平点亮，500 ms 翻转 |
| 构建 | Pico SDK 2.3.1 + CMake 3.31.6；根目录 `Makefile` 是薄封装 |
| stdio | USB CDC + UART0（GP0 TX / GP1 RX，115200 8N1） |
| 产物 | `build/pico-blink.{uf2,elf,bin,hex,map}` |
| 烧录 | UF2 拖拽 / `picotool load` / OpenOCD + CMSIS-DAP（`target/rp2040.cfg`） |
| 状态 | **已上板实测通过**（2026-11-20，RP2040 B2）：picotool 烧录+校验、BOOTSEL+UF2（cp -X）、USB CDC banner/心跳、GP25 500 ms 翻转、**板载 LED 目视确认闪烁** |
| 文档 | `README.md` + **`PIN_GUIDE.md`（40-pin 全部引脚 + 复用矩阵）** + `RP2040_PICO全外设学习项目方案.md` |

```bash
cd /Users/theo-richard/workspace/projects/pico/rp2040/pico-blink
make && make size

# 烧录 A：BOOTSEL 拖拽 build/pico-blink.uf2
# 烧录 B：picotool
/Users/theo-richard/workspace/toolchains/pico-sdk-tools/picotool/picotool \
  load -f -x build/pico-blink.uf2

# 烧录 C：OpenOCD + CMSIS-DAP / Picoprobe
/Users/theo-richard/workspace/toolchains/openocd/bin/openocd \
  -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
  -c "program build/pico-blink.elf verify reset exit"
```

> Pico 工程与 STM32/ESP32/STC32G 不同：**SDK 不复制进工程**，启动代码、boot2、
> 链接脚本由 CMake 按 `PICO_BOARD` 自动选择。板型变体（Pico W / Pico 2 / Pico 2 W）
> 与 LED 差异见 `projects/pico/README.md` 第 6 节和 `PIN_GUIDE.md` 第 10 节。

---

## 5. 编译命令

### 5.1 STM32 三个工程

```bash
# F103
cd /Users/theo-richard/workspace/projects/stm32/f1xx/stm32f103-blink
make                    # 产出 build/stm32f103-blink.{elf,hex,bin}
make size               # 查看 Flash/RAM 占用
make dis                # 反汇编 → build/stm32f103-blink.dis
make symbols            # 符号表 → build/stm32f103-blink.sym
make clean              # 清理

# F407
cd /Users/theo-richard/workspace/projects/stm32/f4xx/stm32f407-blink
make && make size

# H743
cd /Users/theo-richard/workspace/projects/stm32/h7xx/stm32h743-blink
make && make size
```

**编译产物路径**：
- `build/<工程名>.elf` — 可调试
- `build/<工程名>.hex` — Intel HEX
- `build/<工程名>.bin` — 原始二进制（烧录用）
- `build/<工程名>.map` — 链接映射

**一键编译全部 STM32：**
```bash
cd /Users/theo-richard/workspace/projects
for p in projects/stm32/f1xx/stm32f103-blink \
         projects/stm32/f4xx/stm32f407-blink \
         projects/stm32/h7xx/stm32h743-blink; do
  ( cd "$p" && make -s clean && make -s && make -s size )
done
```

### 5.2 STC32G 工程

```bash
cd /Users/theo-richard/workspace/projects/stc32/stc32g144k246-blink
make                    # sdcc 编译 + 汇编 + 链接 + 生成 ihx/hex/bin
make size               # 从 .mem 看 ROM 占用与初始栈顶
make dis                # 列出 .lst 汇编列表
make symbols            # map 符号地址
make verify             # 16 项静态自检
make clean
```

**编译产物**：
- `build/stc32g144k246-blink.ihx` — SDCC 链接输出（Intel HEX）
- `build/stc32g144k246-blink.hex` — packihx 规范化后的 HEX（烧录用）
- `build/stc32g144k246-blink.bin` — sdobjcopy 转出的原始二进制
- `build/stc32g144k246-blink.map/.mem/.lst` — 映射/内存/汇编列表

### 5.3 ESP32 两个工程

```bash
# C3
cd /Users/theo-richard/workspace/projects/esp32/esp32c3-blink
make                    # 编译 + 打包 + 29 项静态自检
make verify             # 只跑自检
make size
make dis
make symbols
make clean

# S3
cd /Users/theo-richard/workspace/projects/esp32/esp32s3-blink
make                    # 编译 + 打包 + 38 项静态自检
make verify
make size
make dis
```

**编译产物路径**：
- `build/<工程名>.elf` — 可调试
- `build/<工程名>.bin` — 原始二进制（从 `_start` 起）
- `build/<工程名>.esp.bin` — **ESP 官方镜像格式**，含 header + SHA256，可直接烧录
- `build/<工程名>.map` — 链接映射

### 5.4 Pico 工程

```bash
cd /Users/theo-richard/workspace/projects/pico/rp2040/pico-blink

make                    # CMake 配置 + 编译（等价 make build）
make configure          # 只跑 CMake 配置
make size               # arm-none-eabi-size 查看 Flash/RAM
make clean              # 删除 build/
make PICO_BOARD=pico2   # 切到 RP2350（Pico 2）
```

**编译产物路径**：
- `build/pico-blink.uf2` — BOOTSEL 拖拽烧录
- `build/pico-blink.elf` — OpenOCD 烧录 / 调试
- `build/pico-blink.bin` — 原始二进制
- `build/pico-blink.hex` — Intel HEX
- `build/pico-blink.map` — 链接映射

> Pico 的 `make` 内部调用 `toolchains/cmake/bin/cmake`，SDK 路径默认
> `libraries/pico/pico-sdk`；可在命令行覆盖 `PICO_SDK_PATH` / `PICO_TOOLCHAIN_PATH`。

### 5.5 一键重建全部工程

```bash
cd /Users/theo-richard/workspace
./scripts/build_all.sh          # 清理重建 7 工程（ESP32/STC32G 自动跑自检）
./scripts/build_all.sh -q       # 安静模式，只显示每个工程的最终结果
```

等价的手工循环：

```bash
cd /Users/theo-richard/workspace/projects
for p in projects/stm32/f1xx/stm32f103-blink \
         projects/stm32/f4xx/stm32f407-blink \
         projects/stm32/h7xx/stm32h743-blink \
         projects/esp32/esp32c3-blink \
         projects/esp32/esp32s3-blink \
         projects/stc32/stc32g144k246-blink \
         projects/pico/rp2040/pico-blink; do
  echo "===== $p ====="
  ( cd "$p" && make -s clean && make -s && make -s size )
done
```

每个 ESP32 工程会在 `make` 末尾自动跑自己的 `tools/verify.py`；STC32G 工程用 `make verify`；STM32 工程用第 6.1 节的
`nm`/`xxd` 命令核对向量表和 RTOS 符号；Pico 工程用第 6.6 节的 `picotool`/`objdump` 自检。

---

## 6. 自检命令

### 6.1 STM32 逆向自检

```bash
cd /Users/theo-richard/workspace/projects/stm32/f1xx/stm32f103-blink
TOOL=/Users/theo-richard/workspace/toolchains/arm-none-eabi/bin/arm-none-eabi-

# ① .bin 头 8 字节 = 初始 SP + Reset 向量（Thumb 位）
xxd -l 8 build/stm32f103-blink.bin
# 期望 F103: ff4f0020 ed240008   (SP=0x20004FFF, Reset=0x080024ED)
# 期望 F407: 00000220 e9260008   (SP=0x20020000, Reset=0x080026E9)
# 期望 H743: 00000220 21280008   (SP=0x20020000, Reset=0x08002821)

# ② 向量表：查 RTOS 三入口
$TOOL objdump -s -j .isr_vector build/stm32f103-blink.elf | head -8

# ③ FreeRTOS 符号已链接
$TOOL nm build/stm32f103-blink.elf | grep -Ei 'vPortSVCHandler|xPortPendSVHandler|xPortSysTickHandler|pxCurrentTCB'
# 应看到 4 个 T/B 符号

# ④ 反汇编 RCC/GPIO 写
$TOOL objdump -d build/stm32f103-blink.elf | grep -Ei 'RCC|GPIO' | head -10

# ⑤ FLASH/RAM 占用
$TOOL size build/stm32f103-blink.elf
```

**参考结果**：

| 工程 | text | data | bss |
|---|---|---|---|
| F103 | 9728 | 24 | 10232 |
| F407 | 11032 | 24 | 35320 |
| H743 | 10532 | 28 | 35324 |

### 6.2 ESP32 镜像自检

```bash
cd /Users/theo-richard/workspace/projects/esp32/esp32c3-blink
make verify
# 29 项：入口 0x40380000、16 KB cache 跳过、IRAM/DRAM 别名、.bss/栈、镜像

cd ../esp32s3-blink
make verify
# 38 项：向量表/0x340 跳转、IRAM/DRAM 别名、.bss/栈、初始 PS=0x30、镜像
```

手工检查镜像头：

```bash
python3 - <<'PY'
import hashlib, struct
for p in ("../esp32c3-blink/build/esp32c3-blink.esp.bin",
          "../esp32s3-blink/build/esp32s3-blink.esp.bin"):
    b = open(p, "rb").read()
    print(f"{p}: size={len(b)}B magic=0x{b[0]:02X} segcnt={b[1]} "
          f"mode=0x{b[2]:02X} size_freq=0x{b[3]:02X} "
          f"entry=0x{struct.unpack_from('<I', b, 4)[0]:08X} "
          f"chip_id=0x{struct.unpack_from('<H', b, 12)[0]:04X} "
          f"sha256={'OK' if hashlib.sha256(b[:-32]).digest()==b[-32:] else 'BAD'}")
PY
# 期望 C3: size=6912B  entry=0x40380000 chip_id=0x0005
# 期望 S3: size=10464B entry=0x4037C3D4 chip_id=0x0009
# 两者 mode=0x02 (DIO)、size_freq=0x20 (4 MB / 40 MHz)、sha256=OK
```

### 6.3 ESP32 GPIO 反汇编验证

```bash
# C3（RISC-V）
RISCV=/Users/theo-richard/workspace/toolchains/riscv32-esp-elf/bin/riscv32-esp-elf-
$RISCV objdump -d build/esp32c3-blink.elf | sed -n '/<led_task>:/,/^$/p'
# 期望：lui s0,0x60004；sw s1,36(s0)=0x24（enable_w1ts）/ 12(s0)=0x0C（out_w1tc）/ 8(s0)=0x08（out_w1ts），s1=256（GPIO8）

# S3（Xtensa）
XTEN=/Users/theo-richard/workspace/toolchains/xtensa-esp-elf/bin/xtensa-esp-elf-
$XTEN objdump -d build/esp32s3-blink.elf | sed -n '/<led_task>:/,/^$/p'
# 期望：s32i 写偏移 48(0x30)（enable1_w1ts）/ 24(0x18)（out1_w1tc）/ 20(0x14)（out1_w1ts），立即数 0x10000（GPIO48 bit16）
```

### 6.4 自包含性验证（ESP32 工程不依赖外部 IDF）

```bash
IDF="/Users/theo-richard/workspace/libraries/esp32/esp-idf"
mv "$IDF" "${IDF}.tmp_renamed"
for chip in c3 s3; do
  cd "/Users/theo-richard/workspace/projects/esp32/esp32$chip-blink"
  make -s clean && make -s && echo "esp32$chip-blink ✅"
done
mv "${IDF}.tmp_renamed" "$IDF"
```

### 6.5 STC32G 固件自检

```bash
cd /Users/theo-richard/workspace/projects/stc32/stc32g144k246-blink
make verify
```

`tools/verify.py` 解析 `build/*.ihx` / `*.map` / `*.mem`，检查 16 项：

| 类别 | 检查 |
|---|---|
| 地址 | IHX 全部 ≥ 0xFF0000、最高地址 ≤ 0xFFFFFF |
| 复位 | FF:0000 是 `LJMP`；FF:0003 是 `EJMP 0xFF00xx`；目标在 0xFF0000..0xFF00FF |
| 符号 | `s_HOME == 0xFF0000`；`_main/_delay_ms` 存在 |
| 大小 | ROM 起始 0xFF0000、占用 255B（≤246KB）；`.bin` 与 ROM 等长 |
| 初始化 | `main.lst` 含 `WTST/CKCON/P0M0/P4M0` 写入 |

当前输出：`ROM/EPROM/FLASH 0xff0000 0xff00fe 255`，`ALL CHECKS PASSED`。

### 6.6 Pico 固件自检

```bash
cd /Users/theo-richard/workspace/projects/pico/rp2040/pico-blink
TOOL=/Users/theo-richard/workspace/toolchains/arm-none-eabi/bin/arm-none-eabi-
PICOTOOL=/Users/theo-richard/workspace/toolchains/pico-sdk-tools/picotool/picotool

# ① UF2 头：magic 0x0A324655 / 0x9E5D5157 / 0x0AB16F30
xxd -l 32 build/pico-blink.uf2
# 期望前 4 字节：55 46 32 0a（"UF2\n"）

# ② 段地址：.boot2 在 0x10000000，.text 紧随其后（通常 0x10000100）
$TOOL objdump -h build/pico-blink.elf | grep -E 'boot2|\.text|\.rodata|\.data|\.bss'

# ③ 初始 SP / Reset 向量：.bin 偏移 0x100 起是向量表
xxd -s 0x100 -l 8 build/pico-blink.bin
# 期望：SP=0x20042000，Reset=0x100001xx（Thumb 位为 1）

# ④ picotool 固件信息（family、程序名、版本、构建时间）
$PICOTOOL info -a build/pico-blink.elf

# ⑤ 体积
$TOOL size build/pico-blink.elf
```

> 具体数值以当前构建为准；`picotool info` 会打印 `family ID`（RP2040）和
> `build date`。若 UF2 magic 不对，说明文件不是 UF2 或已损坏；若 `.boot2` 不在
> `0x10000000`，链接脚本/板型选择有问题。

---

## 7. 固件烧录

> **OpenOCD、picotool 与 stcgal 已安装在 `toolchains/`**，完整用法见 `toolchains/FLASHING.md`。
> `esptool` / `st-flash` 未安装；ESP32 串口下载需要时再装 esptool。

### 7.1 STM32

```bash
# 方式 A：st-flash（ST-Link）
brew install stlink
cd /Users/theo-richard/workspace/projects/stm32/f1xx/stm32f103-blink
st-flash write build/stm32f103-blink.bin 0x08000000

# 方式 B：OpenOCD（已装在本工作区）
cd /Users/theo-richard/workspace/projects/stm32/f1xx/stm32f103-blink
/Users/theo-richard/workspace/toolchains/openocd/bin/openocd \
  -f interface/stlink.cfg -f target/stm32f1x.cfg \
  -c "program build/stm32f103-blink.elf verify reset exit"

# F407 用 target/stm32f4x.cfg，H743 用 target/stm32h7x.cfg
# 详细说明：toolchains/FLASHING.md
```

### 7.2 ESP32

> ESP32 普通串口下载用 esptool；JTAG 烧录用已安装的 OpenOCD（见 `toolchains/FLASHING.md`）。

```bash
# 安装 esptool（仅此一项，不装 IDF 全家桶）
pip3 install esptool

# C3
cd /Users/theo-richard/workspace/projects/esp32/esp32c3-blink
esptool.py --chip esp32c3 -p /dev/tty.usbmodem* \
  write_flash 0x0 build/esp32c3-blink.esp.bin

# S3
cd /Users/theo-richard/workspace/projects/esp32/esp32s3-blink
esptool.py --chip esp32s3 -p /dev/tty.usbmodem* \
  write_flash 0x0 build/esp32s3-blink.esp.bin
```

> 必须烧到 **0x0**（ROM 直接启动）。镜像里没有 ESP-IDF 的 app descriptor，
> 放到 0x10000 的 app 分区会被 IDF 二级 bootloader 拒绝。
>
> S3 启动后 UART0（GPIO43，115200）应输出：
>
> ```
> ESP32-S3 bare-metal FreeRTOS SMP
> [core0] running, core id = 0
> [core1] running, core id = 1
> [core0] tick 1
> [core1] tick 1
> ...
> ```
>
> C3 没有接 UART 输出，验证看 GPIO8 LED（500 ms 翻转）。

> 端口号用 `ls /dev/tty.usb*` 查。C3/S3 进下载模式：按住 BOOT 再按 RESET。

### 7.3 STC32G144K246

> **OpenOCD 不支持 STC**（没有 STC target/flash 驱动）；STC 走 UART/USB ISP，
> 不是 JTAG/SWD。不要浪费时间找 `target/stc32g.cfg`，不存在。

**方式 A：官方 AiCube-ISP（Windows / Wine / 虚拟机，最稳）**

1. 打开 AiCube-ISP / STC-ISP，选芯片 `STC32G144K246`；
2. 选 `build/stc32g144k246-blink.hex`；
3. 选 USB 或串口下载口，点下载，再给 MCU 冷启动上电。

**方式 B：USB 直接下载**

- P3.0 = D−、P3.1 = D+（各串 22Ω）；
- **按住 P3.2 再上电**，进入 USB 等待下载模式；
- 电脑端 ISP 工具点下载。

**方式 C：macOS / 跨平台**

```bash
# stcgal 已装在本工作区（1.10）
/Users/theo-richard/workspace/toolchains/stcgal/bin/stcgal -h
# 注意：协议列表没有 stc32/251，STC32G144K246 不能用 stcgal
/Users/theo-richard/workspace/toolchains/stcgal/bin/stcgal \
  -p /dev/cu.wchusbserial* -P stc8g path/to/stc8g-firmware.hex
```

> **STC32G144K246 是 251 内核，stcgal 1.10 不支持**（协议只有 stc89/12/15/8/8D/8G/usb15）。
> 该芯片请用 AiCube-ISP（Windows/Wine/虚拟机）。stcgal 只适用于 STC8/15/89 等 51 系列。
> 详细说明：`toolchains/FLASHING.md`。

### 7.4 Pico（RP2040）

```bash
cd /Users/theo-richard/workspace/projects/pico/rp2040/pico-blink

# 方式 A：BOOTSEL + UF2 拖拽（无需调试器）
# 按住 BOOTSEL 插 USB，出现 RPI-RP2 后：
cp -X build/pico-blink.uf2 /Volumes/RPI-RP2/

# 方式 B：picotool（板子需在 BOOTSEL 模式）
/Users/theo-richard/workspace/toolchains/pico-sdk-tools/picotool/picotool \
  load -f -x build/pico-blink.uf2
/Users/theo-richard/workspace/toolchains/pico-sdk-tools/picotool/picotool \
  verify build/pico-blink.uf2

# 方式 C：OpenOCD + CMSIS-DAP / Picoprobe
/Users/theo-richard/workspace/toolchains/openocd/bin/openocd \
  -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
  -c "program build/pico-blink.elf verify reset exit"
```

> Pico 2（RP2350）把 target 换成 `target/rp2350.cfg`，并设置 `PICO_BOARD=pico2`。
> 调试排针为 **SWCLK / GND / SWDIO**，不提供 3.3 V；目标板需自行供电。
> 完整接线、擦除、picotool 选项见 `toolchains/FLASHING.md` 第 4 节。
>
> **实测（2026-11-20）**：RP2040 B2，`make flash-uf2`（`picotool load -f -x`）烧录+校验
> 退出码 0；BOOTSEL + UF2 拷贝（`cp -X`）也可自动重启运行；USB CDC banner
> （125 MHz / GP25 / 500 ms）与 tick/level 心跳正常。本次未单独测试 OpenOCD/SWD。

---

## 8. 维护操作

### 8.1 刷新 ESP32 工程的头文件（IDF 升级后）

`refresh_esp_headers.py` 已移除，按下面的方式手动同步（C3 把 `c3` 换成 `s3`）：

```bash
# 1. 更新 IDF 仓库
cd "/Users/theo-richard/workspace/libraries/esp32/esp-idf"
git pull

# 2. 手动复制工程实际用到的目录
IDF=/Users/theo-richard/workspace/libraries/esp32/esp-idf/components
P=/Users/theo-richard/workspace/projects/esp32/esp32c3-blink/Drivers/idf

rm -rf "$P/soc_c3" "$P/hal_c3" "$P/esp_common" "$P/esp_rom_c3" "$P/esp_hal_uart-c3" "$P/esp_hal_gpio-c3"
cp -R "$IDF/soc/esp32c3"                    "$P/soc_c3"
cp -R "$IDF/hal/esp32c3"                    "$P/hal_c3"
cp -R "$IDF/esp_common/include"             "$P/esp_common/include"
cp -R "$IDF/esp_rom/esp32c3"                "$P/esp_rom_c3"
cp -R "$IDF/esp_hal_uart/include"           "$P/esp_hal_uart-c3/hal"
cp -R "$IDF/esp_hal_gpio/include"           "$P/esp_hal_gpio-c3/hal"

# 3. 重编译验证
cd /Users/theo-richard/workspace/projects/esp32/esp32c3-blink
make -s clean && make -s
```

S3 工程同理，把 `soc_c3` → `soc_s3`、`esp32c3` → `esp32s3`、`esp_rom_c3` → `esp_rom_s3`。

### 8.2 添加新外设（ESP32 示例：I2C）

```bash
# 寄存器结构体已在 Drivers/idf/soc_<chip>/register/soc/ 里
# main.c 直接 include 即可
#include "soc/i2c_struct.h"
#define I2C0 ((volatile i2c_dev_t *)0x60013000UL)
```

如果某个 HAL 头不在工程内（如 `hal/i2c_types.h`），按同样方式补：

```bash
IDF=/Users/theo-richard/workspace/libraries/esp32/esp-idf
P=/Users/theo-richard/workspace/projects/esp32/esp32c3-blink
mkdir -p "$P/Drivers/idf/esp_hal_i2c-c3/hal"
cp "$IDF/components/esp_hal_i2c/include/hal/"*.h "$P/Drivers/idf/esp_hal_i2c-c3/hal/"
# Makefile 里加：-IDrivers/idf/esp_hal_i2c-c3
```

### 8.3 新增芯片（以 ESP32-C6 为例）

1. 稀疏克隆补 IDF 组件：
   ```bash
   cd /Users/theo-richard/workspace/libraries/esp32/esp-idf
   git sparse-checkout add components/soc/esp32c6 components/hal/esp32c6
   ```
2. 复制工程骨架：`cp -R projects/esp32/esp32c3-blink projects/esp32/esp32c6-blink`
3. 改 Makefile 的芯片名、`CPU`（`-march=rv32imac_zicsr_zifencei`）、`ld/esp32c6.ld` 内存地址
4. 改 `startup/startup_c6.S`、`main/main.c` 的 LED 引脚
5. 按 8.1 节手动复制 `Drivers/idf/` 头文件（`refresh_esp_headers.py` 已移除）

### 8.4 更新工具链

```bash
# ARM
# 从 ARM 官网下载 arm-gnu-toolchain-<ver>-darwin-arm64.tar.xz，解压替换 toolchains/arm-none-eabi/

# Xtensa / RISC-V
VER=esp-14.2.0_20241119
BASE=https://github.com/espressif/crosstool-NG/releases/download/$VER
cd /Users/theo-richard/workspace/toolchains
# 备份旧版
mv xtensa-esp-elf xtensa-esp-elf.bak
mv riscv32-esp-elf  riscv32-esp-elf.bak
# 下新版（替换为实际文件名）
curl -L "$BASE/xtensa-esp-elf-$VER-aarch64-apple-darwin.tar.xz" | tar -xJ -C xtensa-esp-elf --strip-components=1
curl -L "$BASE/riscv32-esp-elf-$VER-aarch64-apple-darwin.tar.xz" | tar -xJ -C riscv32-esp-elf --strip-components=1
# 验证
xtensa-esp-elf/bin/xtensa-esp-elf-gcc --version | head -1
riscv32-esp-elf/bin/riscv32-esp-elf-gcc --version | head -1
```

---

## 9. 故障排查

### 9.1 STM32 常见错误

| 报错 | 原因 | 解决 |
|---|---|---|
| `undefined reference to vAssertCalled` | `configASSERT` 调了外部函数 | 改为 `do { if((x)==0){for(;;){}} } while(0)`（已改） |
| `undefined reference to vApplicationStackOverflowHook` | `configCHECK_FOR_STACK_OVERFLOW > 0` | 置 0 + `main.c` 加空实现兜底（已改） |
| `undefined reference to vApplicationMallocFailedHook` | `configUSE_MALLOC_FAILED_HOOK=1` | 置 0（已改） |
| `configCPU_CLOCK_HZ` 语法错 | 正则只替换了 `(` | 整行替换成常数（已改） |
| `_close/_lseek/_read/_write not implemented` | newlib-nano 无 syscall 实现 | **无害警告**，忽略 |
| `LOAD segment with RWX permissions` | ld 新版对段权限的提示 | **无害警告**，忽略 |
| `HAL_xxx_MODULE_ENABLED` 未定义 | `hal_conf.h` 未开模块 | 在 `Core/Inc/stm32*xx_hal_conf.h` 取消注释 |

### 9.2 ESP32 常见错误

| 报错 | 原因 | 解决 |
|---|---|---|
| `soc/gpio_struct.h: No such file` | Makefile `-I` 未指到 `register/soc/` | 确认 `-IDrivers/idf/soc_c3/register` |
| `request for member 'val' in something not union` | S3 的 `out_w1ts` 是 `uint32_t`，不是 union | S3 用 `out1_w1ts.val`；C3 用 `out_w1ts.val` |
| `left shift count >= width` | `1U << 48` 对 32 位越界 | GPIO48 用 bank1，`1U << (48-32)` |
| `l32r: literal placed after use` | Xtensa 字面量池必须在代码前 | ① Makefile 加 `-mtext-section-literals`；② ld 里 `.literal*` 放 `.text` 最前面 |
| `mkimage.py AssertionError` | ELF 头 `EI_DATA` 是大端标记 | 已改 mkimage 自适应，镜像仍按小端打包 |
| `unrecognized option '-mtext-section-literals'` | RISC-V 不支持 Xtensa 专用选项 | C3 Makefile 去掉该选项（已改） |
| `Makefile:xx: missing separator` | 脚本插了空行，破坏了 `\` 续行 | 用 `re.sub` 整段重写 CFLAGS |
| `hal/xxx_types.h: No such file` | IDF v6 拆到 `esp_hal_xxx` 组件 | `git sparse-checkout add components/esp_hal_xxx` 后复制进工程 |
| 编译/链接都过，上板一清零 bss 就飞 | S3/C3 的 IRAM 与 DRAM 是同一物理 SRAM 的两个总线视图 | 链接脚本用 `.dram_skip` 跳过整个 IRAM 镜像的别名区再放 `.bss` |
| C3 上板不执行 | 代码被放在 0x4037C000，那是 16 KB 指令 cache | C3 代码必须从 0x40380000 开始（`ld/esp32c3.ld` 已改） |
| S3 第一次 `rfe` 就异常 | 初始任务 PS 缺 PS_UM/PS_EXCM | `pxPortInitialiseStack` 写 0x30 |
| S3 tick 到了但不切换任务 | ISR 退出只重载当前 TCB，没调 `vTaskSwitchContext` | `_xt_lowint1` 保存 SP 后调用切换 |
| S3 双核启动卡死 | core1 未就绪就开始 core0 首任务 / boot addr 顺序错 | `xCore1Ready` 握手 + 先设 boot addr 再释放复位 |

### 9.3 自包含失败（IDF 改名后编译挂）

```bash
# 看编译输出里缺哪个头
make 2>&1 | grep 'No such file' 

# 常见：缺 esp_hal_xxx 组件的 HAL 头
IDF=/Users/theo-richard/workspace/libraries/esp32/esp-idf
git -C "$IDF" sparse-checkout add components/esp_hal_i2c   # 换成缺的组件名
# 然后复制进工程
```

### 9.4 STC32G 常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| `Syntax error at 'sfr'` | 官方头文件是 Keil C251 语法 | 用 `Drivers/STC32G/Inc/stc32g144k246_regs.h`（SDCC `__sfr __at`） |
| `__has_builtin redefined` / `__STDC_HOSTED__ redefined` | sdcc-c251 自带预处理器与系统头冲突 | 无害警告，忽略 |
| `makebin: size of the buffer is too small` | 代码定位在 0xFF0000，makebin 不支持高地址 | 用 `sdobjcopy -I ihex -O binary`（Makefile 已改） |
| 上板 LED 不闪 | I/O 默认高阻 / LED 电源脚未使能 / 主频与 `MAIN_Fosc` 不符 | 查 `LED_Init()` 的 PnM0/PnM1、P4.1、`MAIN_Fosc` |
| 大数组/递归跑飞 | sdcc 默认 8 位栈，只有约 120B | 大变量放 `__xdata`；或改启动代码把 SP 指到 edata 顶部 |

### 9.5 Pico 常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| 编译报 `PICO_DEFAULT_LED_PIN` 未定义 | 选了 Pico W | 改用 CYW43 LED API，或 `PICO_BOARD=pico` |
| `make` 找不到 SDK/CMake | 工作区路径被移动 | 核对 `libraries/pico/pico-sdk`、`toolchains/cmake/bin/cmake` |
| 首次构建很慢 | SDK 要从源码构建 `pioasm` | 正常现象，后续增量很快 |
| `picotool load` 找不到设备 | 板子不在 BOOTSEL | 按住 BOOTSEL 再插 USB；换数据线 |
| OpenOCD `target not examined` | SWDIO/SWCLK 接反/目标未供电 | 用万用表确认 GND，检查 3-pin 线序 |
| USB 串口无输出 | 枚举未完成/充电线 | 等 1.5 s；换数据线；或看 UART0 GP0/GP1 |
| 链接提示 RWX segment | Pico SDK 链接脚本已知现象 | 裸机工程可忽略 |
| `size` 的 text 远大于 `.bin` | `.data` 带 AX 标志被计入 text | 以 `.bin` 大小为准 |

---

## 10. 脚本清单

顶层脚本与各工程自带工具：

| 脚本 | 位置 | 用途 |
|---|---|---|
| `build_all.sh` | `scripts/` | 一键清理重建 7 工程（`-q` 安静模式），任一失败即停 |
| `tools/mkimage.py` | `projects/esp32/esp32c3-blink/` | ELF → ESP 官方镜像（chip_id 0x0005，SHA256） |
| `tools/verify.py` | `projects/esp32/esp32c3-blink/` | 29 项 C3 布局/镜像自检 |
| `tools/mkimage.py` | `projects/esp32/esp32s3-blink/` | ELF → ESP 官方镜像（chip_id 0x0009，SHA256） |
| `tools/verify.py` | `projects/esp32/esp32s3-blink/` | 38 项 S3 向量/布局/镜像自检 |
| `tools/verify.py` | `projects/stc32/stc32g144k246-blink/` | 16 项 STC32G 地址/复位/符号/ROM 自检 |

STM32 三个工程没有额外脚本，直接使用 Makefile 的 `size` / `dis` / `symbols` 目标。

每个工程（含 f411 模板）均有 `README.md`（芯片配置、构建/自检、烧录、扩展
指南）与 `PIN_GUIDE.md`（引脚详解）；各目录配 `.gitignore`（忽略 `build/`
与 `.DS_Store`）。

### 常用命令速查

```bash
# 全部重新编译（含 ESP32 自检）
cd /Users/theo-richard/workspace/projects
for p in projects/stm32/f1xx/stm32f103-blink \
         projects/stm32/f4xx/stm32f407-blink \
         projects/stm32/h7xx/stm32h743-blink \
         projects/esp32/esp32c3-blink \
         projects/esp32/esp32s3-blink \
         projects/stc32/stc32g144k246-blink \
         projects/pico/rp2040/pico-blink; do
  ( cd "$p" && make -s clean && make -s && make -s size ) || break
done

# 单个工程
cd <工程目录> && make -s clean && make -s size

# ESP32 只跑自检
cd <工程目录> && make verify
```

---

## 11. 快速参考表

### 11.1 工程路径

| 工程 | 路径 |
|---|---|
| stm32f103-blink | `projects/stm32/f1xx/stm32f103-blink/` |
| stm32f407-blink | `projects/stm32/f4xx/stm32f407-blink/` |
| stm32h743-blink | `projects/stm32/h7xx/stm32h743-blink/` |
| esp32c3-blink | `projects/esp32/esp32c3-blink/` |
| esp32s3-blink | `projects/esp32/esp32s3-blink/` |
| stc32g144k246-blink | `projects/stc32/stc32g144k246-blink/` |
| pico-blink | `projects/pico/rp2040/pico-blink/` |
| 原 f411 模板 | `projects/stm32/f4xx/stm32f411-blink/` |

### 11.2 工具链前缀

| 工具链 | 前缀 | 路径 |
|---|---|---|
| ARM | `arm-none-eabi-` | `toolchains/arm-none-eabi/bin/` |
| Xtensa | `xtensa-esp-elf-` | `toolchains/xtensa-esp-elf/bin/` |
| RISC-V | `riscv32-esp-elf-` | `toolchains/riscv32-esp-elf/bin/` |
| SDCC MCS-251 | `sdcc` / `sdas251` / `sdobjcopy` | `toolchains/sdcc-c251/bin/` |
| CMake | `cmake` | `toolchains/cmake/bin/` |
| Pico 工具 | `picotool` / `pioasm` | `toolchains/pico-sdk-tools/{picotool,pioasm}/` |

### 11.3 内核与编译选项

| 芯片 | `-mcpu` / `-march` | `-mfpu` / `-mabi` | `-D` 宏 |
|---|---|---|---|
| F103 | `-mcpu=cortex-m3` | — | `-DUSE_HAL_DRIVER -DSTM32F103xB` |
| F407 | `-mcpu=cortex-m4` | `-mfpu=fpv4-sp-d16 -mfloat-abi=hard` | `-DUSE_HAL_DRIVER -DSTM32F407xx` |
| H743 | `-mcpu=cortex-m7` | `-mfpu=fpv5-d16 -mfloat-abi=hard` | `-DUSE_HAL_DRIVER -DSTM32H743xx` |
| C3 | `-march=rv32imc_zicsr_zifencei -mabi=ilp32 -mcmodel=medany` | — | — |
| S3 | `-mlongcalls -mabi=call0 -mtext-section-literals` | — | — |
| STC32G | `-mmcs251 --model-small --code-loc 0xFF0000 --iram-size 0x4000` | — | — |
| RP2040 | `-mcpu=cortex-m0plus -mthumb` | — | `PICO_BOARD=pico`（SDK 传入） |

### 11.4 内存布局

| 芯片 | Flash | RAM | 链接脚本 |
|---|---|---|---|
| F103C8 | 64K @ 0x08000000 | 20K @ 0x20000000 | `STM32F103XB_FLASH.ld` |
| F407VG | 1024K @ 0x08000000 | 128K @ 0x20000000 + 64K CCM @ 0x10000000 | `STM32F407VGTx_FLASH.ld` |
| H743ZI | 2048K @ 0x08000000 | 128K DTCM @ 0x20000000 + 512K AXI @ 0x24000000 | `STM32H743ZITx_FLASH.ld` |
| ESP32-C3 | 外部 Flash（裸机不走缓存映射） | IRAM 0x40380000..0x403CE710（0x4037C000 起 16KB 是 I-cache）/ DRAM 0x3FC80000..0x3FCCE710；别名偏移 0x700000 | `ld/esp32c3.ld` |
| ESP32-S3 | 同上 | IRAM 0x4037C000..0x403C0000 / DRAM 0x3FC88000..0x3FCD0000；别名偏移 0x6F0000；栈 0x3FCC9000..0x3FCCD000 | `ld/esp32s3.ld` |
| STC32G144K246 | 246K @ 0xFF0000（复位入口 FF:0000） | 16K edata + 128K xdata + 4K 可执行 RAM | sdcc `--code-loc/--iram-size`（无独立 ld） |
| RP2040（Pico） | 2 MB QSPI XIP @ 0x10000000 | 264 KB @ 0x20000000（4×64K + 2×4K） | SDK 按 `PICO_BOARD` 自动生成（boot2 + memmap） |

### 11.5 编译产物

| 工程 | elf | hex | bin | esp.bin | uf2 |
|---|---|---|---|---|---|
| STM32 | ✅ | ✅ | ✅ | — | — |
| ESP32 | ✅ | — | ✅（原始） | ✅（官方镜像 + SHA256） | — |
| STC32G | —（sdcc 输出 `.ihx`） | ✅ | ✅ | — | — |
| Pico | ✅ | ✅ | ✅ | — | ✅（BOOTSEL） |

### 11.6 镜像格式（ESP32）

```
+--------+--------+--------+--------+---------+---------+--------+
| 0xE9   | segcnt | 0x02   | 0x20   | entry(4) | ...     | hash   |
+--------+--------+--------+--------+---------+---------+--------+
                                       ↑
                         chip_id(2B) @ offset 12
                         wp_pin=0xEE @ offset 8
                         hash_appended @ offset 23
```

- `magic` = 0xE9
- `segcnt` = PT_LOAD 段数
- `spi_mode` = 0x02（DIO）；`spi_size/speed` = 0x20（4 MB / 40 MHz）
- `wp_pin` = 0xEE（无写保护引脚）
- `entry` = `_start` 绝对地址（从 `nm` 取）
- `chip_id`：C3 = 0x0005，S3 = 0x0009
- 每段：`addr(4) + len(4) + data`
- 尾部：16 字节对齐 + SHA256(32)

> 这三个头字段（mode/size/wp_pin）是 ROM 直接启动时初始化 flash 用的；全 0 表示
> QIO + 1 MB，部分 flash 会读不出来。

---

## 12. 变更日志

| 日期 | 变更 |
|---|---|
| 2026-11 | 初始化：5 工程（F103/F407/H743 + C3/S3）+ 3 工具链 + 全自包含结构 |
| 2026-11 | 修复 FreeRTOSConfig 断言/钩子/堆/时钟宏 |
| 2026-11 | 修复 Xtensa `l32r` 字面量池顺序 + mkimage ELF 端序 |
| 2026-11 | ESP32 工程 `Drivers/idf/` 补全 soc/hal/esp_common/esp_rom/esp_hal_* |
| 2026-11 | 自包含验证：IDF 目录改名后两 ESP32 工程仍编译通过 |
| 2026-11 | C3 接入 FreeRTOS 单核：SYSTIMER target0 1 kHz tick + `freertos_risc_v_trap_handler` |
| 2026-11 | S3 接入 FreeRTOS SMP：S32C1I 自旋锁、FROM_CPU IPI、每核 CCOMPARE0 tick、core1 启动握手 |
| 2026-11 | **修复 S3 IRAM/DRAM 别名重叠**（原布局清 bss 会擦代码）；**修复 C3 代码落在 16 KB I-cache 区**；修正 S3 初始 PS、ISR 退出切换、`xPortInIsrContext`、IPI 向量 |
| 2026-11 | 两 ESP32 工程新增 `make verify`（C3 29 项 / S3 38 项）；S3 增加 UART0 双核心跳 demo |
| 2026-11 | 镜像头补 DIO/40 MHz/4 MB 与 wp_pin=0xEE |
| 2026-11-16 | **全量自检**：3 工具链版本验证、5 工程 `make clean && make` 全通过（尺寸与第 6.1 节参考值一致）、C3 `make verify` 29 项 / S3 38 项全通过、bin 头 8 字节 / 镜像头 / GPIO 反汇编与文档吻合、IDF 改名自包含复测通过 |
| 2026-11-16 | **补充**：f103/f407/h743/c3 四工程新增 `README.md`；顶层新增 `build_all.sh`；各工程与顶层新增 `.gitignore`；清理全部 `.DS_Store` |
| 2026-11-17 | **新增 STC32G144K246-blink**：sdcc-c251 工具链、官方 88 例程包/头文件、SDCC 兼容寄存器层、16 项 `make verify`、`PIN_GUIDE.md`（LQFP100 100 脚 + 706 条复用功能）；一键构建扩为 6 工程 |
| 2026-11-20 | **新增 Pico/RP2040 工程**：CMake 3.31.6 + Pico SDK 2.3.1 + picotool/pioasm 2.3.1（均为 macOS arm64）；`pico-blink`（GP25 500 ms、USB CDC + UART0 stdio、UF2/ELF/BIN/HEX）；新增 `PIN_GUIDE.md` 与 12 阶段学习方案；一键构建扩为 7 工程 |

---

## 13. 参考链接

- ST 设备包：[github.com/STMicroelectronics](https://github.com/STMicroelectronics)
- FreeRTOS-Kernel：[github.com/FreeRTOS/FreeRTOS-Kernel](https://github.com/FreeRTOS/FreeRTOS-Kernel)
- ESP-IDF：[github.com/espressif/esp-idf](https://github.com/espressif/esp-idf)
- Espressif 工具链：[github.com/espressif/crosstool-NG/releases](https://github.com/espressif/crosstool-NG/releases)
- ARM GNU Toolchain：[developer.arm.com/downloads/-/arm-gnu-toolchain-downloads](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)
- SDCC MCS-251 分支：[github.com/zevorn/sdcc-c251](https://github.com/zevorn/sdcc-c251)
- STC 官方资料/例程：[www.stcaimcu.com](https://www.stcaimcu.com)
- esptool：[github.com/espressif/esptool](https://github.com/espressif/esptool)
- Pico SDK：[github.com/raspberrypi/pico-sdk](https://github.com/raspberrypi/pico-sdk)
- Pico C SDK 文档：[raspberrypi.com/documentation/microcontrollers/c_sdk.html](https://www.raspberrypi.com/documentation/microcontrollers/c_sdk.html)
- RP2040 数据手册：[datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf](https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf)