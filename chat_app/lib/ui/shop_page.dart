// import 'package:flutter/material.dart';

// class ShopPage extends StatelessWidget {
//   const ShopPage({super.key});

//   void _showPremiumOptions(BuildContext context) {
//     showDialog(
//       context: context,
//       builder:
//           (_) => AlertDialog(
//             title: const Text("Upgrade to Premium"),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: const [
//                 ListTile(
//                   leading: Icon(Icons.calendar_month),
//                   title: Text("Monthly Access"),
//                   subtitle: Text("\$2.99 / month"),
//                 ),
//                 ListTile(
//                   leading: Icon(Icons.lock_clock),
//                   title: Text("Lifetime Access"),
//                   subtitle: Text("\$24.99 one-time"),
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text("Close"),
//               ),
//             ],
//           ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Shop")),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           const Text(
//             "🟣 PREMIUM USERS",
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 12),
//           ElevatedButton.icon(
//             icon: const Icon(Icons.workspace_premium),
//             label: const Text("Upgrade to Premium"),
//             onPressed: () => _showPremiumOptions(context),
//           ),
//           const SizedBox(height: 24),
//           const Divider(),
//           const Text(
//             "🆓 FREE FEATURES",
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 12),
//           ListTile(
//             leading: const Icon(Icons.refresh),
//             title: const Text("Rematch Previous User"),
//             trailing: const Text("25 coins"),
//           ),
//           ListTile(
//             leading: const Icon(Icons.star),
//             title: const Text("1-Day Premium Access"),
//             trailing: const Text("100 coins"),
//           ),
//           ListTile(
//             leading: const Icon(Icons.flash_on),
//             title: const Text("Priority Matching (1hr)"),
//             trailing: const Text("30 coins"),
//           ),
//           ListTile(
//             leading: const Icon(Icons.ad_units),
//             title: const Text("Hide Ads for 1 Day"),
//             trailing: const Text("50 coins"),
//           ),
//         ],
//       ),
//     );
//   }
// }
