# workspace — 嵌入式开发工作区

> 单片机/嵌入式学习与开发 monorepo：工具链、官方库、自建工程、参考仓库、知识库分层管理。
> 一键重建全部自建工程：`./scripts/build_all.sh`（7 个工程 + ESP32/STC32G 静态自检）。

## 目录结构

```
workspace/
├── toolchains/        # 编译工具链 + 烧录工具（各工程 Makefile 以绝对路径引用，勿随意改名）
│   ├── arm-none-eabi/     # Arm GNU Toolchain 15.3.1（STM32 / Pico）
│   ├── xtensa-esp-elf/    # crosstool-NG esp-14.2.0_20241119（ESP32-S3）
│   ├── riscv32-esp-elf/   # crosstool-NG esp-14.2.0_20241119（ESP32-C3）
│   ├── sdcc-c251/         # SDCC MCS-251 分支（STC32G，源码编译安装，见 libraries/stc/README.md）
│   ├── cmake/             # CMake 3.31.6（Pico 工程构建）
│   ├── pico-sdk-tools/    # pioasm / picotool 2.3.1（RP2040/RP2350）
│   ├── openocd/           # OpenOCD v0.12.0-esp32（STM32/ESP32/RP2040 JTAG/SWD 烧录调试）
│   ├── stcgal/            # stcgal 1.10（STC 串口 ISP，独立 venv）
│   └── FLASHING.md        # 各烧录工具的详细用法
│
├── libraries/         # 官方/第三方库源码（只读参考；STM32 等用工程内副本，Pico 通过 PICO_SDK_PATH 共享引用）
│   ├── stm32/             # ST 官方 HAL + CMSIS 设备包（F1/F4/F411/H7）
│   ├── esp32/esp-idf/     # ESP-IDF 稀疏克隆（头文件来源）
│   ├── freertos/          # FreeRTOS-Kernel 上游
│   ├── display/oledlib/   # OLED 显示库（Keil 工程）
│   ├── pico/              # Pico SDK 2.3.1（RP2040/RP2350，含 TinyUSB/lwIP/mbedTLS/BTstack）
│   └── stc/               # STC 官方库（STC32G144K246，见其 README.md）
│
├── projects/          # 自建工程（可独立构建、全中文注释；Pico 工程共享 SDK）
│   ├── README.md          # 7 工程总文档（编译/自检/烧录/故障排查）
│   ├── stm32/             # f1xx / f4xx / h7xx（FreeRTOS blink 系列）
│   ├── esp32/             # esp32c3-blink / esp32s3-blink（自定义 FreeRTOS port）
│   ├── pico/              # rp2040/pico-blink（Pico SDK + CMake，板载 LED）
│   └── stc32/             # stc32g144k246-blink（SDCC MCS-251 + 官方例程/引脚指南）
│
├── references/        # 学习用完整上游仓库（只读；路线图见 references/README.md）
│   ├── rtos/              # FreeRTOS / Zephyr / NuttX / ThreadX / RIOT
│   ├── filesystems/       # littlefs / FlashDB / SFUD / EasyFlash
│   ├── graphics/          # LVGL / u8g2
│   ├── firmware/          # OV-Watch、micropython、flipperzero-firmware 等实战项目
│   └── datasheets/        # 芯片引脚/器件资料（如 STC32G12K128 LQFP64）
│
├── docs/              # 文档
│   └── knowledge-base/    # 源码精读知识库（入口：INDEX.md）
│
├── scripts/           # 工作区级脚本
│   └── build_all.sh       # 一键清理重建全部自建工程
│
└── .qa/               # 文档质检管线（mermaid 渲染截图、审计脚本，可整体忽略）
```

## 常用命令

```bash
# 一键重建 7 个自建工程（任一失败即停）
./scripts/build_all.sh        # 加 -q 只看结果

# 单独编译某个工程
cd projects/stm32/f1xx/stm32f103-blink && make

# Pico 工程（CMake + Makefile 薄封装）
cd projects/pico/rp2040/pico-blink && make && make size
# 烧录：BOOTSEL 拖 build/pico-blink.uf2，或
# toolchains/pico-sdk-tools/picotool/picotool load -f build/pico-blink.uf2
# 调试器：toolchains/openocd/bin/openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
#         -c "program build/pico-blink.elf verify reset exit"

# 工具链版本自检
toolchains/arm-none-eabi/bin/arm-none-eabi-gcc --version | head -1
toolchains/xtensa-esp-elf/bin/xtensa-esp-elf-gcc --version | head -1
toolchains/riscv32-esp-elf/bin/riscv32-esp-elf-gcc --version | head -1
toolchains/sdcc-c251/bin/sdcc --version | head -1
toolchains/cmake/bin/cmake --version | head -1
toolchains/pico-sdk-tools/picotool/picotool version

# STC32G 工程
cd projects/stc32/stc32g144k246-blink && make && make verify

# 烧录工具版本
toolchains/openocd/bin/openocd --version
toolchains/stcgal/bin/stcgal --version
```

## 约定

- **新增工程**放进 `projects/<芯片族>/<系列>/`，自带构建入口 + `README.md` + `.gitignore`，编译产物只进 `build/`。
  STM32/ESP32/STC 用 `Makefile`；**Pico 工程以 `CMakeLists.txt` 为主，根目录 `Makefile` 只是 CMake 薄封装**。
- **新增库**放进 `libraries/<芯片族>/`，保持上游目录名；`libraries/stc/` 的放置规范见其中 README。
- **烧录工具**统一放 `toolchains/`，用法见 `toolchains/FLASHING.md`；不要依赖全局 `openocd`/`stcgal`。
- **参考仓库**只进 `references/`，不参与一键构建。
- **路径引用**：工程 Makefile 用绝对路径指向 `toolchains/`；文档间引用一律用相对路径。
- `.env` 存敏感 token（勿提交、勿外发）；`.qa/` 是文档质检产物，不与工程混放。
