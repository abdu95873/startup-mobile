import "dart:convert";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:mobile_scanner/mobile_scanner.dart";
import "package:permission_handler/permission_handler.dart";
import "package:shared_preferences/shared_preferences.dart";

String get _apiBaseUrl {
  if (kIsWeb) return "http://localhost:5000";
  if (defaultTargetPlatform == TargetPlatform.android) {
    return "http://10.0.2.2:5000";
  }
  return "http://localhost:5000";
}
const String _cameraAskedKey = "camera_permission_asked";
const String _tokenKey = "app_jwt_token";
const String _emailKey = "app_user_email";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StartupMobileApp());
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.email,
  });

  final String token;
  final String email;
}

class SessionStore {
  static Future<AuthSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final email = prefs.getString(_emailKey) ?? "";
    if (token == null || token.isEmpty) return null;
    return AuthSession(token: token, email: email);
  }

  static Future<void> save(AuthSession s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, s.token);
    await prefs.setString(_emailKey, s.email);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
  }
}

class ApiClient {
  ApiClient(this.baseUrl, {this.token});

  final String baseUrl;
  final String? token;

  Map<String, String> get _headers {
    final h = <String, String>{"Content-Type": "application/json"};
    if (token != null && token!.isNotEmpty) {
      h["Authorization"] = "Bearer $token";
    }
    return h;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/auth/login"),
      headers: _headers,
      body: jsonEncode({"email": email, "password": password}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Login failed (${res.statusCode})");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/auth/register"),
      headers: _headers,
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Register failed (${res.statusCode})");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(Uri.parse("$baseUrl/api/auth/me"), headers: _headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Could not fetch profile (${res.statusCode})");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final res = await http.get(Uri.parse("$baseUrl/api/products"), headers: _headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Failed to load products (${res.statusCode})");
    }
    final decoded = jsonDecode(res.body);
    final raw = decoded is List
        ? decoded
        : (decoded["data"] as List<dynamic>? ?? <dynamic>[]);
    return raw.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getQrByCode(String code) async {
    final res = await http.get(Uri.parse("$baseUrl/api/qr/code/$code"), headers: _headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("QR not found or server error (${res.statusCode})");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});

  final void Function(AuthSession session) onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiClient(_apiBaseUrl);
      final data = await api.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      final token = (data["token"] ?? "").toString();
      if (token.isEmpty) throw Exception("Token missing");
      final session = AuthSession(
        token: token,
        email: _emailCtrl.text.trim(),
      );
      await SessionStore.save(session);
      if (!mounted) return;
      widget.onLoginSuccess(session);
    } catch (e) {
      setState(() {
        _error = "Login failed. Check email/password and server status.";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiClient(_apiBaseUrl);
      await api.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful. Please login.")),
      );
      _tab.animateTo(0);
    } catch (_) {
      setState(() {
        _error = "Register failed. Email may already exist.";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Tag Auth"),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: "Login"),
            Tab(text: "Register"),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: TabBarView(
              controller: _tab,
              children: [
                _buildForm(isRegister: false),
                _buildForm(isRegister: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm({required bool isRegister}) {
    return ListView(
      children: [
        const SizedBox(height: 10),
        Text(
          isRegister ? "Create account" : "Sign in to continue",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        if (isRegister) ...[
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: "Name",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: "Email",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: "Password",
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : (isRegister ? _register : _login),
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isRegister ? "Register" : "Login"),
          ),
        ),
      ],
    );
  }
}

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(_apiBaseUrl, token: session.token);
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

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late Future<List<Map<String, dynamic>>> _futureProducts;

  @override
  void initState() {
    super.initState();
    _futureProducts = _fetchProducts();
  }

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    final api = ApiClient(_apiBaseUrl, token: widget.session.token);
    return api.getProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Packages")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureProducts,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Could not load products.\n$_apiBaseUrl/api/products",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) return const Center(child: Text("No products found"));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = items[i];
              return ListTile(
                title: Text("${p["title"] ?? "Untitled"}"),
                subtitle: Text("${p["description"] ?? ""}"),
                trailing: Text("৳${p["price"] ?? "-"}"),
              );
            },
          );
        },
      ),
    );
  }
}

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
  String? _lastCode;
  bool _busy = false;
  Future<void> _onCodeDetected(String code) async {
    if (_busy || code == _lastCode) return;
    setState(() {
      _busy = true;
      _lastCode = code;
    });
    try {
      final api = ApiClient(_apiBaseUrl, token: widget.session.token);
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not fetch QR details")),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  @override
  void initState() {
    super.initState();
    _preparePermission();
  }

  Future<void> _preparePermission() async {
    final prefs = await SharedPreferences.getInstance();
    final askedBefore = prefs.getBool(_cameraAskedKey) ?? false;
    var status = await Permission.camera.status;

    if (!askedBefore) {
      _isFirstAsk = true;
      await prefs.setBool(_cameraAskedKey, true);
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
          ListTile(
            title: const Text("API Base URL"),
            subtitle: Text(_apiBaseUrl),
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

class QrResultScreen extends StatelessWidget {
  const QrResultScreen({
    super.key,
    required this.scannedCode,
    required this.payload,
  });

  final String scannedCode;
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final qr = payload["qr"] as Map<String, dynamic>?;
    final vehicle = payload["vehicle"] as Map<String, dynamic>?;
    final assigned = vehicle != null;

    return Scaffold(
      appBar: AppBar(title: const Text("QR Result")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assigned ? "Assigned QR" : "Unassigned QR",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text("Scanned Code: $scannedCode"),
                Text("QR ID: ${qr?["_id"] ?? "N/A"}"),
                Text("Status: ${assigned ? "Assigned" : "Not assigned"}"),
                if (assigned) ...[
                  const Divider(height: 24),
                  Text("Vehicle: ${vehicle["vehicleName"] ?? "-"}"),
                  Text("Model: ${vehicle["model"] ?? "-"}"),
                  Text("Plate: ${vehicle["plate"] ?? "-"}"),
                  Text("Owner Phone: ${vehicle["ownerPhone"] ?? "-"}"),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      "This QR is not linked to a vehicle yet.",
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
