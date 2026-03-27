import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/theme.dart';
import '../constants/api.dart';
import '../services/lambda_service.dart';

class TailscaleDialog extends StatelessWidget {
  const TailscaleDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TailscaleDialog(),
    );
  }

  static final Uri _inviteUrl = Uri.parse(
    'https://login.tailscale.com/admin/invite/drM6dTuvGEMkgLGaFe4K11',
  );

  Future<void> _openInvite() async {
    if (!await launchUrl(_inviteUrl, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not open invite link');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.danger.withOpacity(0.15),
                      border: Border.all(color: AppTheme.danger, width: 2),
                    ),
                    child: const Icon(
                      Icons.vpn_lock,
                      color: AppTheme.danger,
                      size: 28,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'VPN Required',
                    style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ComicRelief',
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Connect to Tailscale to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSub,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _step('1', 'Install', 'Install Tailscale from the App Store or Google Play Store.'),
                  _step('2', 'Join', 'Open invite link below.'),
                  _step('3', 'Connect', 'Open Tailscale and tap Connect. Make sure it shows "Connected" before returning here.'),
                  _step('4', 'Return', 'Once connected, return to the app.'),

                  const SizedBox(height: 10),

                  // Invite Link Button
                  GestureDetector(
                    onTap: _openInvite,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cardStart,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.link,
                            color: AppTheme.textSub,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Open Invite Link',
                            style: TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Retry Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        "Retry",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _step(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.accentBlue, AppTheme.accentCyan],
              ),
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppTheme.textSub,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ServerDownWarning extends StatelessWidget {
  final VoidCallback? onOkPressed;

  const ServerDownWarning({super.key, this.onOkPressed});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ServerDownWarning(
        onOkPressed: () {
          Navigator.pop(context);
          // Open EC2 panel after dismissing
          showModalBottomSheet(
            context: context,
            backgroundColor: AppTheme.bgMid,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => const _EC2PanelSheet(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: AppTheme.cardDecoration,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.warning.withOpacity(0.15),
                border: Border.all(color: AppTheme.warning, width: 2),
              ),
              child: const Icon(Icons.cloud_off,
                  color: AppTheme.warning, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Servers Offline',
              style: TextStyle(
                color: AppTheme.textWhite,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'ComicRelief',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'One or more servers are currently offline. Press OK to open the EC2 panel and turn them on.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSub, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onOkPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'ComicRelief',
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EC2PanelSheet extends StatefulWidget {
  const _EC2PanelSheet();

  @override
  State<_EC2PanelSheet> createState() => _EC2PanelSheetState();
}

class _EC2PanelSheetState extends State<_EC2PanelSheet> {
  String _webState = '...';
  String _dbState = '...';
  bool _loading = true;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final web = await LambdaService.getInstanceState(
        ApiConfig.webServerInstanceId, ApiConfig.webServerRegion);
    final db = await LambdaService.getInstanceState(
        ApiConfig.dbServerInstanceId, ApiConfig.dbServerRegion);
    if (mounted) {
      setState(() {
        _webState = web;
        _dbState = db;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(
      String instanceId, String region, String currentState) async {
    setState(() => _toggling = true);
    final action = currentState == 'running' ? 'stop' : 'start';
    await LambdaService.toggleInstance(instanceId, region, action);
    await Future.delayed(const Duration(seconds: 3));
    await _refresh();
    if (mounted) setState(() => _toggling = false);
  }

  Color _stateColor(String state) {
    if (state == 'running') return AppTheme.success;
    if (state == 'stopped') return AppTheme.danger;
    return AppTheme.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSub.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EC2 Instances',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'ComicRelief',
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accentBlue),
                      )
                    : const Icon(Icons.refresh,
                        color: AppTheme.accentBlue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _instanceTile(
            'Web Server',
            'Paris (eu-west-3)',
            ApiConfig.webServerInstanceId,
            ApiConfig.webServerRegion,
            _webState,
          ),
          const SizedBox(height: 12),
          _instanceTile(
            'DB Server',
            'N. Virginia (us-east-1)',
            ApiConfig.dbServerInstanceId,
            ApiConfig.dbServerRegion,
            _dbState,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _instanceTile(String name, String region,
      String instanceId, String awsRegion, String state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _stateColor(state),
              boxShadow: [
                BoxShadow(
                  color: _stateColor(state).withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
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
                  ),
                ),
                Text(
                  '$region • $state',
                  style: const TextStyle(
                    color: AppTheme.textSub,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_toggling)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: state == 'running',
              onChanged: (_) => _toggle(instanceId, awsRegion, state),
              activeColor: AppTheme.success,
              inactiveThumbColor: AppTheme.danger,
            ),
        ],
      ),
    );
  }
}