#!/usr/bin/env bash
#
# Script de pruebas y cobertura local para UniSport
# Emula la experiencia de 'pnpm test --coverage' adaptada a Flutter.
#
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=================================================="
echo "  UniSport: Ejecutando pruebas y cobertura local"
echo "=================================================="

flutter test --coverage "$@"
dart run tool/reporte_cobertura.dart coverage/lcov.info
