import 'package:flutter/material.dart';
import 'start_chat_page.dart';
import 'friends_page.dart'; // import your FriendsPage
import '../services/temp_user_manager.dart';

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
    final name = await TempUserManager.getOrCreateTempUsername();
    setState(() {
      _tempUserName = name;

      // Build pages once username is loaded
      _pages = [
        const StartChatPage(),
        FriendsPage(userId: name),
        const Placeholder(), // Settings
        const Placeholder(), // Shop
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
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Find'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Friends'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Shop',
          ),
        ],
      ),
    );
  }
}
