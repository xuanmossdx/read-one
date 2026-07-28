@echo off
chcp 65001 >nul
cd /d "%~dp0"

set "EXE=%~dp0read-one.exe"
set "REL="
set "DEP_SCRIPT=%~dp0..\依赖包\Install-Runtime.bat"

if not exist "%EXE%" (
  echo 未找到 read-one.exe
  pause
  exit /b 1
)

for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release 2^>nul ^| findstr /i Release') do set "REL=%%a"

rem 461808 = .NET Framework 4.7.2
if defined REL if %REL% GEQ 461808 goto :run

echo 未检测到 .NET Framework 4.7.2 或更高版本。
echo.
if exist "%DEP_SCRIPT%" (
  echo 已找到旁边的“依赖包”，现在为你打开一键安装脚本...
  start "" "%DEP_SCRIPT%"
) else (
  echo 请先下载并解压“依赖包”文件夹，
  echo 然后运行：依赖包\Install-Runtime.bat
  echo.
  echo 期望位置：
  echo   %DEP_SCRIPT%
)
pause
exit /b 1

:run
start "" "%EXE%"
exit /b 0
