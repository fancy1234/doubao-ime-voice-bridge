#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent

;@Ahk2Exe-SetName Doubao Voice IME Bridge
;@Ahk2Exe-SetProductName Doubao Voice IME Bridge
;@Ahk2Exe-SetDescription Use Doubao IME voice input while keeping another IME as default
;@Ahk2Exe-SetVersion 0.1.0.0
;@Ahk2Exe-SetOrigFilename DoubaoVoiceIMEBridge.exe

if A_Args.Length && A_Args[1] = "--self-test"
{
    FileAppend("SELF_TEST_OK`n", "*")
    ExitApp 0
}

if A_Args.Length && A_Args[1] = "--install-test"
{
    if DoubaoIme.IsInstalled(true)
    {
        FileAppend("INSTALL_TEST_OK|" DoubaoIme.InstallPath "`n", "*")
        ExitApp 0
    }
    FileAppend("INSTALL_TEST_NOT_FOUND`n", "*")
    ExitApp 3
}

if A_Args.Length && A_Args[1] = "--smoke-test"
{
    AppConfig.Init()
    if !HotkeyController.Register("F12", "toggle")
    {
        FileAppend("SMOKE_TEST_HOTKEY_FAILED`n", "*")
        ExitApp 2
    }
    HotkeyController.Unregister()
    SettingsWindow.Create()
    SettingsWindow.GuiObj.Destroy()
    FileAppend("SMOKE_TEST_OK`n", "*")
    ExitApp 0
}

if A_Args.Length && A_Args[1] = "--ui-preview"
{
    AppConfig.Init()
    SettingsWindow.Show()
    FileAppend("UI_PREVIEW_READY`n", "*")
    SetTimer(ExitApp, -15000)
    return
}

; 豆包输入法语音桥
; Version: 0.1.0-beta
; 核心对象是豆包输入法的 ImeService.exe，而不是豆包 Windows 客户端。

class AppConfig
{
    static Dir := A_AppData "\DoubaoVoiceIMEBridge"
    static Path := this.Dir "\config.ini"
    static Values := Map()
    static Defaults := Map(
        "TriggerKey", "MButton",
        "Mode", "toggle",
        "CorrectionDelay", 1000,
        "SwitchSettleDelay", 400,
        "MaxSwitchSteps", 6,
        "AutoStart", 0,
        "ShowTrayTips", 1,
        "MonitorVoiceWindow", 1
    )

    static Init()
    {
        for key, value in this.Defaults
            this.Values[key] := value

        existed := FileExist(this.Path) ? true : false
        if existed
            this.Load()
        return existed
    }

    static Load()
    {
        try
        {
            this.Values["TriggerKey"] := IniRead(this.Path, "General", "TriggerKey", this.Defaults["TriggerKey"])
            this.Values["Mode"] := IniRead(this.Path, "General", "Mode", this.Defaults["Mode"])
            this.Values["CorrectionDelay"] := Integer(IniRead(this.Path, "General", "CorrectionDelay", this.Defaults["CorrectionDelay"]))
            this.Values["SwitchSettleDelay"] := Integer(IniRead(this.Path, "Advanced", "SwitchSettleDelay", this.Defaults["SwitchSettleDelay"]))
            this.Values["MaxSwitchSteps"] := Integer(IniRead(this.Path, "Advanced", "MaxSwitchSteps", this.Defaults["MaxSwitchSteps"]))
            this.Values["AutoStart"] := Integer(IniRead(this.Path, "General", "AutoStart", this.Defaults["AutoStart"]))
            this.Values["ShowTrayTips"] := Integer(IniRead(this.Path, "General", "ShowTrayTips", this.Defaults["ShowTrayTips"]))
            this.Values["MonitorVoiceWindow"] := Integer(IniRead(this.Path, "Advanced", "MonitorVoiceWindow", this.Defaults["MonitorVoiceWindow"]))
        }
        catch
        {
            ; 保留已加载的默认值。
        }

        if this.Values["Mode"] != "toggle" && this.Values["Mode"] != "hold"
            this.Values["Mode"] := "toggle"
        this.Values["CorrectionDelay"] := Max(0, Min(5000, this.Values["CorrectionDelay"]))
        this.Values["SwitchSettleDelay"] := Max(100, Min(1500, this.Values["SwitchSettleDelay"]))
        this.Values["MaxSwitchSteps"] := Max(2, Min(12, this.Values["MaxSwitchSteps"]))
    }

