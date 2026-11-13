# E2E: rechazar una propuesta de equipos

Archivo: `integration_test/rechazar_propuesta_equipos_test.dart`.

Requiere Supabase configurado con `supabase/esquema.sql`, conexión a internet,
un dispositivo disponible y dos cuentas registradas distintas. El organizador
envía la propuesta y el segundo usuario actúa como capitán rival autorizado.

Desde la raíz, reemplaza los valores de ejemplo por las credenciales de prueba
y el dispositivo por el ID de `flutter devices`:

```powershell
flutter test integration_test/rechazar_propuesta_equipos_test.dart -d emulator-5554 `
  --dart-define=E2E_ORGANIZADOR_CORREO=correo_organizador `
  --dart-define=E2E_ORGANIZADOR_CLAVE=clave_organizador `
  --dart-define=E2E_CAPITAN_CORREO=correo_capitan `
  --dart-define=E2E_CAPITAN_CLAVE=clave_capitan
```

El E2E prepara un partido temporal de dos plazas en Supabase. Desde la interfaz:

1. El organizador reparte los equipos, designa al capitán rival y envía la propuesta.
2. El capitán inicia sesión y pulsa **Rechazar**.
3. Se comprueba **Propuesta: Rechazada**, sin botones para volver a responder.
4. Una consulta real verifica el estado `rechazada` y que se conservan la revisión,
   el reparto y el capitán de la propuesta original.
5. El capitán sale de la pantalla y la vuelve a abrir para comprobar persistencia.
6. El organizador inicia otra sesión y ve el rechazo y la opción **Editar propuesta**.

También se verifica el registro de inicio y finalización de la respuesta en
analítica. Al finalizar se elimina solo el partido creado por la prueba, incluso
si falla una comprobación posterior a su preparación. Las cuentas no se eliminan.
No hace falta ejecutar `flutter run` antes. Las credenciales se reciben mediante
`--dart-define`; no deben guardarse en el repositorio.
