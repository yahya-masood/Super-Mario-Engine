@echo off
rem ==========================================================================
rem FILE    : build.bat
rem OWNER   : Yahya Masood (Module 1)
rem PURPOSE : Assemble src\mario.asm into build\MARIO.COM using NASM.
rem USAGE   : run "build.bat" in Command Prompt from the project root folder
rem ==========================================================================

if not exist build mkdir build

nasm -f bin src\mario.asm -Isrc/ -w+all -l build\mario.lst -o build\MARIO.COM
if errorlevel 1 goto failed

echo.
echo BUILD OK - created build\MARIO.COM
dir build\MARIO.COM
exit /b 0

:failed
echo.
echo BUILD FAILED - read the FIRST error message above and fix that one first.
exit /b 1