    static Save()
    {
        if !DirExist(this.Dir)
            DirCreate(this.Dir)

        IniWrite(this.Get("TriggerKey"), this.Path, "General", "TriggerKey")
        IniWrite(this.Get("Mode"), this.Path, "General", "Mode")
        IniWrite(this.Get("CorrectionDelay"), this.Path, "General", "CorrectionDelay")
        IniWrite(this.Get("AutoStart"), this.Path, "General", "AutoStart")
        IniWrite(this.Get("ShowTrayTips"), this.Path, "General", "ShowTrayTips")
        IniWrite(this.Get("SwitchSettleDelay"), this.Path, "Advanced", "SwitchSettleDelay")
        IniWrite(this.Get("MaxSwitchSteps"), this.Path, "Advanced", "MaxSwitchSteps")
        IniWrite(this.Get("MonitorVoiceWindow"), this.Path, "Advanced", "MonitorVoiceWindow")
    }

    static Get(key)
    {
        return this.Values.Has(key) ? this.Values[key] : ""
    }

    static Set(key, value)
    {
        this.Values[key] := value
    }

    static StartupLink()
    {
        return A_Startup "\豆包输入法语音桥.lnk"
    }

    static SetAutoStart(enable)
    {
        link := this.StartupLink()
        try
        {
            if enable
            {
                if A_IsCompiled
                    FileCreateShortcut(A_ScriptFullPath, link, A_ScriptDir)
                else
                    FileCreateShortcut(A_AhkPath, link, A_ScriptDir, '"' A_ScriptFullPath '"')
            }
            else if FileExist(link)
                FileDelete(link)
            return true
        }
        catch
        {
            return false
        }
    }

    static IsAutoStartEnabled()
    {
        return FileExist(this.StartupLink()) ? true : false
    }
}

class DoubaoIme
{
    static InstallPath := ""

    static IsInstalled(refresh := false)
    {
        if !refresh && this.InstallPath != ""
            return true

        paths := [A_ProgramFiles "\DoubaoIME"]
        programFilesX86 := EnvGet("ProgramFiles(x86)")
        if programFilesX86 != ""
            paths.Push(programFilesX86 "\DoubaoIME")
        localAppData := EnvGet("LOCALAPPDATA")
        if localAppData != ""
        {
            paths.Push(localAppData "\Programs\DoubaoIME")
            paths.Push(localAppData "\DoubaoIME")
        }

        for path in paths
        {
            if FileExist(path "\ImeService.exe")
            {
                this.InstallPath := path
                return true
            }
        }

        roots := [
            "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        ]

        for root in roots
        {
            try
            {
                Loop Reg, root, "K"
                {
                    key := root "\" A_LoopRegName
                    displayName := ""
                    try displayName := RegRead(key, "DisplayName", "")
                    if !InStr(displayName, "豆包输入法") && !InStr(displayName, "DoubaoIME")
                        continue

                    location := ""
                    try location := RegRead(key, "InstallLocation", "")
                    this.InstallPath := location != "" ? RTrim(location, "\/ ") : "系统安装记录"
                    return true
                }
            }
        }
        return false
    }

    static FindStatusBar()
    {
        for hwnd in WinGetList("ahk_class OimeDirectUIWindow")
        {
            if !DllCall("IsWindowVisible", "Ptr", hwnd, "Int")
                continue

            try WinGetPos(,, &width, &height, "ahk_id " hwnd)
            catch
                continue

            if width >= 140 && height >= 40
                return hwnd
        }
        return 0
    }

    static WaitForStatusBar(timeoutMs)
    {
        deadline := A_TickCount + timeoutMs
        while A_TickCount < deadline
        {
            if this.FindStatusBar()
                return true
            Sleep 30
        }
        return false
    }

    static StartVoice()
    {
        hwnd := this.FindStatusBar()
        if !hwnd
            return false

        ; 豆包默认状态栏皮肤的麦克风按钮客户区坐标。
        voiceButton := 55 | (19 << 16)
        DllCall("PostMessageW", "Ptr", hwnd, "UInt", 0x0201, "UPtr", 1, "Ptr", voiceButton)
        Sleep 30
        DllCall("PostMessageW", "Ptr", hwnd, "UInt", 0x0202, "UPtr", 0, "Ptr", voiceButton)
        return true
    }

    static IsVoiceVisible()
    {
        for hwnd in WinGetList("ahk_class OimeVoiceWaveWindow")
        {
            if DllCall("IsWindowVisible", "Ptr", hwnd, "Int")
                return true
        }
        return false
    }

    static StopVoice()
    {
        found := false
        Loop 24
        {
            visibleNow := false
            for hwnd in WinGetList("ahk_class OimeVoiceWaveWindow")
            {
                if !DllCall("IsWindowVisible", "Ptr", hwnd, "Int")
                    continue
                visibleNow := true
                found := true
                DllCall("PostMessageW", "Ptr", hwnd, "UInt", 0x0010, "UPtr", 0, "Ptr", 0)
            }

            if found && !visibleNow
                return true
            if !found && A_Index >= 12
                return false
            Sleep 50
        }
        return !this.IsVoiceVisible()
    }

    static ServiceRunning()
    {
        return ProcessExist("ImeService.exe") ? true : false
    }
}

class InputMethodSwitcher
{
    static StepsToRestore := 0

