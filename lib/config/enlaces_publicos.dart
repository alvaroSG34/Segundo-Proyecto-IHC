import 'package:url_launcher/url_launcher.dart';

final Uri urlPoliticaPrivacidad = Uri.parse(
  'https://unisport-ihc.pages.dev/politica-de-privacidad.html',
);

final Uri urlEliminarCuenta = Uri.parse(
  'https://unisport-ihc.pages.dev/eliminar-cuenta.html',
);

Future<bool> abrirPoliticaPrivacidad() =>
    launchUrl(urlPoliticaPrivacidad, mode: LaunchMode.externalApplication);
