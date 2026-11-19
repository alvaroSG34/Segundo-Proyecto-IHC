/// Datos de conexión al proyecto de Supabase (base de datos compartida).
///
/// Se pueden pasar de forma segura al ejecutar o compilar:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
///
/// Para desarrollo local también puedes definir valores temporales aquí,
/// asegurándote de no subirlos al repositorio de Git.
///
/// La clave pública ("Publishable key", o la antigua "anon key") es consumida
/// por el cliente móvil: la seguridad de las tablas la garantizan las políticas
/// Row Level Security (RLS) definidas en supabase/esquema.sql.
/// NUNCA expongas aquí la clave secreta ("Secret key" o "service_role").
class ConfiguracionSupabase {
  /// Project URL (solo la dirección base, sin /rest/v1/).
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Publishable key del proyecto.
  static const String clavePublica = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: '',
  );

  /// Pagina publica que recibe el enlace enviado por Supabase al recuperar
  /// una contrasena. Se usa tambien desde Android para evitar que Supabase
  /// redirija al `localhost` configurado durante el desarrollo.
  static const String urlRecuperacion = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'https://unisport-ihc.pages.dev',
  );

  static bool get estaConfigurada => url.isNotEmpty && clavePublica.isNotEmpty;
}