    static PrepareDoubao()
    {
        this.StepsToRestore := 0
        if DoubaoIme.FindStatusBar()
            return true

        maxSteps := AppConfig.Get("MaxSwitchSteps")
        Loop maxSteps
        {
            this.Cycle(false)
            this.StepsToRestore += 1

            ; 第一次激活豆包时服务可能需要一两秒才创建状态栏。
            if DoubaoIme.WaitForStatusBar(1800)
            {
                Sleep AppConfig.Get("SwitchSettleDelay")
                if DoubaoIme.FindStatusBar()
                    return true
            }
        }

        this.RestoreOriginal()
        return false
    }

    static RestoreOriginal()
    {
        steps := this.StepsToRestore
        this.StepsToRestore := 0
        Loop steps
        {
            this.Cycle(true)
            Sleep 180
        }
    }

    static Cycle(reverse)
    {
        static VK_LSHIFT := 0xA0
        static VK_LWIN := 0x5B
        static VK_SPACE := 0x20
        static KEYEVENTF_KEYUP := 0x0002

        if reverse
            DllCall("keybd_event", "UChar", VK_LSHIFT, "UChar", 0, "UInt", 0, "UPtr", 0)

        DllCall("keybd_event", "UChar", VK_LWIN, "UChar", 0, "UInt", 0, "UPtr", 0)
        DllCall("keybd_event", "UChar", VK_SPACE, "UChar", 0, "UInt", 0, "UPtr", 0)
        DllCall("keybd_event", "UChar", VK_SPACE, "UChar", 0, "UInt", KEYEVENTF_KEYUP, "UPtr", 0)
        DllCall("keybd_event", "UChar", VK_LWIN, "UChar", 0, "UInt", KEYEVENTF_KEYUP, "UPtr", 0)

        if reverse
            DllCall("keybd_event", "UChar", VK_LSHIFT, "UChar", 0, "UInt", KEYEVENTF_KEYUP, "UPtr", 0)
    }
}

class HotkeyController
{
    static TriggerKey := ""
    static Mode := "toggle"
    static DownSpec := ""
    static UpSpec := ""
    static IsPhysicallyDown := false

    static Register(key, mode)
    {
        oldKey := this.TriggerKey
        oldMode := this.Mode
        this.Unregister()

        try
        {
            this.TriggerKey := key
            this.Mode := mode
            this.DownSpec := "$*" key
            this.UpSpec := "$*" key " Up"
            Hotkey(this.DownSpec, (*) => this.OnDown(), "On")
            Hotkey(this.UpSpec, (*) => this.OnUp(), "On")
            this.IsPhysicallyDown := false
            return true
        }
        catch
        {
            this.TriggerKey := ""
            this.DownSpec := ""
            this.UpSpec := ""
            if oldKey != ""
                this.Register(oldKey, oldMode)
            return false
        }
    }

