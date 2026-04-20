import "package:flutter/material.dart";

import "../core/constants.dart";
import "../models/auth_session.dart";
import "../services/api_client.dart";

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
    final api = ApiClient(apiBaseUrl, token: widget.session.token);
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Could not load products. Check backend/API base URL.",
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
