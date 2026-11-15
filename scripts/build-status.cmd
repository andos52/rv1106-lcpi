@echo off
setlocal
set "SCRIPT=%~dp0status.sh"
set "SCRIPT=%SCRIPT:\=/%"
set "SCRIPT=/mnt/c%SCRIPT:~2%"
wsl -d Ubuntu bash "%SCRIPT%" %1
