import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/tailscale_service.dart';
import '../widgets/ec2_status_button.dart';
import '../widgets/app_snackbar.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int playerId;
  final String username;
  final String playerName;

  const SettingsScreen({
    super.key,
    required this.playerId,
    required this.username,
    required this.playerName,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _playerName;
  late String _username;
  bool _vpnConnected = false;

  @override
  void initState() {
    super.initState();
    _playerName = widget.playerName;
    _username = widget.username;
    _checkVpn();
  }

  Future<void> _checkVpn() async {
    final connected = await TailscaleService.isConnected();
    if (mounted) setState(() => _vpnConnected = connected);
  }

  String _md5(String input) =>
      md5.convert(utf8.encode(input)).toString();

  Future<void> _showEditDialog({
    required String title,
    required String field,
    required String hint,
    bool isPassword = false,
  }) async {
    final ctrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.accentBlue,
                            AppTheme.accentCyan
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'ComicRelief',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Input
                TextField(
                  controller: ctrl,
                  obscureText: isPassword ? obscure : false,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon: Icon(
                      isPassword
                          ? Icons.lock_outline
                          : field == 'player_name'
                              ? Icons.badge_outlined
                              : Icons.person_outline,
                    ),
                    suffixIcon: isPassword
                        ? IconButton(
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppTheme.textSub,
                              size: 20,
                            ),
                            onPressed: () =>
                                setS(() => obscure = !obscure),
                          )
                        : null,
                  ),
                ),

                // Confirm password
                if (isPassword) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscureConfirm,
                    style:
                        const TextStyle(color: AppTheme.textWhite),
                    decoration: InputDecoration(
                      hintText: 'Confirm new password',
                      prefixIcon:
                          const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.textSub,
                          size: 20,
                        ),
                        onPressed: () => setS(
                            () => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
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
                        onPressed: () async {
                          final value = ctrl.text.trim();
                          if (value.isEmpty) return;

                          if (isPassword) {
                            if (value.length < 6) {
                              AppSnackbar.error(ctx,
                                  'Password must be at least 6 characters.');
                              return;
                            }
                            if (value != confirmCtrl.text) {
                              AppSnackbar.error(
                                  ctx, 'Passwords do not match.');
                              return;
                            }
                          }

                          Navigator.pop(ctx);
                          await _updateField(
                            field,
                            isPassword ? _md5(value) : value,
                            isPassword ? null : value,
                            field,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateField(String field, String value,
      String? displayValue, String fieldName) async {
    final ok = await TailscaleService.guardAction(context);
    if (!ok) return;

    try {
      await ApiService.put(
          '/players/${widget.playerId}', {field: value});

      final prefs = await SharedPreferences.getInstance();

      if (field == 'player_name' && displayValue != null) {
        setState(() => _playerName = displayValue);
        await prefs.setString('player_name', displayValue);
      } else if (field == 'username' && displayValue != null) {
        setState(() => _username = displayValue);
        await prefs.setString('username', displayValue);
      }

      if (mounted) {
        AppSnackbar.success(context, 'Changes saved!');
      }

    } catch (e) {
      String message = 'Failed to save changes.';

      if (e.toString().contains('Username already exists')) {
        message = 'Username is already taken.';
      } else if (e.toString().contains('Player name already exists')) {
        message = 'Player name is already taken.';
      }

      if (mounted) {
        AppSnackbar.error(context, message);
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.danger.withOpacity(0.15),
                  border:
                      Border.all(color: AppTheme.danger, width: 1.5),
                ),
                child: const Icon(Icons.logout,
                    color: AppTheme.danger, size: 26),
              ),
              const SizedBox(height: 16),
              const Text(
                'Logout',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'ComicRelief',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to logout?',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppTheme.textSub, fontSize: 14),
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
                      child: const Text('Logout'),
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMid,
        title: const Text(
          'Settings',
          style: TextStyle(
              fontFamily: 'ComicRelief', fontWeight: FontWeight.w700),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: EC2StatusButton(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Player card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentBlue,
                          AppTheme.accentCyan
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _playerName.isNotEmpty
                            ? _playerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'ComicRelief',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _playerName,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'ComicRelief',
                        ),
                      ),
                      Text(
                        '@$_username',
                        style: const TextStyle(
                          color: AppTheme.textSub,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'ID: #${widget.playerId}',
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

            const SizedBox(height: 12),

            // VPN status
            GestureDetector(
              onTap: _checkVpn,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: (_vpnConnected
                          ? AppTheme.success
                          : AppTheme.danger)
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_vpnConnected
                            ? AppTheme.success
                            : AppTheme.danger)
                        .withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _vpnConnected
                          ? Icons.vpn_lock
                          : Icons.vpn_lock_outlined,
                      color: _vpnConnected
                          ? AppTheme.success
                          : AppTheme.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _vpnConnected
                          ? 'Tailscale Connected'
                          : 'Tailscale Not Connected',
                      style: TextStyle(
                        color: _vpnConnected
                            ? AppTheme.success
                            : AppTheme.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'ComicRelief',
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.refresh,
                      color: _vpnConnected
                          ? AppTheme.success
                          : AppTheme.danger,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Account section label
            _sectionLabel('ACCOUNT'),
            const SizedBox(height: 12),

            // Edit options
            _settingsTile(
              icon: Icons.badge_outlined,
              label: 'Player Name',
              value: _playerName,
              onTap: () => _showEditDialog(
                title: 'Change Player Name',
                field: 'player_name',
                hint: 'New player name',
              ),
            ),
            const SizedBox(height: 10),
            _settingsTile(
              icon: Icons.person_outline,
              label: 'Username',
              value: '@$_username',
              onTap: () => _showEditDialog(
                title: 'Change Username',
                field: 'username',
                hint: 'New username',
              ),
            ),
            const SizedBox(height: 10),
            _settingsTile(
              icon: Icons.lock_outline,
              label: 'Password',
              value: '••••••••',
              onTap: () => _showEditDialog(
                title: 'Change Password',
                field: 'password',
                hint: 'New password',
                isPassword: true,
              ),
            ),

            const SizedBox(height: 32),

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout,
                    color: AppTheme.danger),
                label: const Text(
                  'LOGOUT',
                  style: TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontFamily: 'ComicRelief',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(
                      color: AppTheme.danger, width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            SizedBox(
                height: MediaQuery.of(context).padding.bottom + 80),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: AppTheme.cardDecoration,
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentBlue, size: 20),
            const SizedBox(width: 14),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'ComicRelief',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textSub, size: 20),
          ],
        ),
      ),
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