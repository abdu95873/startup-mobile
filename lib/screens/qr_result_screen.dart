import "package:flutter/material.dart";

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
