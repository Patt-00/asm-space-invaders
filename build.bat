@echo off
nasm -f bin main.asm -o INVADERS.COM
if errorlevel 1 goto error
echo Built INVADERS.COM successfully.
goto end
:error
echo Build failed. Check NASM's error message above.
:end
