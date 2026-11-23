@echo off
REM ============================================================================
REM Script: tool/pre_flight_check.bat
REM Validasi Pre-flight lokal untuk Developer Windows
REM ============================================================================
echo [1/3] Memeriksa Dart Formatter...
where dart >nul 2>nul
if %errorlevel% neq 0 (
    echo [SKIP] Dart belum terpasang di PATH lokal.
) else (
    call dart format --output=none --set-exit-if-changed .
    if %errorlevel% neq 0 (
        echo [ERROR] Format kode belum rapi. Jalankan 'dart format .'
        exit /b 1
    )
)

echo [2/3] Memeriksa Static Analysis...
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [SKIP] Flutter belum terpasang di PATH lokal.
) else (
    call flutter analyze --no-fatal-infos
    if %errorlevel% neq 0 (
        echo [ERROR] Analisis statis menemukan masalah.
        exit /b 1
    )
)

echo [3/3] Menjalankan Unit & Widget Tests...
if %errorlevel% neq 0 (
    echo [SKIP] Flutter belum terpasang di PATH lokal.
) else (
    call flutter test
    if %errorlevel% neq 0 (
        echo [ERROR] Ada tes yang gagal!
        exit /b 1
    )
)

echo [SUKSES] Seluruh pemeriksaan pre-flight lokal 100% lulus!
exit /b 0
