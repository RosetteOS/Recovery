@echo off
setlocal

cd /d "%~dp0"

python3 ".\scripts\rebuild_ingenic.py" ^
    ".\Ender-3_V3_KE_1.1.0.12.ingenic" ^
    ".\Ender-3_V3_OKE_v0.0.1.ingenic" ^
    --root1 ".\rootfs.squashfs" ^
    --kernel1 ".\xImage"

set "exitCode=%ERRORLEVEL%"
endlocal & exit /b %exitCode%
