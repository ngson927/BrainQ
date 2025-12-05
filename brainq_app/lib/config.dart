class ApiConfig {
  // Localhost for Chrome/web debugging
  static const String webBaseUrl = 'http://127.0.0.1:8000/api/';

  // Android emulator (maps localhost → host computer)
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api/';

  // iOS simulator or desktop testing
  static const String localBaseUrl = 'http://127.0.0.1:8000/api/';

  // 🔥 LAN/Wi-Fi access — use your computer’s local IP on the same Wi-Fi
  static const String lanBaseUrl = 'http://192.168.158.130:8000/api/';
}