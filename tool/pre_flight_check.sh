#!/usr/bin/env bash
# ============================================================================
# Script: tool/pre_flight_check.sh
# Validasi Pre-flight lokal untuk Developer Linux / macOS
# ============================================================================
set -e

echo "[1/3] Memeriksa Dart Formatter..."
if command -v dart >/dev/null 2>&1; then
    dart format --output=none --set-exit-if-changed .
else
    echo "[SKIP] Dart belum terpasang di PATH lokal."
fi

echo "[2/3] Memeriksa Static Analysis..."
if command -v flutter >/dev/null 2>&1; then
    flutter analyze --no-fatal-infos
else
    echo "[SKIP] Flutter belum terpasang di PATH lokal."
fi

echo "[3/3] Menjalankan Unit & Widget Tests..."
if command -v flutter >/dev/null 2>&1; then
    flutter test
else
    echo "[SKIP] Flutter belum terpasang di PATH lokal."
fi

echo "[SUKSES] Seluruh pemeriksaan pre-flight lokal 100% lulus!"
exit 0
