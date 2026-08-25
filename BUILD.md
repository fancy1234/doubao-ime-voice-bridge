# 构建说明

## 环境

- Windows 10/11 x64
- AutoHotkey v2
- Ahk2Exe

本项目当前使用 AutoHotkey v2.0.26 和 Ahk2Exe v1.1.37.02a2 构建。

## 源码自检

```powershell
& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" `
  ".\DoubaoVoiceIMEBridge.ahk" --self-test

& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" `
  ".\DoubaoVoiceIMEBridge.ahk" --install-test

& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" `
  ".\DoubaoVoiceIMEBridge.ahk" --smoke-test
```

输出应分别包含：

```text
SELF_TEST_OK
INSTALL_TEST_OK|<豆包输入法安装路径>
SMOKE_TEST_OK
```

`--install-test` 需要测试电脑已安装豆包输入法。

## 编译

```powershell
& ".\Compiler\Ahk2Exe.exe" `
  /in ".\DoubaoVoiceIMEBridge.ahk" `
  /out ".\DoubaoVoiceIMEBridge.exe" `
  /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" `
  /silent verbose
```

建议从 AutoHotkey 官方发布渠道取得运行时和 Ahk2Exe。发布前应重新运行全部自检，并为 EXE 和 ZIP 生成 SHA-256。

## 发布文件

```text
DoubaoVoiceIMEBridge-vX.Y.Z.exe
DoubaoVoiceIMEBridge-vX.Y.Z.zip
SHA256SUMS.txt
```

不要在仓库源码分支里提交临时配置、编译缓存或个人日志；二进制文件放入 GitHub Release。

