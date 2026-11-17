@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
 echo Node.js is needed to run the optional multiplayer server.
 echo Install the free LTS version from https://nodejs.org/
 pause
 exit /b 1
)
echo.
echo WonderWorld 3D Team Server running at http://localhost:8765/
echo Keep this window open while your team is playing.
echo For phones on the same Wi-Fi, use your computer's IPv4 address.
echo View it in another window by running: ipconfig
start "" http://localhost:8765/
node room-server.js
pause
