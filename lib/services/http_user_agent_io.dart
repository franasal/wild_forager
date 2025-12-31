import 'dart:io';

void configureHttpUserAgent() {
  HttpOverrides.global = _UserAgentHttpOverrides();
}

class _UserAgentHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.userAgent = 'wild_forager/1.0 (Flutter)';
    return client;
  }
}
