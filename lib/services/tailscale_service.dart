import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:monsterdex/widgets/tailscale_dialog.dart';
import '../constants/api.dart';
import '../services/lambda_service.dart';

enum ConnectionStatus {
  allGood,        // both servers running + vpn connected
  serversDown,    // one or more servers offline
  vpnDisconnected // servers up but vpn not connected
}

class TailscaleService {
  /// Quick check if we can reach the API (VPN + web server both up)
  static Future<bool> isConnected() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/health');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Priority: servers down → vpn disconnected → all good
  static Future<ConnectionStatus> fullCheck() async {
    // 1. Check EC2 states first
    final webState = await LambdaService.getInstanceState(
        ApiConfig.webServerInstanceId, ApiConfig.webServerRegion);
    final dbState = await LambdaService.getInstanceState(
        ApiConfig.dbServerInstanceId, ApiConfig.dbServerRegion);

    final serversDown =
        webState != 'running' || dbState != 'running';

    if (serversDown) {
      return ConnectionStatus.serversDown;
    }

    // 2. Only check VPN if servers are up
    final vpnOk = await isConnected();
    if (!vpnOk) return ConnectionStatus.vpnDisconnected;

    return ConnectionStatus.allGood;
  }

  /// Use this on every screen action that needs the connection.
  /// Shows the right dialog automatically.
  static Future<bool> guardAction(BuildContext context) async {
    final status = await fullCheck();

    if (status == ConnectionStatus.serversDown) {
      if (context.mounted) await ServerDownWarning.show(context);
      return false;
    }

    if (status == ConnectionStatus.vpnDisconnected) {
      if (context.mounted) await TailscaleDialog.show(context);
      return false;
    }

    return true;
  }
}