import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../constants/api.dart';
import '../services/lambda_service.dart';

class EC2StatusButton extends StatefulWidget {
  const EC2StatusButton({super.key});
  @override
  State<EC2StatusButton> createState() => _EC2StatusButtonState();
}

class _EC2StatusButtonState extends State<EC2StatusButton> {
  String _webState = '...';
  String _dbState = '...';
  bool _loading = false;

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

  Color _stateColor(String state) {
    if (state == 'running') return AppTheme.success;
    if (state == 'stopped') return AppTheme.danger;
    return AppTheme.warning;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPanel(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardStart,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor, width: 1),
        ),
        child: _loading
            ? const SizedBox(
                width: 36,
                height: 16,
                child: Center(
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.accentBlue,
                    ),
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(_webState),
                  const SizedBox(width: 4),
                  _dot(_dbState),
                  const SizedBox(width: 6),
                  const Icon(Icons.cloud, color: AppTheme.accentBlue, size: 16),
                ],
              ),
      ),
    );
  }

  Widget _dot(String state) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _stateColor(state),
          boxShadow: [
            BoxShadow(color: _stateColor(state).withOpacity(0.5), blurRadius: 4)
          ],
        ),
      );

  void _showPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgMid,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      // ✅ Use a StatefulBuilder so the sheet rebuilds when state changes
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          return _EC2Panel(
            webState: _webState,
            dbState: _dbState,
            stateColor: _stateColor,
            onRefresh: () async {
              await _refresh();
              // ✅ Also trigger a rebuild of the sheet itself
              if (mounted) setSheetState(() {});
            },
          );
        },
      ),
    );
  }
}

class _EC2Panel extends StatefulWidget {
  final String webState, dbState;
  final VoidCallback onRefresh;
  final Color Function(String) stateColor;

  const _EC2Panel({
    required this.webState,
    required this.dbState,
    required this.onRefresh,
    required this.stateColor,
  });

  @override
  State<_EC2Panel> createState() => _EC2PanelState();
}

class _EC2PanelState extends State<_EC2Panel> {
  bool _toggling = false;

  Future<void> _toggle(
      String instanceId, String region, String currentState) async {
    setState(() => _toggling = true);
    final action = currentState == 'running' ? 'stop' : 'start';
    final success = await LambdaService.toggleInstance(instanceId, region, action);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $action instance')),
      );
    }
    // ✅ Wait longer — EC2 state transitions take a few seconds to register
    await Future.delayed(const Duration(seconds: 4));
    widget.onRefresh();
    if (mounted) setState(() => _toggling = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('EC2 Instances',
                  style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ComicRelief')),
              IconButton(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh, color: AppTheme.accentBlue)),
            ],
          ),
          const SizedBox(height: 16),
          _instanceTile(
            'Web Server',
            'Paris (eu-west-3)',
            ApiConfig.webServerInstanceId,
            ApiConfig.webServerRegion,
            widget.webState,
          ),
          const SizedBox(height: 12),
          _instanceTile(
            'DB Server',
            'N. Virginia (us-east-1)',
            ApiConfig.dbServerInstanceId,
            ApiConfig.dbServerRegion,
            widget.dbState,
          ),
        ],
      ),
    );
  }

  Widget _instanceTile(String name, String region, String instanceId,
      String awsRegion, String state) {
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
              color: widget.stateColor(state),
              boxShadow: [
                BoxShadow(
                    color: widget.stateColor(state).withOpacity(0.5),
                    blurRadius: 6)
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.w700)),
                Text('$region • $state',
                    style: const TextStyle(
                        color: AppTheme.textSub, fontSize: 12)),
              ],
            ),
          ),
          if (_toggling)
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
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