    static Unregister()
    {
        if this.DownSpec != ""
        {
            try Hotkey(this.DownSpec, "Off")
            try Hotkey(this.UpSpec, "Off")
        }
        this.DownSpec := ""
        this.UpSpec := ""
        this.IsPhysicallyDown := false
    }

    static OnDown()
    {
        if this.IsPhysicallyDown
            return
        this.IsPhysicallyDown := true
        VoiceController.TriggerDown()
    }

    static OnUp()
    {
        if !this.IsPhysicallyDown
            return
        this.IsPhysicallyDown := false
        if this.Mode = "hold"
            VoiceController.TriggerUp()
    }

    static IsMouseTrigger()
    {
        return this.TriggerKey = "MButton" || this.TriggerKey = "XButton1" || this.TriggerKey = "XButton2"
    }

    static ReleaseLogicalMouse()
    {
        if this.IsMouseTrigger()
        {
            try SendEvent "{" this.TriggerKey " up}"
            Sleep 30
        }
    }
}

class VoiceController
{
    static State := "idle"
    static StartedAt := 0
    static VoiceWindowSeen := false
    static MonitorTimer := 0

    static TriggerDown()
    {
        if !BridgeApp.Enabled
            return

        if HotkeyController.Mode = "toggle"
        {
            if this.State = "idle"
                this.Start()
            else if this.State = "starting" || this.State = "listening"
                this.End("user")
        }
        else if this.State = "idle"
            this.Start()
    }

    static TriggerUp()
    {
        if HotkeyController.Mode = "hold" && (this.State = "starting" || this.State = "listening")
            this.End("user")
    }

    static Start()
    {
        if this.State != "idle"
            return

        Critical true
        this.State := "starting"
        BridgeApp.SetStatus("正在切换到豆包输入法…")
        HotkeyController.ReleaseLogicalMouse()

        if !DoubaoIme.IsInstalled()
        {
            this.Fail("没有检测到已安装的豆包输入法")
            Critical false
            return
        }

        if !InputMethodSwitcher.PrepareDoubao()
        {
            this.Fail("无法切换到豆包输入法，请确认豆包状态栏已开启")
            Critical false
            return
        }

        if !DoubaoIme.StartVoice()
        {
            InputMethodSwitcher.RestoreOriginal()
            this.Fail("已切到豆包，但麦克风按钮没有找到")
            Critical false
            return
        }

        this.State := "listening"
        this.StartedAt := A_TickCount
        this.VoiceWindowSeen := false
        BridgeApp.SetStatus("正在听写；再次触发即可结束", true)
        this.StartMonitor()
        Critical false
    }

    static End(reason := "user")
    {
        if this.State = "idle" || this.State = "ending"
            return

        Critical true
        this.State := "ending"
        this.StopMonitor()
        BridgeApp.SetStatus("正在结束并等待豆包校正…")
        DoubaoIme.StopVoice()

        if InputMethodSwitcher.StepsToRestore > 0
            Sleep AppConfig.Get("CorrectionDelay")

        InputMethodSwitcher.RestoreOriginal()
        this.State := "idle"
        this.VoiceWindowSeen := false
        BridgeApp.SetStatus("已就绪")

        if reason = "closed"
            BridgeApp.Notify("语音窗口已关闭，已自动恢复原输入法")
        Critical false
    }

    static Fail(message)
    {
        this.StopMonitor()
        InputMethodSwitcher.RestoreOriginal()
        this.State := "idle"
        this.VoiceWindowSeen := false
        BridgeApp.SetStatus("启动失败")
        BridgeApp.Notify(message, "豆包输入法语音桥")
    }

    static StartMonitor()
    {
        this.StopMonitor()
        if !AppConfig.Get("MonitorVoiceWindow")
            return
        this.MonitorTimer := ObjBindMethod(this, "Monitor")
        SetTimer(this.MonitorTimer, 250)
    }

    static StopMonitor()
    {
        if this.MonitorTimer
        {
            SetTimer(this.MonitorTimer, 0)
            this.MonitorTimer := 0
        }
    }

