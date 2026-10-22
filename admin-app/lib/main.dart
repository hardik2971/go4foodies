import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'shell/router.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // /dashboard, /pos/<id> … like the Laravel URLs
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final theme = ThemeController();
  await theme.load();
  final session = Session();
  session.restore();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: theme),
      ChangeNotifierProvider.value(value: session),
    ],
    child: AdminApp(session: session),
  ));
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key, required this.session});
  final Session session;
  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final router = buildRouter(widget.session);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final ready = context.select<Session, bool>((s) => s.ready);
    // The router is mounted from the start so the browser URL (deep link / reload) is kept while
    // the Firebase session restores; the redirect runs once `ready` flips.
    return MaterialApp.router(
      title: 'Go4Foodie Admin',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: toastMessenger,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: theme.mode,
      routerConfig: router,
      builder: (context, child) => ready ? child! : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
