#!/usr/bin/env bash
#
# Script de ejecución E2E para CI (GitHub Actions) y entorno local
#
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=================================================="
echo "  UniSport: Ejecución de pruebas E2E en emulador"
echo "=================================================="

# Cargar .env o .env.e2e locales si existen y no están en CI
if [ -f .env ] && [ -z "${SUPABASE_URL:-}" ]; then
  set -a
  [ -f .env ] && . ./.env
  [ -f .env.e2e ] && . ./.env.e2e
  set +a
fi

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_KEY:-}" ]; then
  echo "⚠️ AVISO: Faltan las variables SUPABASE_URL o SUPABASE_KEY."
  echo "Para ejecutar las pruebas E2E en GitHub Actions, debes configurar los secrets en:"
  echo "Repository Settings > Secrets and variables > Actions"
  exit 1
fi

DEFINES="--dart-define=SUPABASE_URL=${SUPABASE_URL} --dart-define=SUPABASE_KEY=${SUPABASE_KEY}"
[ -n "${E2E_CORREO:-}" ] && DEFINES="$DEFINES --dart-define=E2E_CORREO=${E2E_CORREO}"
[ -n "${E2E_CLAVE:-}" ] && DEFINES="$DEFINES --dart-define=E2E_CLAVE=${E2E_CLAVE}"
[ -n "${E2E_CORREO_AUXILIAR:-}" ] && DEFINES="$DEFINES --dart-define=E2E_CORREO_AUXILIAR=${E2E_CORREO_AUXILIAR}"
[ -n "${E2E_CLAVE_AUXILIAR:-}" ] && DEFINES="$DEFINES --dart-define=E2E_CLAVE_AUXILIAR=${E2E_CLAVE_AUXILIAR}"
[ -n "${E2E_CORREO_EXISTENTE:-}" ] && DEFINES="$DEFINES --dart-define=E2E_CORREO_EXISTENTE=${E2E_CORREO_EXISTENTE}"
[ -n "${E2E_ORGANIZADOR_CORREO:-}" ] && DEFINES="$DEFINES --dart-define=E2E_ORGANIZADOR_CORREO=${E2E_ORGANIZADOR_CORREO}"
[ -n "${E2E_ORGANIZADOR_CLAVE:-}" ] && DEFINES="$DEFINES --dart-define=E2E_ORGANIZADOR_CLAVE=${E2E_ORGANIZADOR_CLAVE}"
[ -n "${E2E_TITULAR_CORREO:-}" ] && DEFINES="$DEFINES --dart-define=E2E_TITULAR_CORREO=${E2E_TITULAR_CORREO}"
[ -n "${E2E_TITULAR_CLAVE:-}" ] && DEFINES="$DEFINES --dart-define=E2E_TITULAR_CLAVE=${E2E_TITULAR_CLAVE}"
[ -n "${E2E_SUPLENTE_CORREO:-}" ] && DEFINES="$DEFINES --dart-define=E2E_SUPLENTE_CORREO=${E2E_SUPLENTE_CORREO}"
[ -n "${E2E_SUPLENTE_CLAVE:-}" ] && DEFINES="$DEFINES --dart-define=E2E_SUPLENTE_CLAVE=${E2E_SUPLENTE_CLAVE}"
[ -n "${E2E_CAPITAN_CORREO:-}" ] && DEFINES="$DEFINES --dart-define=E2E_CAPITAN_CORREO=${E2E_CAPITAN_CORREO}"
[ -n "${E2E_CAPITAN_CLAVE:-}" ] && DEFINES="$DEFINES --dart-define=E2E_CAPITAN_CLAVE=${E2E_CAPITAN_CLAVE}"

# Detectar comando flutter
FLUTTER_BIN="flutter"
if ! command -v flutter &>/dev/null; then
  if [ -x "/home/rusti/Flutter/flutter/bin/flutter" ]; then
    FLUTTER_BIN="/home/rusti/Flutter/flutter/bin/flutter"
  fi
fi

# Detectar dispositivo
DEVICE="${DEVICE:-}"
if [ -z "$DEVICE" ]; then
  if command -v adb &>/dev/null; then
    DEVICE=$(adb devices 2>/dev/null | grep -o 'emulator-[0-9]\+' | head -n 1 || true)
  fi
fi

if [ -z "$DEVICE" ]; then
  DEVICE=$($FLUTTER_BIN devices 2>/dev/null | grep -o 'emulator-[0-9]\+' | head -n 1 || true)
fi

if [ -z "$DEVICE" ]; then
  DEVICE=$($FLUTTER_BIN devices 2>/dev/null | grep -E "android|emulator" | head -n 1 | awk -F'•' '{print $2}' | tr -d ' ' || true)
fi

if [ -z "$DEVICE" ]; then
  DEVICE="emulator-5554"
fi

echo "Dispositivo seleccionado: $DEVICE"

TEST_FILES=(
  "login_test.dart"
  "recuperar_clave_test.dart"
  "registro_test.dart"
  "salir_partido_test.dart"
  "cerrar_sesion_test.dart"
  "editar_partido_test.dart"
  "eliminar_partido_test.dart"
  "crear_partido_test.dart"
  "rechazar_propuesta_equipos_test.dart"
  "explorar_partidos_test.dart"
  "historial_test.dart"
  "tarea_10_cuenta_test.dart"
  "unirse_partido_test.dart"
  "flujo_suplentes_test.dart"
  "mis_partidos_test.dart"
  "reprogramar_partido_test.dart"
  "resultado_partido_restricciones_test.dart"
  "resultado_partido_flujo_test.dart"
)

TOTAL=${#TEST_FILES[@]}
PASSED=0
FAILED=0
FAILED_NAMES=()

echo "Iniciando ejecución de $TOTAL pruebas E2E..."

for TEST in "${TEST_FILES[@]}"; do
  echo ""
  echo "--------------------------------------------------"
  echo "  Ejecutando: integration_test/$TEST"
  echo "--------------------------------------------------"

  if $FLUTTER_BIN test "integration_test/$TEST" -d "$DEVICE" $DEFINES; then
    echo "✅ PASÓ: $TEST"
    PASSED=$((PASSED + 1))
  else
    echo "❌ FALLÓ: $TEST"
    FAILED=$((FAILED + 1))
    FAILED_NAMES+=("$TEST")
  fi
done

echo ""
echo "=================================================="
echo "  Resumen de ejecución E2E"
echo "=================================================="
echo "Total:    $TOTAL"
echo "Pasaron:  $PASSED"
echo "Fallaron: $FAILED"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## 📱 Reporte de Pruebas E2E (Android)"
    echo ""
    if [ "$FAILED" -eq 0 ]; then
      echo "> 🟢 **Todas las pruebas E2E pasaron:** $PASSED de $TOTAL aprobadas."
    else
      echo "> 🔴 **Pruebas E2E fallidas:** $FAILED de $TOTAL fallaron."
    fi
    echo ""
    echo "| # | Archivo E2E | Estado |"
    echo "|---|:---|:---:|"
    for (( i=0; i<TOTAL; i++ )); do
      T="${TEST_FILES[$i]}"
      if [[ " ${FAILED_NAMES[*]:-} " =~ " ${T} " ]]; then
        echo "| $((i+1)) | \`$T\` | ❌ Falló |"
      else
        echo "| $((i+1)) | \`$T\` | ✅ Aprobado |"
      fi
    done
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$FAILED" -gt 0 ]; then
  echo "Fallas detectadas en: ${FAILED_NAMES[*]}"
  exit 1
fi

echo "¡Todas las pruebas E2E finalizaron exitosamente!"
exit 0
