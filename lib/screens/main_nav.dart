import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../constants/theme.dart';
import 'dashboard_screen.dart';
import 'monsters_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';

class MainNav extends StatefulWidget {
  final int playerId;
  final String playerName;
  final String username;

  const MainNav({
    super.key,
    required this.playerId,
    required this.playerName,
    required this.username,
  });

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> with TickerProviderStateMixin {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  // One AnimationController per tab for the slide+fade
  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _slideAnims;
  late final List<Animation<double>> _fadeAnims;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.catching_pokemon_outlined,
        activeIcon: Icons.catching_pokemon, label: 'Hunt'),
    _NavItem(icon: Icons.museum_outlined,
        activeIcon: Icons.museum, label: 'Monsters'),
    _NavItem(icon: Icons.leaderboard_outlined,
        activeIcon: Icons.leaderboard, label: 'Ranks'),
    _NavItem(icon: Icons.settings_outlined,
        activeIcon: Icons.settings, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();

    _pages = [
      DashboardScreen(
          playerId: widget.playerId, playerName: widget.playerName),
      MonstersScreen(playerId: widget.playerId),
      const LeaderboardScreen(),
      SettingsScreen(
          playerId: widget.playerId, username: widget.username,
          playerName: widget.playerName),
    ];

    _controllers = List.generate(
      4,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      ),
    );

    _slideAnims = List.generate(4, (i) {
      return Tween<Offset>(
        begin: Offset.zero,
        end: Offset.zero,
      ).animate(_controllers[i]);
    });

    _fadeAnims = List.generate(4, (i) {
      return CurvedAnimation(
        parent: _controllers[i],
        curve: Curves.easeOut,
      );
    });

    // Animate the first page in
    _slideAnims[0] = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controllers[0],
      curve: Curves.easeOutCubic,
    ));
    _controllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();

    final bool goingRight = index > _currentIndex;

    // Animate current page OUT (slide away)
    _slideAnims[_currentIndex] = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(goingRight ? -0.06 : 0.06, 0),
    ).animate(CurvedAnimation(
      parent: _controllers[_currentIndex],
      curve: Curves.easeInCubic,
    ));

    // Animate new page IN (slide from direction)
    _slideAnims[index] = Tween<Offset>(
      begin: Offset(goingRight ? 0.06 : -0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controllers[index],
      curve: Curves.easeOutCubic,
    ));

    _controllers[_currentIndex].reverse();

    setState(() {
      _currentIndex = index;
    });

    _controllers[index].forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      extendBody: true, // lets content go behind the glass navbar
      body: Stack(
        children: [
          // Pages — only build active page with animation
          for (int i = 0; i < _pages.length; i++)
            Offstage(
              offstage: _currentIndex != i,
              child: FadeTransition(
                opacity: _fadeAnims[i],
                child: SlideTransition(
                  position: _slideAnims[i],
                  child: _pages[i],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildGlassNavBar(),
    );
  }

  Widget _buildGlassNavBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgMid.withOpacity(0.6),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: AppTheme.borderColor.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  _navItems.length,
                  (i) => _buildNavItem(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.accentBlue.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(
                  color: AppTheme.accentBlue.withOpacity(0.4), width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                key: ValueKey(isActive),
                color: isActive ? AppTheme.accentCyan : AppTheme.textSub,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isActive ? AppTheme.accentCyan : AppTheme.textSub,
                fontSize: 11,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.normal,
                fontFamily: 'ComicRelief',
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}