    static Monitor()
    {
        if this.State != "listening"
        {
            this.StopMonitor()
            return
        }

        if DoubaoIme.IsVoiceVisible()
        {
            this.VoiceWindowSeen := true
            return
        }

        elapsed := A_TickCount - this.StartedAt
        if this.VoiceWindowSeen
            this.End("closed")
        else if elapsed >= 3500
        {
            ; 部分豆包输入法版本不会创建可见的波形窗口。
            ; 此时语音仍可正常工作，静默停止监控，等待用户再次触发结束。
            this.StopMonitor()
        }
    }

    static CleanUp()
    {
        this.StopMonitor()
        if this.State != "idle"
            DoubaoIme.StopVoice()
        InputMethodSwitcher.RestoreOriginal()
        this.State := "idle"
    }
}

class SettingsWindow
{
    static GuiObj := 0
    static KeyList := ["鼠标中键", "鼠标侧键1", "鼠标侧键2", "右 Ctrl", "右 Alt", "F8", "F9", "F10", "F11", "F12"]
    static KeyValues := ["MButton", "XButton1", "XButton2", "RCtrl", "RAlt", "F8", "F9", "F10", "F11", "F12"]
    static KeyDdl := 0
    static ModeDdl := 0
    static DelaySlider := 0
    static DelayText := 0
    static SettleSlider := 0
    static SettleText := 0
    static AutoStartCheck := 0
    static TipsCheck := 0
    static MonitorCheck := 0
    static StatusText := 0

    static Create()
    {
        this.GuiObj := Gui("+AlwaysOnTop -MaximizeBox", "豆包输入法语音桥 - 设置")
        this.GuiObj.SetFont("s10", "Microsoft YaHei UI")
        this.GuiObj.OnEvent("Close", (*) => this.Hide())
        this.GuiObj.OnEvent("Escape", (*) => this.Hide())

        this.GuiObj.AddGroupBox("x12 y10 w416 h150", "语音触发")
        this.GuiObj.AddText("x28 y42 w90", "触发按键：")
        this.KeyDdl := this.GuiObj.AddDropDownList("x120 y38 w190", this.KeyList)
        this.GuiObj.AddText("x28 y82 w90", "工作模式：")
        this.ModeDdl := this.GuiObj.AddDropDownList("x120 y78 w270", ["点按一次开始、再次点按结束", "按住说话、松开结束"])
        this.GuiObj.AddText("x28 y120 w370 c666666", "默认会拦截触发键原有功能，避免中键同时触发网页滚动。")

        this.GuiObj.AddGroupBox("x12 y172 w416 h166", "时间设置")
        this.GuiObj.AddText("x28 y205 w105", "校正等待：")
        this.DelaySlider := this.GuiObj.AddSlider("x132 y200 w205 Range0-5000 Line100 ToolTip", 1000)
        this.DelayText := this.GuiObj.AddText("x345 y205 w65", "1.0 秒")
        this.DelaySlider.OnEvent("Change", (*) => this.RefreshDelayLabels())
        this.GuiObj.AddText("x28 y238 w370 c666666", "结束语音后等待豆包提交最终校正，再恢复搜狗等原输入法。")

        this.GuiObj.AddText("x28 y278 w105", "切换稳定：")
        this.SettleSlider := this.GuiObj.AddSlider("x132 y273 w205 Range100-1500 Line50 ToolTip", 400)
        this.SettleText := this.GuiObj.AddText("x345 y278 w65", "0.4 秒")
        this.SettleSlider.OnEvent("Change", (*) => this.RefreshDelayLabels())
        this.GuiObj.AddText("x28 y311 w370 c666666", "豆包状态栏出现后再等待一小段时间，避免按钮尚未就绪。")

        this.GuiObj.AddGroupBox("x12 y350 w416 h132", "常规")
        this.AutoStartCheck := this.GuiObj.AddCheckbox("x28 y380 w180", "开机自动运行")
        this.TipsCheck := this.GuiObj.AddCheckbox("x220 y380 w180", "显示托盘提示")
        this.MonitorCheck := this.GuiObj.AddCheckbox("x28 y416 w370", "检测到语音窗口后，关闭时自动恢复原输入法")

        this.GuiObj.AddButton("x42 y502 w100 h32 Default", "保存").OnEvent("Click", (*) => this.Save())
        this.GuiObj.AddButton("x170 y502 w100 h32", "环境诊断").OnEvent("Click", (*) => BridgeApp.ShowDiagnostics())
        this.GuiObj.AddButton("x298 y502 w100 h32", "关闭").OnEvent("Click", (*) => this.Hide())
        this.StatusText := this.GuiObj.AddText("x20 y550 w400 Center c228B22", "状态：已就绪")
    }

