class ApiConfig {
  static const String tailnetName = 'monsterdex.tail55d916.ts.net';
  static const int apiPort = 8000;

  static String get baseUrl =>
      'http://$tailnetName:$apiPort';

  static const String lambdaUrl =
      'https://guejj53w3m6vm7hrfhxq4k6mli0vmzji.lambda-url.us-east-1.on.aws/';

  // EC2 Instance IDs
  static const String webServerInstanceId = 'i-0e5055a9f438cee54'; // Paris
  static const String dbServerInstanceId  = 'i-02e56bac508096d22'; // N. Virginia
  static const String webServerRegion = 'eu-west-3';
  static const String dbServerRegion  = 'us-east-1';
}