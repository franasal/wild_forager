import 'package:flutter/material.dart';
import 'app.dart';
import 'services/http_user_agent.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureHttpUserAgent();
  runApp(const WildForagerApp());
}
