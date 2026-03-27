import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/tailscale_service.dart';
import '../widgets/app_snackbar.dart';
import 'catch_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int playerId;
  final String playerName;

  const DashboardScreen({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _catches = [];
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
    _loadCatches();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // GMT+8 formatter
  String _formatDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toUtc().add(
            const Duration(hours: 8),
          );
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final y = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$d/$mo/$y  $h:$mi';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _loadCatches() async {
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
      final raw = await ApiService.get('/catches/${widget.playerId}');
      if (mounted) {
        setState(() {
          _catches =
              raw is List ? List<dynamic>.from(raw) : [];
          _loading = false;
        });
        _animCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load catches. Check your connection.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteCatch(
      int catchId, String monsterName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.danger.withOpacity(0.15),
                  border: Border.all(
                      color: AppTheme.danger, width: 1.5),
                ),
                child: const Icon(Icons.delete_outline,
                    color: AppTheme.danger, size: 26),
              ),
              const SizedBox(height: 16),
              const Text(
                'Release Monster',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'ComicRelief',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Release "$monsterName" back into the wild?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSub, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSub,
                        side: BorderSide(
                            color:
                                AppTheme.textSub.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                      child: const Text('Release'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    final ok = await TailscaleService.guardAction(context);
    if (!ok) return;

    try {
      await ApiService.delete('/catches/$catchId');
      if (mounted) {
        AppSnackbar.success(
            context, '$monsterName released!');
        _loadCatches();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
            context, 'Failed to release monster.');
      }
    }
  }

  void _showCatchDetail(dynamic catch_) {
    final String name = catch_['monster_name'] ?? 'Unknown';
    final String type = catch_['monster_type'] ?? '';
    final String? pictureUrl = catch_['picture_url'];
    final String datetime =
        _formatDateTime(catch_['catch_datetime'] ?? '');
    final double lat =
        double.tryParse(catch_['latitude'].toString()) ?? 0;
    final double lng =
        double.tryParse(catch_['longitude'].toString()) ?? 0;
    final Color typeCol = AppTheme.typeColor(type);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppTheme.bgMid,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
                color: typeCol.withOpacity(0.5), width: 2),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSub.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Image + name row
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: AppTheme.bgDark,
                    child: pictureUrl != null &&
                            pictureUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: pictureUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.catching_pokemon,
                              color: typeCol,
                              size: 40,
                            ),
                          )
                        : Icon(
                            Icons.catching_pokemon,
                            color: typeCol,
                            size: 40,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'ComicRelief',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Image.asset(
                        'assets/images/types/${type.toLowerCase()}.png',
                        height: 24,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 16),

            // Info rows
            _detailRow(
              Icons.access_time,
              'Caught At',
              datetime,
              typeCol,
            ),
            const SizedBox(height: 12),
            _detailRow(
              Icons.location_on_outlined,
              'Catch Location',
              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
              typeCol,
            ),
            const SizedBox(height: 12),
            _detailRow(
              Icons.tag,
              'Catch ID',
              '#${catch_['catch_id']}',
              typeCol,
            ),

            const SizedBox(height: 24),

            // Release button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteCatch(
                      catch_['catch_id'], name);
                },
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.danger),
                label: const Text(
                  'RELEASE MONSTER',
                  style: TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    fontFamily: 'ComicRelief',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(
                      color: AppTheme.danger, width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            SizedBox(
                height:
                    MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSub,
                  fontSize: 11,
                  letterSpacing: 1,
                  fontFamily: 'ComicRelief',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'ComicRelief',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _goToCatch() async {
    final ok = await TailscaleService.guardAction(context);
    if (!ok) return;

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CatchScreen(playerId: widget.playerId),
        ),
      );
      _loadCatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.bgMid,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hey, ${widget.playerName}!',
            style: const TextStyle(
              fontFamily: 'ComicRelief',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppTheme.textWhite,
            ),
          ),
          Text(
            '${_catches.length} monster${_catches.length == 1 ? '' : 's'} caught',
            style: const TextStyle(
              color: AppTheme.textSub,
              fontSize: 12,
              fontFamily: 'ComicRelief',
            ),
          ),
        ],
      ),
      actions: [
        _buildVpnStatus(),
        IconButton(
          onPressed: _loadCatches,
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
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildVpnStatus() {
    return FutureBuilder<bool>(
      future: TailscaleService.isConnected(),
      builder: (context, snap) {
        final connected = snap.data ?? false;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (connected
                      ? AppTheme.success
                      : AppTheme.danger)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (connected
                        ? AppTheme.success
                        : AppTheme.danger)
                    .withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected
                        ? AppTheme.success
                        : AppTheme.danger,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  connected ? 'VPN' : 'No VPN',
                  style: TextStyle(
                    color: connected
                        ? AppTheme.success
                        : AppTheme.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Positioned(
          top: -40,
          right: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentBlue.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(
                color: AppTheme.accentBlue),
          )
        else if (_error != null)
          _buildError()
        else if (_catches.isEmpty)
          _buildEmpty()
        else
          _buildCatchList(),

        // FAB — only when catches exist
        if (!_loading && _catches.isNotEmpty)
          Positioned(
            bottom: 90,
            right: 20,
            child: _buildCatchFAB(),
          ),
      ],
    );
  }

  Widget _buildCatchList() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView.builder(
        padding:
            const EdgeInsets.fromLTRB(16, 16, 16, 160),
        itemCount: _catches.length,
        itemBuilder: (context, index) {
          final catch_ = _catches[index];
          return _buildCatchCard(catch_, index);
        },
      ),
    );
  }

  Widget _buildCatchCard(dynamic catch_, int index) {
    final String name = catch_['monster_name'] ?? 'Unknown';
    final String type = catch_['monster_type'] ?? '';
    final String? pictureUrl = catch_['picture_url'];
    final String datetime =
        _formatDateTime(catch_['catch_datetime'] ?? '');
    final Color typeCol = AppTheme.typeColor(type);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () => _showCatchDetail(catch_),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppTheme.cardStart,
                AppTheme.cardEnd
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            // Type-colored border
            border: Border.all(
                color: typeCol.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: typeCol.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              // Monster image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppTheme.bgMid,
                  child: pictureUrl != null &&
                          pictureUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: pictureUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentBlue,
                            ),
                          ),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.catching_pokemon,
                            color: typeCol,
                            size: 36,
                          ),
                        )
                      : Icon(
                          Icons.catching_pokemon,
                          color: typeCol,
                          size: 36,
                        ),
                ),
              ),

              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'ComicRelief',
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildTypeBadge(type),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              color: typeCol.withOpacity(0.7),
                              size: 11),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              datetime,
                              style: TextStyle(
                                color:
                                    AppTheme.textSub,
                                fontSize: 11,
                              ),
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Tap hint
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: typeCol.withOpacity(0.1),
                        border: Border.all(
                            color: typeCol.withOpacity(0.4)),
                      ),
                      child: Icon(Icons.info_outline,
                          color: typeCol, size: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(
        'assets/images/types/${type.toLowerCase()}.png',
        height: 20,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            _fallbackBadge(type),
      ),
    );
  }

  Widget _fallbackBadge(String type) {
    final color = AppTheme.typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border:
            Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          fontFamily: 'ComicRelief',
        ),
      ),
    );
  }

  Widget _buildCatchFAB() {
    return GestureDetector(
      onTap: _goToCatch,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppTheme.accentBlue,
              AppTheme.accentCyan
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentBlue.withOpacity(0.5),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.catching_pokemon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardStart,
              border: Border.all(
                  color:
                      AppTheme.borderColor.withOpacity(0.4)),
            ),
            child: const Icon(Icons.catching_pokemon,
                color: AppTheme.textSub, size: 50),
          ),
          const SizedBox(height: 20),
          const Text(
            'No monsters caught yet!',
            style: TextStyle(
              color: AppTheme.textWhite,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'ComicRelief',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Go outside and start hunting',
            style: TextStyle(
                color: AppTheme.textSub, fontSize: 14),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _goToCatch,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppTheme.accentBlue,
                    AppTheme.accentCyan
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color:
                        AppTheme.accentBlue.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Text(
                'START HUNTING',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 2,
                  fontFamily: 'ComicRelief',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off,
                color: AppTheme.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSub, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCatches,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}