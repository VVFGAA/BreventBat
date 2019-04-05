@echo off
set d=-d
set kill=1
if exist VVFGAA.lock (
  set backup=1
  set /p MIUI=<VVFGAA.lock
)
set ANDROID_ADB_SERVER_PORT=45037
set t=黑阈服务一键开启 2.1 by VVFGAA ^^^& KizunaAI

title 【检查 ADB ……】%t%
adb version>nul 2>&1
if "%errorlevel%"=="9009" (
  ver|findstr "5.1">nul && (
    echo 错误：未找到Android调试桥（ADB），请下载platform-tools后把本文件放入此文件夹中。
    echo 链接：https://dl.google.com/android/repository/platform-tools_r23.1.0-windows.zip
    echo 按任意键退出
    pause>nul
    exit
  )
  echo 错误：未找到Android调试桥（ADB），请下载platform-tools后把本文件放入此文件夹中。按任意键打开下载网址
  pause>nul
  start https://dl.google.com/android/repository/platform-tools-latest-windows.zip
  exit
)
call :adb

title 【检查手机环境……】%t%
for /f "usebackq tokens=2 delims== " %%i in (`adb %d% shell "dumpsys package me.piebridge.brevent" ^| findstr versionCode`) do set ver=%%i
if "%ver%"=="" (
  echo 错误：未安装黑阈（此工具不支持白域），按任意键退出
  pause>nul
  goto end
)
if not %ver% GEQ 30 (
  echo 错误：黑阈版本太低，按任意键退出
  pause>nul
  goto end
)
for /f "usebackq tokens=* " %%i in (`adb %d% shell "getprop ro.boot.serialno"`) do set serialno=%%i
if "%serialno%"=="" for /f "usebackq tokens=* " %%i in (`adb %d% shell "getprop ro.build.date.utc"`) do set serialno=e-%%i
for /f "tokens=*" %%i in ('adb %d% shell "getprop ro.build.version.sdk"') do set sdk=%%i
for /f "tokens=*" %%i in ('adb %d% shell "getprop sys.usb.config"') do set usbconfig=%%i
for /f "tokens=*" %%i in ('adb %d% shell "getprop log.tag.brevent.daemon"') do set daemon=%%i
adb %d% shell "ls -l /sdcard/Android/data/me.piebridge.brevent/" 2>nul | findstr server>nul && set serverlog=1

if "%backup%"=="1" call :backup

call :check
if "%run%"=="1" (
  echo 黑阈服务已经开启，当前模式：%user%
  if "%serverlog%"=="1" (
    echo 黑阈工作日志位于手机/sdcard/Android/data/me.piebridge.brevent/目录下
    echo 问题反馈请在应用内点按日志按钮并向作者发送邮件说明情况（需要邮件应用）
    echo 按任意键开始检查事件日志，不需要请直接关闭窗口
    pause>nul
    call :events
    if "%events%"=="0" echo 警告：没有事件日志，黑阈无法自动工作。按任意键退出 && pause>nul && goto end
    echo 按任意键打开事件日志
    pause>nul
    start events.txt
    goto end
  ) else (
    echo 按任意键提取黑阈日志。不需要请直接关闭窗口
    pause>nul
    title 【提取黑阈日志……】%t%
    adb %d% shell "setprop log.tag.BreventServer D"
    adb %d% shell "logcat -G 16M"
    if not exist 黑阈日志.txt echo 此文件不会被自动删除，请注意日志的累积问题。>黑阈日志.txt
    if not exist 崩溃日志.txt echo 此文件不会被自动删除，请注意日志的累积问题。>崩溃日志.txt
    adb %d% logcat -d -b crash>>崩溃日志.txt
    adb %d% logcat -d -s BreventServer BreventLoader BreventUI>>黑阈日志.txt
    call :events
    echo 已提取日志，并调整了日志级别（重启前有效）
    echo 因此建议（如果可以的话）再触发一次相关问题，并运行本工具收集更详细的日志。
    echo 按任意键打开日志
    pause>nul
    start events.txt
    start 崩溃日志.txt
    start 黑阈日志.txt
    goto end
  )
)
if "%daemon%"=="1" (
  echo 检测到黑阈曾异常关闭，可能是由于拔线失效、关闭 USB 调试等原因造成，将开启网络ADB。
  echo 注意：网络 ADB 有风险，不要同意不明的 USB 调试确认弹窗。
  adb %d% tcpip 3035
  echo 请在拔线后打开黑阈应用一次，黑阈会自动启动服务，按任意键退出
  pause>nul
  goto end
)

