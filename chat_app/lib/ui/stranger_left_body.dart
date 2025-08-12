import 'package:flutter/material.dart';
import 'searching_screen.dart';

class StrangerLeftBody extends StatelessWidget {
  final String userId;
  const StrangerLeftBody({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/sad_emoji.png', height: 120),
          const SizedBox(height: 20),
          const Text(
            "Oops! Stranger left the chat 😕",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Want to find someone new?",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Find Again"),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchingScreen(userId: userId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
