@echo off
chcp 65001 >nul
cd /d "%~dp0"

set "DEP_SCRIPT=%~dp0..\依赖包\Install-Runtime.bat"
if exist "%DEP_SCRIPT%" (
  start "" "%DEP_SCRIPT%"
  exit /b 0
)

echo 未找到旁边的“依赖包”安装脚本。
echo 请先下载并解压“依赖包”文件夹，
echo 然后运行：依赖包\Install-Runtime.bat
echo.
echo 期望位置：
echo   %DEP_SCRIPT%
pause
exit /b 1
