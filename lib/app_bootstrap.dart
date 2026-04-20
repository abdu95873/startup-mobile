import "package:flutter/material.dart";

import "models/auth_session.dart";
import "screens/login_screen.dart";
import "screens/root_shell.dart";
import "services/session_store.dart";

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<AuthSession?> _futureSession;

  @override
  void initState() {
    super.initState();
    _futureSession = SessionStore.load();
  }

  void _enterApp(AuthSession session) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RootShell(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSession?>(
      future: _futureSession,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = snap.data;
        if (session == null) {
          return LoginScreen(onLoginSuccess: _enterApp);
        }
        return RootShell(session: session);
      },
    );
  }
}
