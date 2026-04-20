import "package:flutter/material.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:permission_handler/permission_handler.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../core/constants.dart";
import "../models/auth_session.dart";
import "../services/api_client.dart";
import "qr_result_screen.dart";

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasCameraAccess = false;
  bool _checking = true;
  bool _isFirstAsk = false;
  bool _busy = false;
  String? _lastCode;

  @override
  void initState() {
    super.initState();
    _preparePermission();
  }

  Future<void> _preparePermission() async {
    final prefs = await SharedPreferences.getInstance();
    final askedBefore = prefs.getBool(cameraAskedKey) ?? false;
    var status = await Permission.camera.status;

    if (!askedBefore) {
      _isFirstAsk = true;
      await prefs.setBool(cameraAskedKey, true);
      status = await Permission.camera.request();
    }

    if (!mounted) return;
    setState(() {
      _hasCameraAccess = status.isGranted;
      _checking = false;
    });
  }

  Future<void> _requestAgain() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _hasCameraAccess = status.isGranted);
  }

  Future<void> _onCodeDetected(String code) async {
    if (_busy || code == _lastCode) return;
    setState(() {
      _busy = true;
      _lastCode = code;
    });
    try {
      final api = ApiClient(apiBaseUrl, token: widget.session.token);
      final data = await api.getQrByCode(code);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QrResultScreen(
            scannedCode: code,
            payload: data,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not fetch QR details")),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR")),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : _hasCameraAccess
              ? Column(
                  children: [
                    Expanded(
                      child: MobileScanner(
                        controller: _controller,
                        onDetect: (capture) {
                          if (capture.barcodes.isEmpty) return;
                          final code = capture.barcodes.first.rawValue;
                          if (code == null || code.trim().isEmpty) return;
                          _onCodeDetected(code.trim());
                        },
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Text(
                        _lastCode == null ? "Point camera to a QR tag" : "Last: $_lastCode",
                      ),
                    ),
                  ],
                )
              : _PermissionHelp(
                  isFirstAsk: _isFirstAsk,
                  onRequestAgain: _requestAgain,
                ),
    );
  }
}

class _PermissionHelp extends StatelessWidget {
  const _PermissionHelp({
    required this.isFirstAsk,
    required this.onRequestAgain,
  });

  final bool isFirstAsk;
  final Future<void> Function() onRequestAgain;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 44),
            const SizedBox(height: 10),
            const Text(
              "Camera permission is required",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              isFirstAsk
                  ? "Please allow camera access to scan QR tags."
                  : "You denied permission before. Allow it from settings to continue.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRequestAgain,
              child: const Text("Grant Permission"),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: openAppSettings,
              child: const Text("Open App Settings"),
            ),
          ],
        ),
      ),
    );
  }
}
