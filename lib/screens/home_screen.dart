import "package:flutter/material.dart";

import "../core/constants.dart";
import "../models/auth_session.dart";
import "../services/api_client.dart";

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(apiBaseUrl, token: session.token);
    return Scaffold(
      appBar: AppBar(title: const Text("QR Tag System")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, dynamic>>(
          future: api.getMe(),
          builder: (context, snap) {
            final me = snap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Scan. Connect. Stay Safe.",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          me == null
                              ? "Signed in as ${session.email}"
                              : "Hello ${me["name"] ?? me["email"] ?? session.email}",
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text("Vehicle Safety")),
                    Chip(label: Text("No app required for scanner users")),
                    Chip(label: Text("Secure contact flow")),
                  ],
                ),
                if (snap.hasError)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      "Profile fetch failed (token might be expired).",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