    static Show()
    {
        if !this.GuiObj
            this.Create()
        this.Load()
        this.GuiObj.Show("w440 h582")
    }

    static Hide()
    {
        if this.GuiObj
            this.GuiObj.Hide()
    }

    static Load()
    {
        key := AppConfig.Get("TriggerKey")
        keyIndex := 1
        for index, value in this.KeyValues
        {
            if value = key
            {
                keyIndex := index
                break
            }
        }
        this.KeyDdl.Choose(keyIndex)
        this.ModeDdl.Choose(AppConfig.Get("Mode") = "hold" ? 2 : 1)
        this.DelaySlider.Value := AppConfig.Get("CorrectionDelay")
        this.SettleSlider.Value := AppConfig.Get("SwitchSettleDelay")
        this.AutoStartCheck.Value := AppConfig.IsAutoStartEnabled()
        this.TipsCheck.Value := AppConfig.Get("ShowTrayTips")
        this.MonitorCheck.Value := AppConfig.Get("MonitorVoiceWindow")
        this.RefreshDelayLabels()
        this.StatusText.Text := "状态：" BridgeApp.StatusText
    }

    static Save()
    {
        keyIndex := this.KeyDdl.Value
        if keyIndex < 1
            keyIndex := 1
        newKey := this.KeyValues[keyIndex]
        newMode := this.ModeDdl.Value = 2 ? "hold" : "toggle"

        if !HotkeyController.Register(newKey, newMode)
        {
            MsgBox("这个按键无法注册，可能已被其他软件占用。", "保存失败", 48)
            return
        }

        AppConfig.Set("TriggerKey", newKey)
        AppConfig.Set("Mode", newMode)
        AppConfig.Set("CorrectionDelay", this.DelaySlider.Value)
        AppConfig.Set("SwitchSettleDelay", this.SettleSlider.Value)
        AppConfig.Set("AutoStart", this.AutoStartCheck.Value)
        AppConfig.Set("ShowTrayTips", this.TipsCheck.Value)
        AppConfig.Set("MonitorVoiceWindow", this.MonitorCheck.Value)
        AppConfig.Save()

        if !AppConfig.SetAutoStart(this.AutoStartCheck.Value)
            MsgBox("设置已保存，但开机启动项更新失败。", "提示", 48)

        BridgeApp.BuildTrayMenu()
        this.StatusText.Text := "状态：设置已保存"
        BridgeApp.Notify("设置已保存")
    }

    static RefreshDelayLabels()
    {
        this.DelayText.Text := Format("{:.1f} 秒", this.DelaySlider.Value / 1000)
        this.SettleText.Text := Format("{:.1f} 秒", this.SettleSlider.Value / 1000)
    }
}

class BridgeApp
{
    static Version := "0.1.0-beta"
    static InstanceMutex := 0
    static Enabled := true
    static StatusText := "已就绪"

    static AcquireSingleInstance()
    {
        mutex := DllCall("CreateMutexW", "Ptr", 0, "Int", true, "Str", "Local\DoubaoVoiceIMEBridge", "Ptr")
        if !mutex
            return false
        if A_LastError = 183
        {
            DllCall("CloseHandle", "Ptr", mutex)
            return false
        }
        this.InstanceMutex := mutex
        return true
    }

    static ShutDown()
    {
        try VoiceController.CleanUp()
        if this.InstanceMutex
        {
            DllCall("CloseHandle", "Ptr", this.InstanceMutex)
            this.InstanceMutex := 0
        }
    }

