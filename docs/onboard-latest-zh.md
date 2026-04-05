---
title: Latest Onboard Guide (ZH)
layout: default
nav_exclude: true
description: PiTrac 最新版软硬件中文线性 onboard 指导
last_modified_date: 2026-04-04
---

# PiTrac 最新版软硬件 Onboard 线性指导

这份文档给第一次搭 PiTrac 的人一条当前仓库里最顺的主线，不走旧 V1/V2 旧双 Pi 路线，不把过期 quickstart 和新硬件文档混着用。

## 先说结论

当前建议直接按这套组合上手：

- 外壳：V3 Enclosure
- 计算：1 x Raspberry Pi 5，8GB 优先
- 相机：2 x Innomaker IMX296 Mono
- 镜头：2 x 6mm M12
- 板卡：V3 Connector Board + IRLED2
- 电源：Meanwell LRS-75-5
- 模式：Single Pi
- 软件安装方式：`packaging/build.sh dev`

软件层面当前仓库已经同时照顾了 Bookworm 和 Trixie，但因为 `docs/quickstart.md` 还是旧口径，首台 onboard 建议优先用 Raspberry Pi OS 64-bit Bookworm；如果你已经在 Trixie 上，当前 `packaging/` 也有对应支持，不必因为 quickstart 退回旧版本。

## 你现在该买什么

先按 [parts-list.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/hardware/parts-list.md) 下单，主件不要偏离下面这套：

- 1 x Raspberry Pi 5 8GB
- 1 x Pi 5 Active Cooler
- 1 x 64GB+ MicroSD
- 2 x Innomaker GS Camera Module with IMX296 Mono Sensor
- 2 x Pi 5 22-pin to 15-pin camera cable
- 2 x 6mm 3MP M12 lens
- 1 x 1" IR-pass filter
- 1 x USB COB LED strip
- 1 x Meanwell LRS-75-5
- 1 x AC Power Inlet C14 with fuse
- V3 Connector Board 全部 BOM
- IRLED2 BOM

如果你还没订板，直接按 [pcb-assembly.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/hardware/pcb-assembly.md) 的 V3 路线：

- 订 `V3 Connector Only` 或 `V3 Connector + IRLED2`
- V3 Connector 不建议让板厂代焊，自己焊
- IRLED2 可以代焊，通常更省事

## 你该打印什么

不要再打印 V1/V2 主体件，直接按 [V3 Enclosure/3D-printing.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/hardware/V3%20Enclosure/3D-printing.md) 的 `R1` 主件清单打。

最少要有这些：

- `EyeScreen` x3
- `5x2IRLED_Eyeball` x1
- `Stack_Module_PSU_vent` x1
- `Pi5_Carrier_vertical_3mm` x1
- `IMX296-MPI_Eyeball_6mm_camfered` x2
- `Carrier_Clamps` x4
- `ConnectorBoardv3_Carrier` x1
- `Foot` x4
- `LinePower_Cover` x1
- `Stack_Module` x3
- `EyeScreen_Clamp` x3
- `Ambient_LED_Screen` x1
- `Spacer` x16
- `Stack_Module_Cover_forInserts` x1
- `Stack_Module_Cover_insert` x1
- `Stack_Module_Cover_LogoTee` x1
- `Stack_Module_Cover_LogoBall` x1
- `Ambient_LED_Visor` x1

额外必须补：

- `IRFilter_Mount_1inchround` x1
- `Calibration Rig` x1

材料上优先 PETG 或阻燃材料，PLA 只算能用，不算推荐。`LinePower_Cover.stl` 必装，这不是装饰件。

## 线性装配顺序

### 1. 先做板卡，不要先封箱

按 [pcb-assembly.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/hardware/pcb-assembly.md) 焊好：

- V3 Connector Board
- IRLED2

通电前先做三件事：

- 万用表确认 5V 和 GND 没短路
- 核对所有二极管、电解、电源接口方向
- 核对 IRLED 极性

### 2. 做三个头部组件

按 [V3 Enclosure/Assembly.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/hardware/V3%20Enclosure/Assembly.md) 先完成：

- Tee camera assembly
- Flight camera assembly
- LED assembly

这里有两个关键点：

- 两个相机都优先用 `IMX296-MPI_Eyeball_6mm_camfered`
- 只有 flight cam 要加 IR-pass filter

### 3. 做 PSU 模块

按 V3 装配文档把下面装进 `Stack_Module_PSU_vent`：

- Meanwell LRS-75-5
- C14 进电口
- USB COB LED strip
- `LinePower_Cover`
- `Ambient_LED_Visor`

这一步结束时先不要急着完全封死，后面还要复查接线。

### 4. 做三个 stack module

按 V3 装配文档依次组：

- Camera Stack Module 1
- LED Stack Module
- Camera Stack Module 2

相机模组装到 `Stack_Module` 时，先把前平面距离控制在 30 mm 左右，先接近设计参考，不要指望后面校准替你救大偏差。

### 5. 组整体堆栈

按 V3 文档的堆叠顺序装：

1. PSU stack
2. 下方 camera stack
3. LED stack
4. 上方 camera stack

推荐先用短 M5 螺丝把模块固定起来，等整机跑通后再决定是不是切 M5 长杆做最终装配。

### 6. 装 Pi5 和 V3 Connector

先把 Pi5 和 V3 Connector 分别固定到各自 carrier，再滑入机身。

接线时按 [pcb-assembly.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/hardware/pcb-assembly.md) 里的 Raspberry Pi 5 对照表，不要自己猜：

