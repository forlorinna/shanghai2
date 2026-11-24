# V0.1.0 测试报告

验证日期 2026-11-24。环境为 Debian 13 x86_64、AMD EPYC 9V74 虚拟机 3 个逻辑核心、9.7 GiB 内存，工作盘起始可用约 7.5 GiB。当前有 Godot 4.7.2 stable、Python 3.12.14、Blender 4.3.2、Temurin JDK 17.0.17+10、Android API 36 SDK、Build Tools 36.0.0。桌面图形验证使用 Mesa llvmpipe。Web 验证使用 Chromium 和 SwiftShader。

## 已通过

| 范围 | 验证方法与结果 |
| --- | --- |
| 启动与界面 | Godot 无头场景和桌面图形启动。主菜单、地图、游戏 HUD 和手机渲染成功。 |
| 人物与相机 | 实际输入驱动步行、跳跃、骨骼姿势、第一人称开关和主角可见性。物理测试验证角色站在分块碰撞面。 |
| 车辆 | 上下车、在上海道路上加速和移动、手刹、轮与路面状态通过；测试驾驶员按真实油门和物理移动，从隧道西口驶到东口。 |
| 跨江与室内 | 驶过实体延安东路隧道、搭乘东金线从金陵东路到东昌路并下船、进入和退出咖啡馆、用游戏币解锁并进入城市公寓。 |
| 分块、GPS、行人和车流 | 路线使用有向 OSM 道路网，跨街区移动挂载和卸载分块，对岸正常碰撞，附近行人与 AI 车流正常实例化。 |
| 昼夜、天气、任务与通缉 | 夜间和降雨状态、降雨粒子开关、通缉等级与关闭、任务检查点和结算通过。地标、地图、白天和夜景有桌面渲染样本。 |
| 输入与震动开关 | 合成的两指输入同时按住摇杆与冲刺，震动开关的代码路径可关闭调用。 |
| 存档 | 版本化本地存档、破损主档回退到备份、继续游戏恢复虚拟货币通过。 |
| 无头稳定性 | 37 项冒烟断言通过。另完成 36,000 个物理模拟 tick，相当于 10 分钟游戏模拟；24 次跨街区跳转，遍历全部七种天气。常驻分块峰值 40，Godot 静态内存从预热后 92.49 MiB 到峰值 94.92 MiB。 |
| Web | 静态目录通过 Chromium 启动 WASM 和 WebGL 2.0，菜单进入 3D 场景，接收键盘输入。首次缓存完成后模拟浏览器断网，同一站点可以重载进入游戏。 |
| APK 完整性 | apksigner v2/v3 签名通过；aapt 能解析包名、版本、清单和权限；zipalign 检查通过，ZIP CRC 通过。两份原生 ELF 均为 ARM64 并通过 16 KiB 对齐检查。140 个城区分块、远景、地图和许可均在 APK 中。 |
| Android 配置 | 包名 com.shanghai.openworld，versionCode 1，版本 0.1.0，minSdk 24，targetSdk 36，横屏 userLandscape，应用名「魔都：自由都市」。唯一应用权限为 android.permission.VIBRATE。 |

APK SHA256 位于 [SHA256SUMS](builds/android/SHA256SUMS)。官方工具提取结果在 builds/android/ 的 badging.txt、manifest.txt 和 zipalign.txt 中。

## 待验证

- Android 16 真机安装、启动、图形驱动兼容、背景恢复、全面屏安全区、真实多点触控、蓝牙手柄、倾斜输入和振动强度。构建环境没有可用的 ADB 连接设备，且 ADB 本地服务无法在只读用户目录创建配置。
- 骁龙 8s Gen 4 及其他设备的 30–60 FPS 目标、真机长时间稳定性、热管理与系统低内存。引擎无头静态内存统计不包含移动 GPU 显存，不能作为手机性能结论。
- 两岸反向隧道、更多汽车转弯、所有任务分支、雨天高强度渲染、长时间浏览器存档、全面的地标碰撞和相机边界为后续测试项。
- Vulkan Mobile 渲染的设备兼容和性能。交付包采用 Compatibility。

## 重跑

    tools/test_game.sh
    tools/test_game.sh --soak
    python3 tools/verify_apk.py
    node tests/web_smoke.cjs

Web 测试需要 Chromium 和 Playwright。无头模拟使用隔离的临时存档。桌面截图的 V-Sync 由软件驱动限制。
