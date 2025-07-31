import 'package:flutter/material.dart';
import 'start_chat_page.dart';
// import 'friends_page.dart'; // import your FriendsPage
import '../services/user_id_storage.dart';
import 'settings_page.dart';
import '../firebase//firestore_service.dart';
import 'package:logger/logger.dart';
// import 'shop_page.dart';

final FirestoreService _firestoreService = FirestoreService();
final logger = Logger();

class HomeContainerPage extends StatefulWidget {
  final Widget? overrideBody;
  final int? initialIndex;

  const HomeContainerPage({super.key, this.overrideBody, this.initialIndex});

  @override
  State<HomeContainerPage> createState() => _HomeContainerPageState();
}

class _HomeContainerPageState extends State<HomeContainerPage> {
  int _currentIndex = 0;
  String? _tempUserName;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final name = await UserIdStorage.getOrCreateTempUserId();

    setState(() {
      _tempUserName = name;

      // Build pages once username is loaded
      _pages = [
        const StartChatPage(),
        // FriendsPage(userId: name),
        // ShopPage(), // Shop
        SettingsPage(), // Settings
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tempUserName == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body:
          widget.overrideBody != null &&
                  _currentIndex == (widget.initialIndex ?? 0)
              ? widget.overrideBody!
              : _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) async {
          // If leaving the "Find" tab (index 0), remove user from waitingQueue
          if (_currentIndex == 0 && index != 0 && _tempUserName != null) {
            await _firestoreService.leaveWaitingQueue(_tempUserName!);
          }

          setState(() {
            _currentIndex = index;
          });
        },

        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Find'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