    static Init()
    {
        if !this.AcquireSingleInstance()
        {
            MsgBox("豆包输入法语音桥已经在运行。", "豆包输入法语音桥", 48)
            ExitApp 4
        }

        existed := AppConfig.Init()
        if !DoubaoIme.IsInstalled(true)
        {
            MsgBox("没有检测到豆包 Windows 输入法。`n`n请先安装豆包输入法，再运行本工具。", "豆包输入法语音桥", 48)
            ExitApp 3
        }

        if !HotkeyController.Register(AppConfig.Get("TriggerKey"), AppConfig.Get("Mode"))
        {
            MsgBox("默认触发键注册失败，请在设置里选择其他按键。", "豆包输入法语音桥", 48)
        }

        this.BuildTrayMenu()
        try TraySetIcon("shell32.dll", 169)
        A_IconTip := "豆包输入法语音桥 - 已就绪"
        OnExit((*) => this.ShutDown())

        if !existed
            SettingsWindow.Show()
    }

    static BuildTrayMenu()
    {
        tray := A_TrayMenu
        tray.Delete()
        if this.Enabled
            tray.Add("✓ 已启用", (*) => this.ToggleEnabled())
        else
            tray.Add("○ 已暂停", (*) => this.ToggleEnabled())
        tray.Add()
        tray.Add("设置…", (*) => SettingsWindow.Show())
        tray.Add("环境诊断", (*) => this.ShowDiagnostics())
        tray.Add()
        triggerLabel := this.TriggerDisplayName(AppConfig.Get("TriggerKey"))
        modeLabel := AppConfig.Get("Mode") = "hold" ? "按住说话" : "两次点按"
        infoItem := "触发：" triggerLabel " / " modeLabel
        tray.Add(infoItem, (*) => 0)
        tray.Disable(infoItem)
        tray.Add()
        tray.Add("退出", (*) => ExitApp())
        tray.Default := "设置…"
    }

    static TriggerDisplayName(key)
    {
        names := Map("MButton", "鼠标中键", "XButton1", "鼠标侧键1", "XButton2", "鼠标侧键2", "RCtrl", "右 Ctrl", "RAlt", "右 Alt")
        return names.Has(key) ? names[key] : key
    }

    static ToggleEnabled()
    {
        this.Enabled := !this.Enabled
        if !this.Enabled && VoiceController.State != "idle"
            VoiceController.End("user")
        this.SetStatus(this.Enabled ? "已就绪" : "已暂停")
        this.BuildTrayMenu()
    }

    static SetStatus(text, listening := false)
    {
        this.StatusText := text
        A_IconTip := "豆包输入法语音桥 - " text
        if SettingsWindow.GuiObj
            SettingsWindow.StatusText.Text := "状态：" text
    }

    static Notify(message, title := "豆包输入法语音桥")
    {
        if AppConfig.Get("ShowTrayTips")
            TrayTip(message, title, 1)
    }

    static ShowDiagnostics()
    {
        installed := DoubaoIme.IsInstalled(true) ? "已安装" : "未检测到"
        service := DoubaoIme.ServiceRunning() ? "正常" : "未运行"
        bar := DoubaoIme.FindStatusBar() ? "可见" : "当前隐藏（非豆包输入法时属于正常现象）"
        wave := DoubaoIme.IsVoiceVisible() ? "可见" : "未显示"
        mode := AppConfig.Get("Mode") = "hold" ? "按住说话" : "两次点按"
        message := "安装状态：" installed "`n"
        message .= "安装位置：" (DoubaoIme.InstallPath != "" ? DoubaoIme.InstallPath : "未知") "`n"
        message .= "豆包服务：" service "`n"
        message .= "工具版本：" this.Version "`n"
        message .= "豆包状态栏：" bar "`n"
        message .= "语音波形：" wave "`n"
        message .= "工具状态：" this.StatusText "`n"
        message .= "触发方式：" this.TriggerDisplayName(AppConfig.Get("TriggerKey")) " / " mode "`n"
        message .= "校正等待：" AppConfig.Get("CorrectionDelay") " ms`n`n"
        message .= "配置文件：`n" AppConfig.Path
        MsgBox(message, "环境诊断", 64)
    }
}

BridgeApp.Init()
