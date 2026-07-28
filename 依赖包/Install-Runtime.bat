@echo off
chcp 65001 >nul
cd /d "%~dp0"

set "SETUP=%~dp0NDP472-KB4054530-x86-x64-AllOS-ENU.exe"
if not exist "%SETUP%" (
  echo 未找到运行库安装包：NDP472-KB4054530-x86-x64-AllOS-ENU.exe
  pause
  exit /b 1
)

set "REL="
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release 2^>nul ^| findstr /i Release') do set "REL=%%a"

rem 461808 = .NET Framework 4.7.2
if defined REL if %REL% GEQ 461808 goto :already

echo 即将安装 .NET Framework 4.7.2（微软官方离线包，可能需要管理员权限与重启）...
echo.
"%SETUP%"
set "EC=%ERRORLEVEL%"
if %EC%==0 (
  echo 安装完成。
) else if %EC%==3010 (
  echo 安装完成，需要重启电脑后再运行 read-one。
) else (
  echo 安装程序退出代码：%EC%
)
pause
exit /b %EC%

:already
echo 本机已安装 .NET Framework 4.7.2 或更高版本，无需再装。
pause
exit /b 0
