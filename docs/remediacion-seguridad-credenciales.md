# Auditoría y Remediación de Seguridad de Credenciales

Este documento detalla el análisis de seguridad realizado sobre el repositorio de **UniSport**, los hallazgos encontrados respecto a credenciales y claves expuestas, y las acciones de remediación aplicadas.

---

## 1. Resumen Ejecutivo

* **Estado general:** El proyecto contaba con una arquitectura de datos bien protegida a nivel de base de datos gracias a las reglas **Row Level Security (RLS)** en PostgreSQL. No se identificaron claves maestras (`service_role`), certificados privados ni tokens de infraestructura en la nube (AWS/GCP).
* **Vulnerabilidades mitigadas:** Se identificó la presencia de la URL y la Publishable Key de Supabase fijas en el código fuente, contraseñas de cuentas semilla en documentación pública y ausencia de exclusión de archivos de entorno en `.gitignore`.
* **Remediación:** Se desvincularon las credenciales fijas del código, se blindó el `.gitignore`, se suministró una plantilla `.env.example` y se sanearon las referencias a contraseñas en la documentación.

---

## 2. Metodología de la Auditoría

Se realizó una inspección sobre:
1. **Historial completo de Git:** Búsqueda mediante expresiones regulares en commits, diffs y ramas (`git log -p --all`) rastreando patrones de:
   - Claves de Supabase (`sb_publishable_*`, `sb_secret_*`, `service_role`).
   - Tokens JWT (`eyJ...`).
   - Claves de Google (`AIzaSy...`), AWS (`AKIA...`), GitHub PATs y llaves privadas RSA/OpenSSH.
2. **Archivos de configuración y repositorios locales:** Revisión de `lib/config/`, `android/`, `ios/`, `web/`, scripts y `.gitignore`.
3. **Políticas de Base de Datos:** Verificación de las tablas y políticas en `supabase/esquema.sql`.

---

## 3. Hallazgos Identificados

| Elemento | Ubicación | Severidad | Estado |
| :--- | :--- | :--- | :--- |
| **Publishable Key y URL en código** | `lib/config/configuracion_supabase.dart` | Media | **Remediado** |
| **Credenciales semilla en texto plano** | `README.md` y `docs/base-de-datos-supabase.md` | Media | **Remediado** |
| **Ausencia de reglas en `.gitignore`** | `.gitignore` | Baja / Preventiva | **Remediado** |
| **Claves maestras (`service_role`)** | Repositorio completo | Crítica | **No detectadas (Seguro)** |
| **Políticas RLS en Base de Datos** | `supabase/esquema.sql` | Alta | **Implementadas correctamente** |

### Detalle de los hallazgos:
1. **URL y clave pública fijadas en código:**
   - La URL (`https://bxntcurkwwczhkngmvvk.supabase.co`) y la clave (`sb_publishable_...`) estaban configuradas como `defaultValue` dentro de `lib/config/configuracion_supabase.dart`.
   - *Evaluación de riesgo:* En Supabase, la Publishable Key (`anon`) está pensada para ser consumida por clientes móviles y web, y su seguridad depende de las políticas RLS. Sin embargo, exponerla en repositorios compartidos o públicos expone la instancia a consumo de cuota, ataques de denegación de servicio o spam en los endpoints de registro.
2. **Contraseñas semilla en documentación:**
   - En el `README.md` y la guía de Supabase se especificaba la contraseña fija (`123456`) para las cuentas de prueba `diego@unisport.edu` y `lorgio@unisport.edu`.
   - Con la combinación de la Publishable Key y estas credenciales públicas, cualquier usuario podía autenticarse legítimamente y operar con permisos de estudiante dentro de la base de datos real.
3. **Fuga potencial de archivos `.env` o certificados:**
   - `.gitignore` no ignoraba `.env`, `.env.*` ni certificados Android (`key.properties`, `*.jks`, `*.keystore`).

---

## 4. Acciones de Remediación Aplicadas

### Paso 1: Limpieza de `lib/config/configuracion_supabase.dart`
* Se retiraron los valores reales por defecto (`defaultValue: ''`), manteniendo la lectura de variables en tiempo de compilación (`String.fromEnvironment`).
* Si la aplicación se ejecuta sin credenciales, la clase `_FaltaConfiguracion` en `lib/main.dart` avisa limpiamente al usuario que debe suministrar las variables.

### Paso 2: Blindaje de `.gitignore` y creación de `.env.example`
* Se agregaron al archivo `.gitignore`:
  ```gitignore
  # Variables de entorno y secretos
  .env
  .env.*
  !.env.example

  # Firmas y certificados de Android
  key.properties
  *.jks
  *.keystore

  # Registros de pruebas generados localmente
  /build/registro-e2e-cuentas.txt

  # Generated plugin registrants (Desktop)
  linux/flutter/generated_plugin_registrant.*
  linux/flutter/generated_plugins.cmake
  windows/flutter/generated_plugin_registrant.*
  windows/flutter/generated_plugins.cmake
  macos/Flutter/GeneratedPluginRegistrant.swift
  ```
* Se desasociaron del rastreo de Git (`git rm --cached`) los registradores de plugins generados para Linux, Windows y macOS, preservando los archivos locales para compilar sin ensuciar el control de versiones al añadir librerías.
* Se creó el archivo `.env.example` como referencia para desarrolladores sin exponer valores reales.

### Paso 3: Saneamiento de Documentación
* En `README.md` y `docs/base-de-datos-supabase.md`:
  - Se eliminaron las contraseñas fijas (`123456`).
  - Se sustituyeron por indicaciones para que cada evaluador o desarrollador registre su propia cuenta con una contraseña privada.
  - Se actualizaron los ejemplos de comandos para utilizar parámetros seguros `--dart-define`.

---

## 5. Guía de Ejecución Segura

Para ejecutar o probar la aplicación ahora que no contiene credenciales fijas en el código:

### Opción A: Pasar las credenciales por línea de comandos (Recomendada)
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_KEY=tu_publishable_key
```

### Opción B: Configuración local en VS Code (`.vscode/launch.json`)
Puedes configurar tu entorno local en `.vscode/launch.json` (asegurándote de que permanezca ignorado o no versionado):
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "UniSport (Desarrollo)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define", "SUPABASE_URL=https://tu-proyecto.supabase.co",
        "--dart-define", "SUPABASE_KEY=tu_publishable_key"
      ]
    }
  ]
}
```

### Opción C: Pruebas automatizadas e integración E2E
```bash
flutter test integration_test/crear_partido_test.dart -d emulator-5554 \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_KEY=tu_publishable_key \
  --dart-define=E2E_CORREO=usuario_prueba@unisport.edu \
  --dart-define=E2E_CLAVE=tu_clave_segura
```

---

## 6. Pasos Siguientes Recomendados (Gestión en Supabase)

1. **Rotación de Clave en Supabase:**
   - En la consola de Supabase (*Project Settings* → *API*), rota la clave de API (*Roll key*) si el repositorio ha sido público o compartido externamente.
2. **Actualización de Usuarios de Prueba:**
   - En *Authentication* → *Users*, actualiza las contraseñas de las cuentas `diego@unisport.edu` y `lorgio@unisport.edu` para invalidar la contraseña `123456` que estuvo en la documentación anterior.
