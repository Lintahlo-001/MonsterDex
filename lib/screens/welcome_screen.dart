import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/tailscale_service.dart';
import '../widgets/tailscale_dialog.dart';
import '../widgets/ec2_status_button.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _checking = true;
  ConnectionStatus _status = ConnectionStatus.serversDown;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _animCtrl, curve: Curves.easeOut));
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    final status = await TailscaleService.fullCheck();
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
    _animCtrl.forward(from: 0);
  }

  void _onLogin() {
    if (_status != ConnectionStatus.allGood) {
      _showBlockedDialog();
      return;
    }
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _onRegister() {
    if (_status != ConnectionStatus.allGood) {
      _showBlockedDialog();
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  void _showBlockedDialog() async {
    if (_status == ConnectionStatus.serversDown) {
      await ServerDownWarning.show(context);
      // After EC2 panel is closed, re-check
      _checkStatus();
      return;
    }
    if (_status == ConnectionStatus.vpnDisconnected) {
      await TailscaleDialog.show(context);
      _checkStatus();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canProceed = _status == ConnectionStatus.allGood;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: const EC2StatusButton(),
          ),
          if (_checking)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.accentBlue),
            )
          else
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 24),
                        _buildStatusBadge(),
                        const SizedBox(height: 48),
                        _buildLoginButton(canProceed),
                        const SizedBox(height: 14),
                        _buildRegisterButton(canProceed),
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: _checkStatus,
                          icon: const Icon(Icons.refresh,
                              color: AppTheme.textSub, size: 16),
                          label: const Text(
                            'Refresh status',
                            style: TextStyle(
                                color: AppTheme.textSub, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'MonsterDex © 2026',
                          style: TextStyle(
                              color: AppTheme.textSub.withOpacity(0.5),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo.png',
      width: 500,
      fit: BoxFit.contain,
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    IconData icon;
    String label;

    switch (_status) {
      case ConnectionStatus.allGood:
        color = AppTheme.success;
        icon = Icons.check_circle_outline;
        label = 'Connected & Ready';
        break;
      case ConnectionStatus.serversDown:
        color = AppTheme.danger;
        icon = Icons.cloud_off;
        label = 'Servers Offline — Turn on EC2 first';
        break;
      case ConnectionStatus.vpnDisconnected:
        color = AppTheme.warning;
        icon = Icons.vpn_lock_outlined;
        label = 'VPN Not Connected';
        break;
    }

    return GestureDetector(
      onTap: _status == ConnectionStatus.vpnDisconnected
          ? () => TailscaleDialog.show(context).then((_) => _checkStatus())
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_status == ConnectionStatus.vpnDisconnected) ...[
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios,
                  color: color, size: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(bool enabled) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: enabled ? 1.0 : 0.35,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _onLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentBlue,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'LOGIN',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              fontFamily: 'ComicRelief',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterButton(bool enabled) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: enabled ? 1.0 : 0.35,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _onRegister,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.accentCyan,
            side: const BorderSide(
                color: AppTheme.accentCyan, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'REGISTER',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              fontFamily: 'ComicRelief',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Container(color: AppTheme.bgDark),
        Positioned(
          top: -80,
          left: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentBlue.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentCyan.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _GridPainter()),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E90FF).withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 40.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}