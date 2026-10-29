/// Datos de conexión al proyecto de Supabase (base de datos compartida).
///
/// Se pueden pasar al ejecutar:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
/// o escribirse en los valores por defecto de abajo.
///
/// La clave pública ("Publishable key", o la antigua "anon key") puede estar en
/// el código: la seguridad la dan las reglas por fila (RLS) definidas en
/// supabase/esquema.sql. Nunca pongas aquí la clave secreta ("Secret key" o
/// "service_role").
class ConfiguracionSupabase {
  /// Project URL (solo la dirección base, sin /rest/v1/).
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bxntcurkwwczhkngmvvk.supabase.co',
  );

  /// Publishable key del proyecto.
  static const String clavePublica = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_C41hkBvxQKrcm2bLk8nSoA_E3697ZZf',
  );

  static bool get estaConfigurada => url.isNotEmpty && clavePublica.isNotEmpty;
}
