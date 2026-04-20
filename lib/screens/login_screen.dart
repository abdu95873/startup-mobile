import "package:flutter/material.dart";

import "../core/constants.dart";
import "../models/auth_session.dart";
import "../services/api_client.dart";
import "../services/session_store.dart";

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
      final api = ApiClient(apiBaseUrl);
      final data = await api.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      final token = (data["token"] ?? "").toString();
      if (token.isEmpty) throw Exception("Token missing");
      final session = AuthSession(token: token, email: _emailCtrl.text.trim());
      await SessionStore.save(session);
      if (!mounted) return;
      widget.onLoginSuccess(session);
    } catch (_) {
      setState(() => _error = "Login failed. Check email/password and server status.");
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
      final api = ApiClient(apiBaseUrl);
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
      setState(() => _error = "Register failed. Email may already exist.");
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
