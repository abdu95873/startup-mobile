import "package:flutter/material.dart";

import "../models/auth_session.dart";
import "../services/session_store.dart";
import "home_screen.dart";
import "login_screen.dart";
import "product_screen.dart";
import "qr_scan_screen.dart";
import "settings_screen.dart";

class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.session});

  final AuthSession session;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  Future<void> _logout() async {
    await SessionStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoginSuccess: (session) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => RootShell(session: session)),
            );
          },
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(session: widget.session),
      ProductScreen(session: widget.session),
      QrScanScreen(session: widget.session),
      SettingsScreen(
        session: widget.session,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: "Home"),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: "Products"),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: "Scan"),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: "Settings"),
        ],
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}
