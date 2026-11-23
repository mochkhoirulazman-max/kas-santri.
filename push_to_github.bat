@echo off
echo ====================================================
echo Menghubungkan dan Mengunggah Kas Santri ke GitHub...
echo ====================================================
set "PATH=%PATH%;C:\Users\smkit\AppData\Local\Programs\Git\cmd"
cd /d "D:\project antigrafity"

git remote set-url origin https://github.com/mochkhoirulazman-max/kas-santri..git
git push -f -u origin main

echo.
echo ====================================================
echo Selesai! Buka https://github.com/mochkhoirulazman-max/kas-santri./actions
echo ====================================================
pause
