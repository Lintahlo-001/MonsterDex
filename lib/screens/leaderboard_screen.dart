import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/tailscale_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _leaders = [];
  bool _loading = true;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await TailscaleService.guardAction(context);
    if (!ok) {
      setState(() => _loading = false);
      return;
    }

    try {
      final data = await ApiService.get('/leaderboard');
      if (mounted) {
        setState(() {
          _leaders = data is List ? List<dynamic>.from(data) : [];
          _loading = false;
        });
        _animCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load leaderboard.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMid,
        elevation: 0,
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            fontFamily: 'ComicRelief',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadLeaderboard,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentBlue,
                    ),
                  )
                : const Icon(Icons.refresh,
                    color: AppTheme.accentBlue),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppTheme.accentBlue),
            )
          : _error != null
              ? _buildError()
              : _leaders.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildList() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          // Podium — show whatever top players exist (1, 2, or 3)
          if (_leaders.isNotEmpty) _buildPodium(),
          const SizedBox(height: 24),

          // Rest of the list from rank 4 onward
          if (_leaders.length > 3)
            ...List.generate(
              _leaders.length - 3,
              (i) => _buildRankRow(_leaders[i + 3], i + 4),
            ),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    final first = _leaders[0];
    final second = _leaders.length > 1 ? _leaders[1] : null;
    final third = _leaders.length > 2 ? _leaders[2] : null;

    // Only 1 player
    if (second == null) {
      return Center(child: _buildPodiumTile(first, 1, 130));
    }

    // Only 2 players
    if (third == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _buildPodiumTile(second, 2, 100)),
          const SizedBox(width: 8),
          Expanded(child: _buildPodiumTile(first, 1, 130)),
        ],
      );
    }

    // Full 3-player podium
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _buildPodiumTile(second, 2, 100)),
        const SizedBox(width: 8),
        Expanded(child: _buildPodiumTile(first, 1, 130)),
        const SizedBox(width: 8),
        Expanded(child: _buildPodiumTile(third, 3, 80)),
      ],
    );
  }
  Widget _buildPodiumTile(
      dynamic player, int rank, double height) {
    final colors = {
      1: const Color(0xFFFFD700),
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };
    final color = colors[rank] ?? AppTheme.accentBlue;
    final name = player['player_name'] ?? '';
    final catches = player['total_catches'] ?? 0;

    return Column(
      children: [
        // Crown for 1st
        if (rank == 1)
          const Text('👑', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 4),

        // Avatar
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'ComicRelief',
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'ComicRelief',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$catches caught',
          style: const TextStyle(
              color: AppTheme.textSub, fontSize: 11),
        ),
        const SizedBox(height: 6),

        // Podium block
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'ComicRelief',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankRow(dynamic player, int rank) {
    final name = player['player_name'] ?? '';
    final username = player['username'] ?? '';
    final catches = player['total_catches'] ?? 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (rank * 40)),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - v)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: AppTheme.cardDecoration,
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 32,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: AppTheme.textSub,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'ComicRelief',
                ),
              ),
            ),
            // Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    AppTheme.accentBlue,
                    AppTheme.accentCyan
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'ComicRelief',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ComicRelief',
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: AppTheme.textSub,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Catches
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$catches',
                  style: const TextStyle(
                    color: AppTheme.accentCyan,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'ComicRelief',
                  ),
                ),
                const Text(
                  'caught',
                  style: TextStyle(
                    color: AppTheme.textSub,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined,
              color: AppTheme.textSub, size: 48),
          SizedBox(height: 16),
          Text(
            'No catches yet!',
            style: TextStyle(
              color: AppTheme.textWhite,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'ComicRelief',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Be the first to catch a monster',
            style:
                TextStyle(color: AppTheme.textSub, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off,
              color: AppTheme.danger, size: 48),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(
                color: AppTheme.textSub, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadLeaderboard,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}