// ═════════════════════════════════════════════════════════════════
// r2_config.dart — Aspirantes ITVH
//
// Configuración de Cloudflare R2 para esta app. Buckets dedicados
// (independientes de Comunidad ITVH) para aislar el contenido de
// aspirantes.
//
// SEGURIDAD (jul 2026):
//   Esta versión YA NO contiene accountId/accessKey/secretKey del
//   lado del cliente. El flujo viejo con --dart-define-from-file
//   reducía el riesgo de que las credenciales quedaran en texto
//   plano en el repo, pero seguían viajando dentro del APK
//   compilado — cualquiera podía extraerlas descompilando la app,
//   con permisos reales de lectura/escritura/borrado sobre los
//   buckets. Además, si el build no pasaba la bandera
//   --dart-define-from-file, las credenciales llegaban vacías en
//   silencio (justo lo que causó el error "MinioError: Endpoint
//   .r2.cloudflarestorage.com is not a valid domain").
//
//   Ahora TODA subida/borrado pasa por Edge Functions de Supabase
//   (`generar-url-subida`, `eliminar-objeto-r2`), que son las
//   ÚNICAS que conocen accountId/accessKey/secretKey — viven como
//   secrets del lado del servidor:
//
//     supabase secrets set R2_ACCOUNT_ID=...
//     supabase secrets set R2_ACCESS_KEY_ID=...
//     supabase secrets set R2_SECRET_ACCESS_KEY=...
//
//   El cliente Flutter solo necesita saber A DÓNDE llamar (la URL
//   base de las funciones) y qué buckets/dominios públicos existen
//   — nada de eso es secreto, son datos públicos de todos modos
//   (los dominios r2.dev ya son públicos por diseño).
// ═════════════════════════════════════════════════════════════════

class R2Config {
  R2Config._();

  // ── Edge Functions (Supabase) ──────────────────────────────
  // Project ref: xllfczvhzfnccbzeedqd (Aspirantes ITVH).
  static const String edgeFunctionsUrl =
      'https://xllfczvhzfnccbzeedqd.supabase.co/functions/v1';

  // ── Buckets ─────────────────────────────────────────────────
  static const String bucketPerfil        = 'itvh-aspirantes-perfil';
  static const String bucketPublicaciones = 'itvh-aspirantes-publicaciones';

  // ── Dominios públicos (CDN) ─────────────────────────────────
  // Tu custom domain o el subdominio r2.dev habilitado en el paso
  // "Public access" de cada bucket. Esto es público por diseño,
  // no es información sensible.
  static const String dominioPerfil        = 'https://pub-18fdb12494a14724b0f9badea2fd0fdb.r2.dev';
  static const String dominioPublicaciones = 'https://pub-3e198ec7a9bf48d6835a1e037c2dea4d.r2.dev';
}