title 【准备开启黑阈服务……】%t%
adb %d% shell "am force-stop me.piebridge.brevent"
adb %d% shell "am start -n me.piebridge.brevent/.ui.BreventActivity">nul
if %ver% LSS 86 (
  call :events del
  if "%events%"=="0" (
    echo 请不要关闭日志记录器缓冲区（位于开发者选项-调试）
    echo 按任意键退出
    pause>nul
    goto end
  )
)
adb %d% shell "cat /data/data/me.piebridge.brevent/brevent.sh" 2>nul|findstr "exec">nul || set file=0
if "%file%"=="0" call :findlib

title 【开启黑阈服务……】%t%
if %ver% GEQ 62 (
  if "%file%"=="0" (
    echo 警告：未发现指令文件，准备强行启动服务。可能启动失败，下次请读完黑阈向导后再运行本工具。
    adb %d% shell "%libpath%" >BreventLog.txt 2>&1
  ) else (
    adb %d% shell "sh /data/data/me.piebridge.brevent/brevent.sh" >BreventLog.txt 2>&1
  )
) else (
  echo 警告：这是黑阈的历史版本，已不受支持，请尽快更新。
  adb %d% shell "sh /sdcard/Android/data/me.piebridge.brevent/brevent.sh" >BreventLog.txt 2>&1
)
call :check
if "%run%"=="0" (
  echo 黑阈服务开启失败，请将日志与具体情况发至 https://github.com/brevent/Brevent/issues 来解决问题。>>BreventLog.txt
  echo 黑阈服务开启失败，请将日志与具体情况发至 https://github.com/brevent/Brevent/issues 来解决问题。按任意键打开日志
  pause>nul
  start BreventLog.txt
  goto end
)
adb %d% shell "setprop log.tag.brevent.daemon 1"

if "%MIUI%"=="MIUI" call :deviceidle

title 【OK】%t%
del BreventLog.txt
if %sdk% GEQ 26 (
  echo 警告：Android O及以上的设备，不要关闭“USB 调试”，不要更改 USB 使用方式，否则需要重新启动黑阈服务。
  if not "%usbconfig%"=="adb" (
    echo 警告：当前设备的状态会导致拔线后黑阈服务关闭，将开启网络ADB。注意：网络 ADB 有风险，不要同意不明的 USB 调试确认弹窗。
    adb %d% tcpip 3035
    echo 请在拔线后打开黑阈应用一次，黑阈会自动启动服务，按任意键退出
    pause>nul
    goto end
  )
)
echo 黑阈已开启，本程序即将自动关闭
ping -n 5 127.0.0.1 >nul
goto end

:adb
adb start-server>nul 2>&1 || (
  echo ADB 服务启动失败，请检查防火墙设置。
  echo 按任意键重试
  pause>nul
  goto adb
)
for /f "tokens=*" %%t in ('adb %d% get-state') do set adbState=%%t
if not "%adbState%"=="device" (
  echo;
  echo   ADB服务无法连接至设备实例，请依次确保：
  echo;
  echo   * 设备已与计算机USB连接。
  echo;
  echo   * 计算机已安装相关驱动。（各类管家/助手第一次连接设备时会帮助安装驱动）
  echo;
  echo   * 设备已启用ADB调试，并允许此计算机连接。
  echo;
  echo   * 设备没有与计算机上其他ADB服务连接，请尝试断开USB后再次连接。
  echo;
  echo 按任意键重试
  setlocal
  set ANDROID_ADB_SERVER_PORT=
  adb kill-server>nul 2>&1
  endlocal
  pause>nul
  goto adb
)
adb %d% unroot>nul
goto :EOF

:findlib
for /f "usebackq tokens=1,* delims== " %%a in (`adb %d% shell "dumpsys package me.piebridge.brevent" ^| findstr legacyNativeLibraryDir`) do set libdir=%%b
for /f "usebackq tokens=1 " %%i in (`adb %d% shell "ls %libdir%"`) do set abi=%%i
set libpath=%libdir%/%abi%/libbrevent.so
goto :EOF

:check
title 【检查黑阈服务状态……】%t%
set user=norun
if %sdk% GEQ 26 set all=-A
for /f "usebackq tokens=1 delims= " %%a in (`adb %d% shell "ps %all%" ^| findstr brevent_server`) do set user=%%a
if "%user%"=="norun" (set run=0) else set run=1
goto :EOF

