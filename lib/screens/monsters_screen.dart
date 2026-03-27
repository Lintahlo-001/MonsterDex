import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:monsterdex/services/permission_service.dart';
import 'package:monsterdex/widgets/app_snackbar.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/tailscale_service.dart';
import 'monster_form_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MonstersScreen extends StatefulWidget {
  final int playerId;

  const MonstersScreen({super.key, required this.playerId});

  @override
  State<MonstersScreen> createState() => _MonstersScreenState();
}

class _MonstersScreenState extends State<MonstersScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _monsters = [];
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
    _loadMonsters();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMonsters() async {
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
    final raw = await ApiService.get('/monsters');
    if (mounted) {
      setState(() {
        _monsters = raw is List ? List<dynamic>.from(raw) : [];
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = 'Failed to load monsters. Check your connection.';
        _loading = false;
      });
    }
  }
  }

  Future<void> _deleteMonster(int monsterId, String name) async {
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
                  border: Border.all(color: AppTheme.danger, width: 1.5),
                ),
                child: const Icon(Icons.delete_outline,
                    color: AppTheme.danger, size: 26),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Monster',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'ComicRelief',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "$name"?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSub, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSub,
                        side: BorderSide(
                            color: AppTheme.textSub.withOpacity(0.4)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Delete'),
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
      await ApiService.delete('/monsters/$monsterId');
      if (mounted) AppSnackbar.success(context, '$name deleted.');
      _loadMonsters();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Failed to delete monster.');
    }
  }

  Future<void> _goToForm({Map<String, dynamic>? monster}) async {
    final ok = await TailscaleService.guardAction(context);
    if (!ok) return;

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MonsterFormScreen(monster: monster),
        ),
      );
      _loadMonsters();
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
          const Text(
            'Monsters',
            style: TextStyle(
              fontFamily: 'ComicRelief',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppTheme.textWhite,
            ),
          ),
          Text(
            '${_monsters.length} registered',
            style: const TextStyle(
              color: AppTheme.textSub,
              fontSize: 12,
              fontFamily: 'ComicRelief',
            ),
          ),
        ],
      ),
      actions: [
        // Map icon
        IconButton(
          onPressed: () async {
            final ok = await TailscaleService.guardAction(context);
            if (!ok) return;
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MonsterMapScreen(
                      monsters: _monsters),
                ),
              );
            }
          },
          icon: const Icon(Icons.map_outlined,
              color: AppTheme.accentBlue),
          tooltip: 'Map',
        ),
        // Add icon
        IconButton(
          onPressed: () => _goToForm(),
          icon: const Icon(Icons.add_circle_outline,
              color: AppTheme.accentCyan),
          tooltip: 'Add Monster',
        ),
        // Reload
        IconButton(
          onPressed: _loadMonsters,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accentBlue,
                  ),
                )
              : const Icon(Icons.refresh, color: AppTheme.accentBlue),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentBlue),
      );
    }
    if (_error != null) return _buildError();
    if (_monsters.isEmpty) return _buildEmpty();
    return _buildList();
  }

  Widget _buildList() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _monsters.length,
        itemBuilder: (context, index) {
          final monster = _monsters[index];
          return _buildMonsterCard(monster, index);
        },
      ),
    );
  }

  Widget _buildMonsterCard(dynamic monster, int index) {
    final String name = monster['monster_name'] ?? 'Unknown';
    final String type = monster['monster_type'] ?? '';
    final String? pictureUrl = monster['picture_url'];
    final int monsterId = monster['monster_id'];
    final double radius =
        double.tryParse(monster['spawn_radius_meters'].toString()) ??
            100.0;
    final Color typeCol = AppTheme.typeColor(type);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.cardDecoration,
        child: Column(
          children: [
            Row(
              children: [
                // Monster image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                  ),
                  child: Container(
                    width: 90,
                    height: 90,
                    color: AppTheme.bgMid,
                    child: pictureUrl != null && pictureUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: pictureUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.accentBlue,
                              ),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.catching_pokemon,
                              color: AppTheme.accentBlue,
                              size: 40,
                            ),
                          )
                        : const Icon(
                            Icons.catching_pokemon,
                            color: AppTheme.accentBlue,
                            size: 40,
                          ),
                  ),
                ),

                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 6),
                        // Type image
                        _buildTypeBadge(type),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.radar,
                                color: AppTheme.textSub, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Radius: ${radius.toStringAsFixed(0)}m',
                              style: const TextStyle(
                                color: AppTheme.textSub,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Edit / Delete buttons
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    children: [
                      _actionButton(
                        icon: Icons.edit_outlined,
                        color: AppTheme.accentBlue,
                        onTap: () => _goToForm(
                            monster:
                                Map<String, dynamic>.from(monster)),
                      ),
                      const SizedBox(height: 8),
                      _actionButton(
                        icon: Icons.delete_outline,
                        color: AppTheme.danger,
                        onTap: () => _deleteMonster(monsterId, name),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom strip — spawn location
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: typeCol.withOpacity(0.06),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(
                      color: typeCol.withOpacity(0.2), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      color: typeCol, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Spawn: ${double.tryParse(monster['spawn_latitude'].toString())?.toStringAsFixed(5) ?? '?'}, '
                    '${double.tryParse(monster['spawn_longitude'].toString())?.toStringAsFixed(5) ?? '?'}',
                    style: TextStyle(
                      color: typeCol.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(
        'assets/images/types/${type.toLowerCase()}.png',
        height: 22,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackBadge(type),
      ),
    );
  }

  Widget _fallbackBadge(String type) {
    final color = AppTheme.typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
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

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardStart,
              border: Border.all(
                  color: AppTheme.borderColor.withOpacity(0.4)),
            ),
            child: const Icon(Icons.catching_pokemon,
                color: AppTheme.textSub, size: 44),
          ),
          const SizedBox(height: 20),
          const Text(
            'No monsters registered!',
            style: TextStyle(
              color: AppTheme.textWhite,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'ComicRelief',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add one using the + button above',
            style: TextStyle(color: AppTheme.textSub, fontSize: 14),
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
              onPressed: _loadMonsters,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class MonsterMapScreen extends StatefulWidget {
  final List<dynamic> monsters;
  const MonsterMapScreen({super.key, required this.monsters});

  @override
  State<MonsterMapScreen> createState() => _MonsterMapScreenState();
}

class _MonsterMapScreenState extends State<MonsterMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _locating = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _locating = true);
    final granted = await PermissionService.requestLocationPermission();
    if (!granted) {
      setState(() => _locating = false);
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final loc = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentLocation = loc;
          _locating = false;
        });
        _mapController.move(loc, 16);
      }
    } catch (_) {
      setState(() => _locating = false);
    }
  }

  List<Marker> _buildMarkers() {
    return widget.monsters.map<Marker>((m) {
      final lat = double.tryParse(m['spawn_latitude'].toString()) ?? 0;
      final lng = double.tryParse(m['spawn_longitude'].toString()) ?? 0;
      final type = (m['monster_type'] ?? '') as String;
      final name = (m['monster_name'] ?? '') as String;

      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/types/${type.toLowerCase()}.png',
                        height: 28,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'ComicRelief',
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$lat, $lng',
                        style: const TextStyle(
                            color: AppTheme.textSub, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Icon(
            Icons.location_on,
            color: AppTheme.typeColor(type),
            size: 36,
          ),
        ),
      );
    }).toList();
  }

  List<CircleMarker> _buildCircles() {
    return widget.monsters.map<CircleMarker>((m) {
      final lat = double.tryParse(m['spawn_latitude'].toString()) ?? 0;
      final lng = double.tryParse(m['spawn_longitude'].toString()) ?? 0;
      final radius =
          double.tryParse(m['spawn_radius_meters'].toString()) ?? 100;
      final type = (m['monster_type'] ?? '') as String;

      return CircleMarker(
        point: LatLng(lat, lng),
        radius: radius,
        useRadiusInMeter: true,
        color: AppTheme.typeColor(type).withOpacity(0.15),
        borderColor: AppTheme.typeColor(type),
        borderStrokeWidth: 1.5,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMid,
        title: Text(
          'Monster Map (${widget.monsters.length})',
          style: const TextStyle(
              fontFamily: 'ComicRelief', fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _locating ? null : _getCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accentBlue))
                : const Icon(Icons.my_location,
                    color: AppTheme.accentBlue),
            tooltip: 'My location',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: LatLng(15.1490, 120.5960),
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.haumonsters.app',
          ),
          CircleLayer(circles: _buildCircles()),
          MarkerLayer(markers: _buildMarkers()),
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation!,
                  width: 40,
                  height: 40,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentBlue,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentBlue.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}