import "package:flutter/material.dart";
import "package:permission_handler/permission_handler.dart";

import "../core/constants.dart";
import "../models/auth_session.dart";

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const ListTile(
            title: Text("API Base URL"),
            subtitle: Text(apiBaseUrl),
          ),
          ListTile(
            title: const Text("Signed in as"),
            subtitle: Text(session.email),
          ),
          ListTile(
            title: const Text("Open App Settings"),
            subtitle: const Text("Manage camera and other permissions"),
            onTap: openAppSettings,
          ),
          ListTile(
            title: const Text("Logout"),
            subtitle: const Text("Clear session and go to login"),
            onTap: onLogout,
          ),
          const ListTile(
            title: Text("Version"),
            subtitle: Text("startup_mobile 1.0.0"),
          ),
        ],
      ),
    );
  }
}