:backup
title 【检查黑阈清单……】%t%
set pathx=/data/data/com.android.shell
if %sdk% GEQ 24 set pathx=/data/user_de/0/com.android.shell
adb %d% shell "ls -l %pathx%"|findstr "me.piebridge.brevent.list$">nul && (
  adb %d% pull %pathx%/me.piebridge.brevent.list %serialno%.list>nul 2>&1 && echo 已备份黑阈清单。
) || if exist %serialno%.list (
  echo 黑阈清单为空，但电脑上存在备份。
  adb %d% push  %serialno%.list %pathx%/me.piebridge.brevent.list>nul 2>&1 && echo 已还原黑阈清单。
) else (
  echo 黑阈清单为空，电脑上也没有备份。
)
goto :EOF

:deviceidle
title 【处理电池优化】%t%
for /f "usebackq tokens=* " %%a in (`adb %d% shell "getprop ro.miui.ui.version.code"`) do set miuiver=%%a
if "%miuiver%"=="" echo 不是 MIUI 系统，跳过处理电池优化。 && goto :EOF
for /f "tokens=1 delims==" %%a in (%serialno%.list) do adb %d% shell "dumpsys deviceidle whitelist -%%a">>deviceidle.log && title 【检查电池优化：%%a】%t%
for /f "usebackq tokens=2 delims=:" %%a in (`find /c "Removed:" deviceidle.log`) do set num=%%a
echo 已将%num% 个应用移出了电池优化白名单。
del deviceidle.log
goto :EOF

:events
title 【检查事件日志……】%t%
adb %d% logcat -d -b events>events.log
echo VVFGAA>>events.log
set /p fir=<events.log
if "%fir%"=="VVFGAA" set events=0
if not "%events%"=="0" (
  echo ----------am_proc_start---------->events.txt
  findstr "am_proc_start" events.log 1>>events.txt || echo 警告：未发现am_proc_start日志，无法迅速处理被恶意唤醒的应用。
  echo ----------am_restart_activity---------->>events.txt
  findstr "am_restart_activity" events.log 1>>events.txt || echo 警告：未发现am_restart_activity日志，无法识别界面被打开。
  echo ----------am_resume_activity---------->>events.txt
  findstr "am_resume_activity" events.log 1>>events.txt || echo 警告：未发现am_resume_activity日志，无法识别界面被打开。
  echo ----------screen_toggled---------->>events.txt
  findstr "screen_toggled" events.log 1>>events.txt || echo 警告：未发现screen_toggled日志，将不会在开关屏时黑阈。
  echo ----------am_new_intent---------->>events.txt
  findstr "am_new_intent" events.log 1>>events.txt || echo 未发现am_new_intent日志，无法识别主页。
  echo ----------am_pause_activity---------->>events.txt
  findstr "am_pause_activity" events.log 1>>events.txt || echo 未发现am_pause_activity日志，无法识别非正常返回。
  echo ----------am_switch_user---------->>events.txt
  findstr "am_switch_user" events.log 1>>events.txt || echo 未发现am_switch_user日志，这很正常。
  echo ----------notification_cancel_all---------->>events.txt
  findstr "notification_cancel_all" events.log 1>>events.txt || echo 未发现notification_cancel_all日志，无法识别安装或卸载应用事件。
  echo ----------notification_panel_revealed---------->>events.txt
  findstr "notification_panel_revealed" events.log 1>>events.txt || echo 未发现notification_panel_revealed日志，黑阈不会在展开通知栏时暂停。
  echo ----------notification_panel_hidden---------->>events.txt
  findstr "notification_panel_hidden" events.log 1>>events.txt || echo 未发现notification_panel_hidden日志，黑阈不会在隐藏通知栏后恢复。
  echo ----------device_idle---------->>events.txt
  findstr "device_idle:" events.log 1>>events.txt || echo 未发现device_idle日志，黑阈不会在低电耗模式下暂停。
  echo ----------device_idle_light---------->>events.txt
  findstr "device_idle_light:" events.log 1>>events.txt || echo 未发现device_idle_light日志，黑阈不会在低电耗模式下暂停。
  echo ----------notification_enqueue---------->>events.txt
  findstr "notification_enqueue:" events.log 1>>events.txt || echo 未发现notification_enqueue日志，影响黑阈检查通知。
  echo ----------notification_canceled---------->>events.txt
  findstr "notification_canceled:" events.log 1>>events.txt || echo 未发现notification_canceled日志，影响黑阈检查通知。
  echo ----------am_kill---------->>events.txt
  findstr "am_kill:" events.log 1>>events.txt || echo 未发现am_kill日志，影响黑阈检查进程。

  if "%1"=="del" del events.txt
)
del events.log
goto :EOF

:end
if "%kill%"=="1" adb kill-server>nul 2>&1
exit
