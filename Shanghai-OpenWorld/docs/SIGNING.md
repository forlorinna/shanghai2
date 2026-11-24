# Android 签名的安全保存

- 应用 ID 为 com.shanghai.openworld。版本名为 0.1.0，versionCode 为 1。
- 项目专用 RSA 3072 私钥保存在 tools/signing/shanghai-release.p12。密码位于同目录的 password 文件。目录权限为 0700，各文件权限为 0600。
- 更换构建机器前，将私钥容器和密码分别保存到受控的加密备份中。遗失任意一项将影响同签名就地升级。
- 公共证书是 tools/signing/public-certificate.pem，可用于检查发行包。公开副本随 APK 放在 builds/android/。
- 源码 ZIP、Web ZIP 和 Git 忽略规则排除私钥及密码。构建脚本在本地读取密码并传入 Godot。
- 后续版本沿用应用 ID 和同一签名证书，递增 export_presets.cfg 的 version/code，并同步版本名和输出名。

    tools/build_android.sh
    python3 tools/verify_apk.py
    cd builds/android && sha256sum -c SHA256SUMS

覆盖安装使用同一签名时可保留 Android 应用专属存档。卸载会移除应用专属目录。
