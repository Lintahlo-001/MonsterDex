import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final playerId = prefs.getInt('player_id');
  final playerName = prefs.getString('player_name');
  final username = prefs.getString('username');

  final bool isLoggedIn =
      playerId != null && playerName != null && username != null;

  runApp(HAUMonstersApp(
    isLoggedIn: isLoggedIn,
    playerId: playerId,
    playerName: playerName,
    username: username,
  ));
}

class HAUMonstersApp extends StatelessWidget {
  final bool isLoggedIn;
  final int? playerId;
  final String? playerName;
  final String? username;

  const HAUMonstersApp({
    super.key,
    required this.isLoggedIn,
    this.playerId,
    this.playerName,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HAU Monsters',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: isLoggedIn
          ? MainNav(
              playerId: playerId!,
              playerName: playerName!,
              username: username!,
            )
          : const WelcomeScreen(),
    );
  }
}