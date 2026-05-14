import 'package:http/http.dart' as http;
import '../constants/api.dart';
import '../services/lambda_service.dart';
import '../widgets/tailscale_dialog.dart';
import 'package:flutter/material.dart';

enum ConnectionStatus {
  allGood,
  serverDown,
  vpnDisconnected,
}

class TailscaleService {
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

  /// Priority: server down → vpn disconnected → all good
  static Future<ConnectionStatus> fullCheck() async {
    // 1. Check web server EC2 state via Lambda
    final webState = await LambdaService.getInstanceState(
        ApiConfig.webServerInstanceId, ApiConfig.webServerRegion);

    if (webState != 'running') {
      return ConnectionStatus.serverDown;
    }

    // 2. Server is up — check VPN reachability
    final vpnOk = await isConnected();
    if (!vpnOk) return ConnectionStatus.vpnDisconnected;

    return ConnectionStatus.allGood;
  }
  
  /// Shows the right dialog automatically and returns false if blocked.
  static Future<bool> guardAction(BuildContext context) async {
    final status = await fullCheck();

    if (status == ConnectionStatus.serverDown) {
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