- V3 Connector `GND` -> Pi `Pin 39`
- `DIAG` -> `Pin 19`
- `CS0` -> `Pin 12`
- `MOSI` -> `Pin 38`
- `MISO` -> `Pin 35`
- `CLK` -> `Pin 40`
- `CS1` -> `Pin 11`
- `V3P3` -> `Pin 1`
- Flight cam `Trig+` -> `Pin 22`
- Flight cam `Trig-` -> `Pin 20`

同时接好：

- 两根相机 ribbon cable
- Pi5 的 USB-C 供电
- V3 Connector 到 IRLED2 的 `VIR+ / VIR-`
- USB COB LED strip

### 7. 在盖后盖之前先做一次台架通电

这一步必须在所有部件还容易摸到的时候做。

检查顺序：

1. 目检所有线序和极性
2. 确认没有任何线被压住
3. 上电，看 Pi5 能否正常启动
4. 看相机 ribbon 是否识别
5. 看 LED strip 是否正常

如果这一步没过，不要继续装背板和外壳盖。

## 软件 onboard 顺序

### 8. 装系统

按 [install-os.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/software/pi-setup/install-os.md) 走，但第一次主线建议这样选：

- Raspberry Pi OS 64-bit
- 首选 Bookworm
- Desktop 或 Lite 都行，第一次更推荐 Desktop
- 开 SSH
- 配好 Wi-Fi 或直接上有线

### 9. 首次登录后先升级

按 [first-login.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/software/pi-setup/first-login.md)：

```bash
sudo apt update
sudo apt -y upgrade
sudo reboot now
```

重连后确认：

```bash
cat /etc/os-release
uname -m
```

你要看到 64-bit，`aarch64`。

### 10. 装 PiTrac

按 [build-from-source.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/software/install/build-from-source.md)：

```bash
git clone https://github.com/PiTracLM/PiTrac.git
cd PiTrac/packaging
sudo ./build.sh dev
```

如果构建时提示缺失大文件，先跑：

```bash
git lfs install
git lfs pull
```

然后再执行 `sudo ./build.sh dev`。

### 11. 安装后不要照抄旧 quickstart 改 boot config

当前仓库里这块有历史口径不一致：

- 旧 quickstart 和部分 troubleshooting 还在写 `camera_auto_detect=1`
- 当前安装脚本会补 `dtoverlay=spi1-2cs`
- 当前安装脚本也会管理 `force_turbo=1` 和 `arm_boost=1`
- `packaging/scripts/configure-cameras.sh` 里默认是手动控制思路

实际 onboard 时，优先以安装脚本跑完后的结果为准。也就是说：

- 先装完 PiTrac
- 先看系统当前 `/boot/firmware/config.txt`
- 不要在没理解现状时把旧文档里的 `camera_auto_detect=1` 机械抄回去

### 12. 基础验收

先跑这几个真实检查：

```bash
pitrac status
rpicam-hello --list-cameras
```

你要看到：

- `activemq` 正常
- `pitrac-web` 正常
- 两个相机都能列出来

如果 web 没起来：

```bash
pitrac web start
pitrac web status
```

## Web UI 首次配置顺序

### 13. 先打开界面

浏览器访问：

```text
http://<pi-ip>:8080
```

### 14. 先配最少必要项

按 [using-pitrac.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/software/using-pitrac.md) 先只改这些：

- Camera 1 Type
- Camera 2 Type
- Lens Choice = `6mm M12`
- System Mode = `Single Pi`
- Connector Board Version = `V3`

相机类型优先让 UI 的 `Auto Detect` 识别；不对就手选 Innomaker。

### 15. 先做 strobe / current 相关校准

V3 Connector 板在正式打球前要先把板卡相关校准跑通，再去看击球结果；否则能亮不代表电流控制和触发时序已经对。

### 16. 再做相机校准

按 [cameras.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/camera/cameras.md) 和 UI 向导走，顺序固定：

1. 先 Camera 1
2. 再 Camera 2

每一步都先做：

- Check Ball Location
- Capture Still Image

确认球真的在画面里，再开 calibration。

## 第一球前的最终验收

到这一步你应该已经满足：

- 机器已经完整装好，但还没把问题封进壳里
- 两个相机都能枚举
- Web UI 可访问
- Single Pi 模式已配置
- Camera type 和 lens 已配置
- V3 board 已选对
- Camera 1 / Camera 2 校准已完成
- 静态抓图能看到球

然后再打第一球。

## 真正卡住时先看哪几份

- 硬件主线：[V3 Enclosure.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/hardware/V3%20Enclosure.md)
- 打印：[V3 Enclosure/3D-printing.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/hardware/V3%20Enclosure/3D-printing.md)
- 装配：[V3 Enclosure/Assembly.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/hardware/V3%20Enclosure/Assembly.md)
- 板卡：[pcb-assembly.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/hardware/pcb-assembly.md)
- 采购：[parts-list.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/hardware/parts-list.md)
- 软件安装：[build-from-source.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/software/install/build-from-source.md)
- 首次使用：[using-pitrac.md](/Users/moonz/Repos/Walky/golf-stuff/PiTrac/docs/software/using-pitrac.md)

## 这份指导解决了哪些旧冲突

- 硬件主线不再用 V1/V2 文档当主装配路径，统一切到 V3
- 计算主线不再用双 Pi，统一切到单 Pi 5
- 软件安装不再以旧 quickstart 为准，而以 `docs/software/*` 和当前 `packaging/*` 能力为准
- OS 口径统一为：Bookworm/Trixie 都支持，但首台主线优先 Bookworm
- boot config 口径统一为：优先看安装脚本最终写入结果，不机械照抄旧文档
