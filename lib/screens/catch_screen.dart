import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/tailscale_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_snackbar.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:torch_light/torch_light.dart';

class CatchScreen extends StatefulWidget {
  final int playerId;
  const CatchScreen({super.key, required this.playerId});

  @override
  State<CatchScreen> createState() => _CatchScreenState();
}

class _CatchScreenState extends State<CatchScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  List<dynamic> _nearbyMonsters = [];
  List<dynamic> _allMonsters = [];
  List<int> _caughtIds = [];
  bool _scanning = false;
  bool _locating = false;
  bool _initializing = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _flashActive = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _init();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _audioPlayer.dispose();
    if (_flashActive) {
      TorchLight.disableTorch().catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _init() async {
    await _loadAllMonsters();
    await _getCurrentLocation();
    setState(() => _initializing = false);
  }

  Future<void> _loadAllMonsters() async {
    try {
      final data = await ApiService.get('/monsters');
      if (mounted) {
        setState(() {
          _allMonsters = data is List ? List<dynamic>.from(data) : [];
        });
      }
    } catch (_) {}
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _locating = true);

    final granted =
        await PermissionService.requestLocationPermission();
    if (!granted) {
      setState(() => _locating = false);
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentLocation = loc;
          _locating = false;
        });
        _mapController.move(loc, 16);
        // Auto scan after getting location
        await _scan(loc);
      }
    } catch (e) {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _scan(LatLng location) async {
    setState(() => _scanning = true);
    HapticFeedback.mediumImpact();

    try {
      final raw = await ApiService.post('/scan', {
        'latitude': location.latitude,
        'longitude': location.longitude,
      });

      // Explicit cast to List
      final List<dynamic> nearby = raw is List ? List<dynamic>.from(raw) : [];

      // Filter out already caught ones this session
      final filtered = nearby
          .where((m) => !_caughtIds.contains(m['monster_id']))
          .toList();

      if (mounted) {
        setState(() {
          _nearbyMonsters = filtered;
          _scanning = false;
        });

        if (filtered.isEmpty) {
          AppSnackbar.error(context, 'No monsters nearby. Keep exploring!');
        } else {
          AppSnackbar.success(
            context,
            '${filtered.length} monster${filtered.length > 1 ? 's' : ''} detected nearby!',
          );
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        AppSnackbar.error(context, 'Scan failed. Check connection.');
      }
    }
  }

  Future<void> _catchMonster(Map<String, dynamic> monster) async {
    final ok = await TailscaleService.guardAction(context);
    if (!ok) return;

    if (_currentLocation == null) return;

    final monsterId = monster['monster_id'];
    final monsterName = monster['monster_name'];

    try {
      await ApiService.post('/catch', {
        'player_id': widget.playerId,
        'monster_id': monsterId,
        'latitude': _currentLocation!.latitude,
        'longitude': _currentLocation!.longitude,
      });

      // Trigger effects — don't await so UI updates immediately
      _triggerCatchEffects();

      setState(() {
        _caughtIds.add(monsterId);
        _nearbyMonsters
            .removeWhere((m) => m['monster_id'] == monsterId);
      });

      if (mounted) {
        AppSnackbar.gotcha(context, monsterName);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to catch $monsterName.');
      }
    }
  }

  Future<void> _triggerCatchEffects() async {
    // Play sound
    try {
      await _audioPlayer.play(AssetSource('sounds/gotcha.mp3'));
    } catch (_) {}

    // Flashlight strobe for 5 seconds
    try {
      final hasTorch = await TorchLight.isTorchAvailable();
      if (!hasTorch) return;

      setState(() => _flashActive = true);

      // Strobe: on/off every 200ms for 5 seconds = 12 cycles
      for (int i = 0; i < 12; i++) {
        if (!mounted || !_flashActive) break;
        await TorchLight.enableTorch();
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted || !_flashActive) break;
        await TorchLight.disableTorch();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Make sure torch is off at end
      await TorchLight.disableTorch();
      if (mounted) setState(() => _flashActive = false);
    } catch (_) {
      if (mounted) setState(() => _flashActive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMid,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Catch Monsters',
              style: TextStyle(
                fontFamily: 'ComicRelief',
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            if (_nearbyMonsters.isNotEmpty)
              Text(
                '${_nearbyMonsters.length} monster${_nearbyMonsters.length > 1 ? 's' : ''} nearby!',
                style: const TextStyle(
                  color: AppTheme.accentCyan,
                  fontSize: 12,
                  fontFamily: 'ComicRelief',
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _locating ? null : _getCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentBlue,
                    ),
                  )
                : const Icon(Icons.my_location,
                    color: AppTheme.accentBlue),
            tooltip: 'Get my location',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _initializing
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.accentBlue),
            )
          : Column(
              children: [
                // Map
                Expanded(
                  flex: 3,
                  child: _buildMap(),
                ),
                // Monster list
                if (_nearbyMonsters.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: _buildNearbyList(),
                  )
                else
                  _buildEmptyPanel(),
              ],
            ),
    floatingActionButton: _currentLocation != null
        ? Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton.extended(
              onPressed: _scanning ? null : () => _scan(_currentLocation!),
              backgroundColor: _scanning ? AppTheme.bgMid : AppTheme.accentBlue,
              icon: _scanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppTheme.accentCyan,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.radar, color: Colors.white),
              label: Text(
                _scanning ? 'Scanning...' : 'SCAN AREA',
                style: const TextStyle(
                  fontFamily: 'ComicRelief',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          )
        : null,
    );
  }

  Widget _buildMap() {
    // Build markers for all monsters
    final allMarkers = _allMonsters.map((m) {
      final lat =
          double.tryParse(m['spawn_latitude'].toString()) ?? 0;
      final lng =
          double.tryParse(m['spawn_longitude'].toString()) ?? 0;
      final type = m['monster_type'] ?? '';
      final mId = m['monster_id'];
      final isCaught = _caughtIds.contains(mId);
      final isNearby = _nearbyMonsters
          .any((n) => n['monster_id'] == mId);

      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Icon(
            Icons.location_on,
            color: isCaught
                ? AppTheme.textSub
                : isNearby
                    ? AppTheme.accentCyan
                    : AppTheme.typeColor(type),
            size: isNearby ? 36 * _pulseAnim.value + 4 : 32,
          ),
        ),
      );
    }).toList();

    // Radius circles for all monsters
    final circles = _allMonsters.map((m) {
      final lat =
          double.tryParse(m['spawn_latitude'].toString()) ?? 0;
      final lng =
          double.tryParse(m['spawn_longitude'].toString()) ?? 0;
      final radius =
          double.tryParse(m['spawn_radius_meters'].toString()) ??
              100;
      final type = m['monster_type'] ?? '';
      final mId = m['monster_id'];
      final isCaught = _caughtIds.contains(mId);

      return CircleMarker(
        point: LatLng(lat, lng),
        radius: radius,
        useRadiusInMeter: true,
        color: isCaught
            ? AppTheme.textSub.withOpacity(0.05)
            : AppTheme.typeColor(type).withOpacity(0.15),
        borderColor: isCaught
            ? AppTheme.textSub.withOpacity(0.3)
            : AppTheme.typeColor(type).withOpacity(0.6),
        borderStrokeWidth: 1.5,
      );
    }).toList();

    // Player marker
    final playerMarkers = _currentLocation != null
        ? [
            Marker(
              point: _currentLocation!,
              width: 50,
              height: 50,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 40 * _pulseAnim.value,
                      height: 40 * _pulseAnim.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentBlue
                            .withOpacity(0.2 * _pulseAnim.value),
                      ),
                    ),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentBlue,
                        border: Border.all(
                            color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentBlue
                                .withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]
        : <Marker>[];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter:
            _currentLocation ?? const LatLng(15.1490, 120.5960),
        initialZoom: 16,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.haumonsters.app',
        ),
        CircleLayer(circles: circles),
        MarkerLayer(markers: allMarkers),
        MarkerLayer(markers: playerMarkers),
      ],
    );
  }

  Widget _buildNearbyList() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgMid,
        border: Border(
          top: BorderSide(
              color: AppTheme.accentCyan.withOpacity(0.4),
              width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentCyan,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentCyan.withOpacity(0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'MONSTERS IN RANGE',
                  style: TextStyle(
                    color: AppTheme.accentCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontFamily: 'ComicRelief',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              itemCount: _nearbyMonsters.length,
              itemBuilder: (context, i) =>
                  _buildNearbyCard(_nearbyMonsters[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyCard(dynamic monster) {
    final name = monster['monster_name'] ?? 'Unknown';
    final type = monster['monster_type'] ?? '';
    final String? pictureUrl = monster['picture_url'];
    final typeColor = AppTheme.typeColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            typeColor.withOpacity(0.1),
            AppTheme.cardEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Container(
              width: 64,
              height: 64,
              color: AppTheme.bgMid,
              child: pictureUrl != null && pictureUrl.isNotEmpty
                  ? Image.network(
                      pictureUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.catching_pokemon,
                        color: typeColor,
                        size: 30,
                      ),
                    )
                  : Icon(
                      Icons.catching_pokemon,
                      color: typeColor,
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Image.asset(
                  'assets/images/types/${type.toLowerCase()}.png',
                  height: 18,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    type.toUpperCase(),
                    style: TextStyle(
                        color: typeColor, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          // Catch button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () =>
                  _catchMonster(Map<String, dynamic>.from(monster)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [typeColor, typeColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: typeColor.withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Text(
                  'CATCH!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1,
                    fontFamily: 'ComicRelief',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      decoration: BoxDecoration(
        color: AppTheme.bgMid,
        border: Border(
          top: BorderSide(
              color: AppTheme.borderColor.withOpacity(0.3),
              width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar,
              color: AppTheme.textSub.withOpacity(0.5),
              size: 20),
          const SizedBox(width: 10),
          Text(
            _currentLocation == null
                ? 'Getting your location...'
                : 'No monsters in range. Tap SCAN AREA!',
            style: const TextStyle(
                color: AppTheme.textSub, fontSize: 13),
          ),
        ],
      ),
    );
  }
}