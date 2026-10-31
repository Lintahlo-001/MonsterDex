/// Server settings for the app.
/// See `env.example.json` for the keys and docs/flutter-app.md for details.
class ApiConfig {
  static const String tailnetName = String.fromEnvironment('TAILNET_NAME');

  static const int apiPort =
      int.fromEnvironment('API_PORT', defaultValue: 8000);

  static String get baseUrl => 'http://$tailnetName:$apiPort';

  /// AWS Lambda Function URL that starts/stops/checks the web server.
  static const String lambdaUrl = String.fromEnvironment('LAMBDA_URL');

  /// Web server EC2 instance (the database is managed by RDS).
  static const String webServerInstanceId =
      String.fromEnvironment('WEB_SERVER_INSTANCE_ID');
  static const String webServerRegion =
      String.fromEnvironment('WEB_SERVER_REGION', defaultValue: 'eu-west-3');
}