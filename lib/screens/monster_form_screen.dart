import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:monsterdex/services/permission_service.dart';
import 'package:monsterdex/widgets/app_snackbar.dart';
import 'dart:convert';
import 'dart:io';
import '../constants/theme.dart';
import '../constants/api.dart';
import '../services/api_service.dart';
import '../services/tailscale_service.dart';

class MonsterFormScreen extends StatefulWidget {
  final Map<String, dynamic>? monster;

  const MonsterFormScreen({super.key, this.monster});

  @override
  State<MonsterFormScreen> createState() => _MonsterFormScreenState();
}

class _MonsterFormScreenState extends State<MonsterFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _pictureCtrl = TextEditingController();
  final _mapController = MapController();

  String? _selectedType;
  LatLng? _spawnLocation;

  bool _loading = false;
  bool _locating = false;
  bool _uploadingImage = false;
  String? _errorMessage;

  XFile? _pickedImage;

  bool get _isEditing => widget.monster != null;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // Default center — HAU Angeles City
  static const LatLng _defaultCenter = LatLng(15.1490, 120.5960);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    if (_isEditing) {
      final m = widget.monster!;
      _nameCtrl.text = m['monster_name'] ?? '';
      _selectedType = m['monster_type'];
      _radiusCtrl.text =
          (m['spawn_radius_meters'] ?? '100').toString();
      _pictureCtrl.text = m['picture_url'] ?? '';
      final lat =
          double.tryParse(m['spawn_latitude'].toString()) ?? 0;
      final lng =
          double.tryParse(m['spawn_longitude'].toString()) ?? 0;
      _spawnLocation = LatLng(lat, lng);
    } else {
      _radiusCtrl.text = '100';
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _radiusCtrl.dispose();
    _pictureCtrl.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _locating = true);

    final granted = await PermissionService.requestLocationPermission();
    if (!granted) {
      setState(() {
        _locating = false;
        _errorMessage = 'Location permission denied. Please allow it in Settings.';
      });
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _spawnLocation = loc;
        _locating = false;
      });
      _mapController.move(loc, 16);
    } catch (e) {
      setState(() {
        _locating = false;
        _errorMessage = 'Could not get location. Make sure GPS is on.';
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    // Request permission first
    final granted = await PermissionService.requestImagePermission();
    if (!granted) {
      setState(() =>
          _errorMessage = 'Storage permission denied. Please allow it in Settings.');
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _pickedImage = picked;
      _uploadingImage = true;
    });

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('image', picked.path),
      );
      final response = await request.send();

      print('STATUS: ${response.statusCode}');

      final body = await response.stream.bytesToString();
      print('BODY: $body');

      final data = jsonDecode(body);
      if (data['url'] != null) {
        setState(() {
          _pictureCtrl.text = data['url'];
          _uploadingImage = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Upload failed: ${data['error']}';
          _uploadingImage = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Image upload failed. Check connection.';
        _uploadingImage = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      setState(
          () => _errorMessage = 'Please select a monster type.');
      return;
    }
    if (_spawnLocation == null) {
      setState(() =>
          _errorMessage = 'Please set a spawn location on the map.');
      return;
    }

    final ok = await TailscaleService.guardAction(context);
    if (!ok) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final body = {
      'monster_name': _nameCtrl.text.trim(),
      'monster_type': _selectedType,
      'spawn_latitude': _spawnLocation!.latitude,
      'spawn_longitude': _spawnLocation!.longitude,
      'spawn_radius_meters':
          double.tryParse(_radiusCtrl.text) ?? 100.0,
      'picture_url': _pictureCtrl.text.trim().isEmpty
          ? null
          : _pictureCtrl.text.trim(),
    };

    try {
      if (_isEditing) {
        await ApiService.put(
            '/monsters/${widget.monster!['monster_id']}', body);
      } else {
        await ApiService.post('/monsters', body);
      }
      if (mounted) {
        AppSnackbar.success(
          context,
          _isEditing ? 'Monster updated!' : 'Monster added!',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save. Check your connection.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMid,
        title: Text(
          _isEditing ? 'Edit Monster' : 'Add Monster',
          style: const TextStyle(
            fontFamily: 'ComicRelief',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Basic Info ──────────────────────────────
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('MONSTER INFO'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(
                            color: AppTheme.textWhite),
                        decoration: const InputDecoration(
                          labelText: 'Monster Name',
                          prefixIcon: Icon(
                              Icons.catching_pokemon_outlined),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Enter a name'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTypeDropdown(),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Image Upload ────────────────────────────
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('MONSTER IMAGE'),
                      const SizedBox(height: 12),

                      // Preview
                      if (_pickedImage != null ||
                          _pictureCtrl.text.isNotEmpty)
                        Container(
                          width: double.infinity,
                          height: 150,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.borderColor),
                            color: AppTheme.bgMid,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _pickedImage != null
                                ? Image.file(
                                    File(_pickedImage!.path),
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    _pictureCtrl.text,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Center(
                                      child: Icon(
                                          Icons.broken_image,
                                          color: AppTheme.textSub,
                                          size: 40),
                                    ),
                                  ),
                          ),
                        ),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _uploadingImage
                                  ? null
                                  : _pickAndUploadImage,
                              icon: _uploadingImage
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.accentCyan,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.upload_outlined,
                                      size: 16,
                                      color: AppTheme.accentCyan),
                              label: Text(
                                _uploadingImage
                                    ? 'Uploading...'
                                    : 'Upload Image',
                                style: const TextStyle(
                                    color: AppTheme.accentCyan),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppTheme.accentCyan),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          if (_pictureCtrl.text.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: () => setState(() {
                                _pictureCtrl.clear();
                                _pickedImage = null;
                              }),
                              icon: const Icon(Icons.close,
                                  color: AppTheme.danger, size: 20),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _pictureCtrl,
                        style: const TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'Or paste image URL',
                          prefixIcon:
                              Icon(Icons.link, size: 18),
                          isDense: true,
                        ),
                        onChanged: (_) =>
                            setState(() => _pickedImage = null),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Spawn Location ──────────────────────────
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionLabel('SPAWN LOCATION'),
                          TextButton.icon(
                            onPressed: _locating
                                ? null
                                : _getCurrentLocation,
                            icon: _locating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.accentCyan,
                                    ),
                                  )
                                : const Icon(Icons.my_location,
                                    size: 14,
                                    color: AppTheme.accentCyan),
                            label: const Text(
                              'My location',
                              style: TextStyle(
                                color: AppTheme.accentCyan,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Tap the map to set spawn point',
                        style: TextStyle(
                            color: AppTheme.textSub,
                            fontSize: 12),
                      ),
                      const SizedBox(height: 12),

                      // flutter_map
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 260,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _spawnLocation ??
                                  _defaultCenter,
                              initialZoom:
                                  _spawnLocation != null ? 16 : 13,
                              onTap: (_, point) {
                                setState(
                                    () => _spawnLocation = point);
                              },
                            ),
                            children: [
                              // OpenStreetMap tiles — no API key needed
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.haumonsters.app',
                              ),

                              // Radius circle
                              if (_spawnLocation != null)
                                CircleLayer(
                                  circles: [
                                    CircleMarker(
                                      point: _spawnLocation!,
                                      radius: double.tryParse(
                                              _radiusCtrl.text) ??
                                          100,
                                      useRadiusInMeter: true,
                                      color: AppTheme.accentBlue
                                          .withOpacity(0.2),
                                      borderColor:
                                          AppTheme.accentBlue,
                                      borderStrokeWidth: 2,
                                    ),
                                  ],
                                ),

                              // Spawn marker
                              if (_spawnLocation != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _spawnLocation!,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: AppTheme.accentCyan,
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Coords display
                      if (_spawnLocation != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue
                                .withOpacity(0.08),
                            borderRadius:
                                BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.accentBlue
                                    .withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: AppTheme.accentCyan,
                                  size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${_spawnLocation!.latitude.toStringAsFixed(6)}, '
                                '${_spawnLocation!.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  color: AppTheme.accentCyan,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Radius input
                      TextFormField(
                        controller: _radiusCtrl,
                        style: const TextStyle(
                            color: AppTheme.textWhite),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Catch Radius (meters)',
                          prefixIcon: Icon(Icons.radar),
                          suffixText: 'm',
                          suffixStyle: TextStyle(
                              color: AppTheme.textSub),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Enter a radius';
                          }
                          if (double.tryParse(v) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),

                // Error banner
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              AppTheme.danger.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.danger, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.danger,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16),
                      backgroundColor: AppTheme.accentBlue,
                      disabledBackgroundColor:
                          AppTheme.accentBlue.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isEditing
                                ? 'SAVE CHANGES'
                                : 'ADD MONSTER',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              fontFamily: 'ComicRelief',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedType,
      dropdownColor: AppTheme.bgMid,
      decoration: const InputDecoration(
        labelText: 'Monster Type',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      hint: const Text('Select a type',
          style: TextStyle(color: AppTheme.textSub)),
      items: AppTheme.monsterTypes.map((type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.asset(
                  'assets/images/types/${type.toLowerCase()}.png',
                  height: 22,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 50,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.typeColor(type)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Center(
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.typeColor(type),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                type,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontFamily: 'ComicRelief',
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedType = val),
      selectedItemBuilder: (context) {
        return AppTheme.monsterTypes.map((type) {
          return Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.asset(
                  'assets/images/types/${type.toLowerCase()}.png',
                  height: 22,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                type,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontFamily: 'ComicRelief',
                ),
              ),
            ],
          );
        }).toList();
      },
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.accentBlue, AppTheme.accentCyan],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.textSub,
            fontSize: 11,
            letterSpacing: 2,
            fontFamily: 'ComicRelief',
          ),
        ),
      ],
    );
  }
}