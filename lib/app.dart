import "package:flutter/material.dart";

import "app_bootstrap.dart";

class StartupMobileApp extends StatelessWidget {
  const StartupMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "QR Tag Mobile",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const AppBootstrap(),
    );
  }
}
