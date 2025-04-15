import 'package:flutter/material.dart';

class FindAgainPlaceholder extends StatelessWidget {
  final VoidCallback onFindAgain;

  const FindAgainPlaceholder({super.key, required this.onFindAgain});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Stranger left the chat.", style: TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Find Again"),
            onPressed: onFindAgain,
          ),
        ],
      ),
    );
  }
}
