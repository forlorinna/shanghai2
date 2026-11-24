# 魔都：自由都市 · Shanghai Open World

V0.1.0 · Godot 4.7.2 · 离线单机 · 简体中文 / English

从陆家嘴出发，可以徒步或开车游览黄浦江两岸。经过延安东路隧道的地面入口时互动，即可驶入依据 OpenStreetMap 线路重建的地下车道。金陵东路渡口与东昌路渡口之间有轮渡。自由探索模式关闭通缉，任何模式都可以跳过任务。

## 交付文件

- [Android APK](builds/android/Shanghai-OpenWorld-v0.1.0-arm64.apk)及 [SHA256](builds/android/SHA256SUMS)
- [Web 静态文件](builds/Shanghai-OpenWorld-v0.1.0-web.zip)
- [Godot 工程、地图源数据与生成工具](builds/Shanghai-OpenWorld-v0.1.0-source.zip)
- [开发进度](PROGRESS.md) · [测试报告](TEST_REPORT.md) · [素材与许可证](LICENSES.md) · [签名证书保存](docs/SIGNING.md)

## 开始游玩

通过 Android 的本地安装流程安装 ARM64 APK。应用名称为「魔都：自由都市」。最低 Android 7.0，目标 Android 16。地图随 APK 提供。存档、设置和照片写入应用沙箱。

开始后，首辆轿车停在玩家附近。触屏左侧移动，右侧拖动镜头，移动和动作键可同时使用。驾驶有独立的转向、油门、刹车和手刹键。减速后可以下车，刹车键在车停后可以继续倒车。右上角打开地图、手机或暂停。

| 键盘 / 鼠标 | 操作 |
| --- | --- |
| WASD / 方向键 | 移动、转向、油门与刹车 |
| 鼠标 / 滚轮 | 旋转镜头 / 调整镜头距离 |
| Shift / Alt / Ctrl | 冲刺 / 慢走 / 下蹲 |
| Space | 跳跃，驾驶时为手刹 |
| F / E | 上下车 / 互动 |
| V / H / Z / X | 切换视角 / 喇叭 / 左转灯 / 右转灯 |
| M / Tab / Esc | 地图 / 手机 / 暂停 |
| F9 / F3 | 保存照片 / 性能遥测 |

在地图点选地标或自定义位置可导航和传送。暂停菜单可手动存档，游戏每 35 秒运行时间自动存档。手机可以接任务、召唤车辆、换色、换装、解锁公寓和拍照。暂停菜单的沙盒页提供时间天气、交通密度、无限资源及摄影选项。

Web 压缩包可部署到静态 HTTPS 目录。可在项目根目录运行以下命令进行本地预览。首次访问需要加载站点资源。HTTPS 或本机回环地址下，浏览器完成 Service Worker 缓存后可以断网重开。同源存档依赖浏览器存储。

    python3 -m http.server --bind 127.0.0.1 --directory builds/web 8000

## 在工程中构建

Linux x86_64 工作站可运行以下脚本。工具装入工程内，已提供生成好的地图与游戏资源。

    tools/setup_toolchain.sh
    tools/godot.sh --editor
    tools/test_game.sh
    tools/build_android.sh
    tools/build_web.sh

地图重建使用 tools/rebuild_map.sh。默认使用 maps/source/shanghai.osm，加 --fetch 时重新下载同一范围。工具链需要 Godot 4.7.2、Python 3、Pillow 和 Shapely。签名按项目文档管理。

地图数据 © OpenStreetMap contributors，ODbL 1.0。[OpenStreetMap 版权与许可](https://www.openstreetmap.org/copyright)
