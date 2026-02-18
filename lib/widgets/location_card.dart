import 'package:flutter/material.dart';

class LocationCard extends StatelessWidget {
  final String title;
  final String address;
  final bool isDefault;

  const LocationCard({
    super.key,
    required this.title,
    required this.address,
    required this.isDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDefault ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? Colors.green : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (isDefault)
                const Chip(
                  label: Text("Default Location"),
                  backgroundColor: Colors.greenAccent,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(address),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isDefault)
                ElevatedButton(
                  onPressed: () {},
                  child: const Text("Set as Default"),
                ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
