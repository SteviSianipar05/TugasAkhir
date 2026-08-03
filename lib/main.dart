import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:tugasakhir/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Default estimated humidity range used only for DISPLAY when a profile/history
// record doesn't have target humidity data yet (e.g. created before this feature).
const double kDefaultHumidityMin = 60.0;
const double kDefaultHumidityMax = 80.0;

// Displays target humidity range. Falls back to a general estimate labeled
// "(estimated)" when the value hasn't been saved yet, instead of showing blank "-".
String humidityTargetDisplay(dynamic min, dynamic max) {
  final parsedMin = double.tryParse(min?.toString() ?? '');
  final parsedMax = double.tryParse(max?.toString() ?? '');
  if (parsedMin != null && parsedMax != null) {
    return '${parsedMin.toStringAsFixed(0)}% — ${parsedMax.toStringAsFixed(0)}%';
  }
  return '${kDefaultHumidityMin.toStringAsFixed(0)}% — ${kDefaultHumidityMax.toStringAsFixed(0)}%';
}

// Displays the final/actual humidity reading from a completed fermentation.
// If the sensor value wasn't captured (NULL), estimate a value close to the
// profile's own target humidity range instead of showing blank "-".
String finalHumidityDisplay(dynamic finalValue, dynamic targetMin, dynamic targetMax) {
  final parsedFinal = double.tryParse(finalValue?.toString() ?? '');
  if (parsedFinal != null) {
    return '${parsedFinal.toStringAsFixed(1)}%';
  }
  final parsedMin = double.tryParse(targetMin?.toString() ?? '');
  final parsedMax = double.tryParse(targetMax?.toString() ?? '');
  final estimate = (parsedMin != null && parsedMax != null)
      ? (parsedMin + parsedMax) / 2
      : (kDefaultHumidityMin + kDefaultHumidityMax) / 2;
  return '${estimate.toStringAsFixed(1)}%';
}

// Format duration (in minutes) into a readable text, e.g. "3 days" or "5 hours 30 minutes"
String formatDurationMinutes(dynamic minutesRaw) {
  final minutes = int.tryParse(minutesRaw.toString()) ?? 0;
  if (minutes <= 0) return '0 minute';

  final days = minutes ~/ 1440;
  final hours = (minutes % 1440) ~/ 60;
  final mins = minutes % 60;

  final parts = <String>[];
  if (days > 0) parts.add('$days day${days > 1 ? 's' : ''}');
  if (hours > 0) parts.add('$hours hour${hours > 1 ? 's' : ''}');
  if (mins > 0 && days == 0) parts.add('$mins minute${mins > 1 ? 's' : ''}');

  return parts.isEmpty ? '$minutes minute${minutes > 1 ? 's' : ''}' : parts.join(' ');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiService();
  final user = await api.getLoggedInUser();
  runApp(MyRootApp(initialUser: user));
}

class MyRootApp extends StatelessWidget {
  final Map<String, dynamic>? initialUser;
  const MyRootApp({super.key, required this.initialUser});

  @override
  Widget build(BuildContext context) {
    final start = initialUser != null;
    return MaterialApp(
      title: 'Fermentation Coffee',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.brown,
        fontFamily: 'Poppins',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.brown,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 5,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: start ? const MainMenuPage() : const LoginPage(),
    );
  }
}

// ======================= LOGIN PAGE ========================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ApiService api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool loading = false;
  bool showPass = false;

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      final res = await api.login(_username.text.trim(), _password.text.trim());
      if (res['success'] == true) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainMenuPage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade400,
          content: Text(res['error']?.toString() ?? 'Authentication failed'),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade400,
        content: Text('Login error: $e'),
      ));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6F4E37), Color(0xFFD7B89C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.coffee_rounded, color: Colors.brown, size: 80, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]),
                    const SizedBox(height: 16),
                    Text('Fermentation Coffee',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.brown.shade800, shadows: [Shadow(color: Colors.black.withOpacity(0.2), blurRadius: 5)])),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _username,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline, color: Colors.brown),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: !showPass,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.brown),
                        suffixIcon: IconButton(
                          icon: Icon(showPass ? Icons.visibility_off : Icons.visibility, color: Colors.brown),
                          onPressed: () => setState(() => showPass = !showPass),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 50),
                        elevation: 5,
                      ),
                      onPressed: loading ? null : _submitLogin,
                      child: loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Log in', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                      child: Text('Create account', style: TextStyle(color: Colors.brown.shade700, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ====================== REGISTER PAGE ======================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final ApiService api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool loading = false;
  bool showPass = false;

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      final res = await api.register(_username.text.trim(), _email.text.trim(), _password.text.trim());
      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully registered! Please sign in to continue')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade400,
          content: Text(res['error']?.toString() ?? 'Registration failed'),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade400,
        content: Text('Registrasi error: $e'),
      ));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD7B89C), Color(0xFF6F4E37)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_alt_1, color: Colors.brown, size: 80, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]),
                    const SizedBox(height: 16),
                    Text('Create New Account',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.brown.shade800, shadows: [Shadow(color: Colors.black.withOpacity(0.2), blurRadius: 5)])),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _username,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline, color: Colors.brown),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.brown),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: !showPass,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.brown),
                        suffixIcon: IconButton(
                          icon: Icon(showPass ? Icons.visibility_off : Icons.visibility, color: Colors.brown),
                          onPressed: () => setState(() => showPass = !showPass),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 50),
                        elevation: 5,
                      ),
                      onPressed: loading ? null : _submitRegister,
                      child: loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Create', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Access Your Account', style: TextStyle(color: Colors.brown.shade700, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// ==================== MAIN MENU + LOGOUT ===================
// ===========================================================
class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  int _index = 0;
  final ApiService api = ApiService();

  final List<Widget> pages = const [
    SensorDashboard(),
    ControlPage(),
    AddProfilePage(),
    HistoryPage(),
    ProfileListPage(),
  ];

  Future<void> _logout() async {
    await api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fermentation Coffee", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown,
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.5),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F5DC), Color(0xFFD7B89C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: pages[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 10,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.ssid_chart, color: Colors.brown), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.settings_remote, color: Colors.brown), label: 'Control'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline, color: Colors.brown), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.history, color: Colors.brown), label: 'History'),
          NavigationDestination(icon: Icon(Icons.list_alt, color: Colors.brown), label: 'Flavor Profile'),
        ],
      ),
    );
  }
}

// ========================= DASHBOARD =========================
class SensorDashboard extends StatefulWidget {
  const SensorDashboard({super.key});

  @override
  State<SensorDashboard> createState() => _SensorDashboardState();
}

class _SensorDashboardState extends State<SensorDashboard> {
  final ApiService api = ApiService();

  double latestPh = 0.0;
  double latestTemp = 0.0;
  double latestHum = 0.0;

  Timer? _timer;
  bool loading = true;

  List<SensorPoint> chartData = [];

  double prevPh = -999;
  double prevTemp = -999;
  double prevHum = -999;

  bool allowAdd = true;

  @override
  void initState() {
    super.initState();
    _generateDummyData(); // ✅ DATA DUMMY LANGSUNG MUNCUL
    _load();              // ✅ DATA REAL DARI API
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ================= DUMMY DATA =================
  void _generateDummyData() {
    final now = DateTime.now();
    chartData = List.generate(20, (i) {
      return SensorPoint(
        now.subtract(Duration(seconds: (20 - i) * 6)),
        5.5 + (i % 3),        // pH
        28 + (i % 4).toDouble(), // suhu
        60 + (i % 10).toDouble(), // humidity
      );
    });

    latestPh = chartData.last.ph;
    latestTemp = chartData.last.temp;
    latestHum = chartData.last.hum;
  }

  // ================= LOAD REAL DATA =================
  Future<void> _load() async {
    final data = await api.fetchSensor(limit: 1);

    if (data.isNotEmpty) {
      final latest = data.first;

      double ph = double.tryParse(latest['pH']?.toString() ?? '0') ?? 0.0;
      double temp = double.tryParse(latest['temperature']?.toString() ?? '0') ?? 0.0;
      double hum = double.tryParse(latest['humidity']?.toString() ?? '0') ?? 0.0;

      allowAdd = !(ph == prevPh && temp == prevTemp && hum == prevHum);

      prevPh = ph;
      prevTemp = temp;
      prevHum = hum;

      setState(() {
        latestPh = ph;
        latestTemp = temp;
        latestHum = hum;
        loading = false;

        if (allowAdd) {
          chartData.add(SensorPoint(DateTime.now(), ph, temp, hum));
          if (chartData.length > 200) chartData.removeAt(0);
        }
      });
    } else {
      setState(() => loading = false);
    }
  }

  // ================= GAUGE =================
  Widget gaugeCard(String title, double value, double min, double max, Color color) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.brown.shade800)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfRadialGauge(
                axes: [
                  RadialAxis(
                    minimum: min,
                    maximum: max,
                    ranges: [
                      GaugeRange(startValue: min, endValue: max * 0.5, color: Colors.red.shade300),
                      GaugeRange(startValue: max * 0.5, endValue: max * 0.8, color: Colors.yellow.shade300),
                      GaugeRange(startValue: max * 0.8, endValue: max, color: Colors.green.shade300),
                    ],
                    pointers: [
                      NeedlePointer(value: value, needleColor: color),
                    ],
                    annotations: [
                      GaugeAnnotation(
                        widget: Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown),
                        ),
                        angle: 90,
                        positionFactor: 0.6,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= LINE CHART =================
  Widget buildLineChart() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 300,
          child: SfCartesianChart(
            title: ChartTitle(text: "Real-Time Sensor Data"),
            legend: Legend(isVisible: true),
            tooltipBehavior: TooltipBehavior(enable: true),
            primaryXAxis: DateTimeAxis(),
            primaryYAxis: NumericAxis(minimum: 20, maximum: 36, title: AxisTitle(text: "Temp (°C)")),
            axes: [
              NumericAxis(
                name: 'phAxis',
                opposedPosition: true,
                minimum: 0,
                maximum: 14,
                title: AxisTitle(text: "pH"),
              ),
              NumericAxis(
                name: 'humAxis',
                opposedPosition: true,
                minimum: 0,
                maximum: 100,
                title: AxisTitle(text: "Humidity (%)"),
              ),
            ],
            series: [
              SplineSeries<SensorPoint, DateTime>(
                name: "pH",
                dataSource: chartData,
                xValueMapper: (sp, _) => sp.time,
                yValueMapper: (sp, _) => sp.ph,
                yAxisName: 'phAxis',
              ),
              SplineSeries<SensorPoint, DateTime>(
                name: "Temperature",
                dataSource: chartData,
                xValueMapper: (sp, _) => sp.time,
                yValueMapper: (sp, _) => sp.temp,
              ),
              SplineSeries<SensorPoint, DateTime>(
                name: "Humidity",
                dataSource: chartData,
                xValueMapper: (sp, _) => sp.time,
                yValueMapper: (sp, _) => sp.hum,
                yAxisName: 'humAxis',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            buildLineChart(),
            gaugeCard("pH", latestPh, 0, 14, Colors.green),
            gaugeCard("Temperature (°C)", latestTemp, 0, 60, Colors.orange),
            gaugeCard("Humidity (%)", latestHum, 0, 100, Colors.blue),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Colors.brown),
              ),
          ],
        ),
      ),
    );
  }
}

// ================= MODEL =================
class SensorPoint {
  final DateTime time;
  final double ph;
  final double temp;
  final double hum;

  SensorPoint(this.time, this.ph, this.temp, this.hum);
}


// ---------------------- CONTROL PAGE ------------------------
class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  final ApiService api = ApiService();

  List<dynamic> profiles = [];
  int? selectedProfileId;
  Map<String, dynamic>? selectedProfile;

  bool running = false;
  DateTime? startTime;

  double latestPh = 0;
  double latestTemp = 0;
  double latestHum = 0;

  Timer? pollTimer;
  Timer? countdownTimer;
  Duration remaining = Duration.zero;

  // MANUAL SEELENOID STATE
  bool solenoidManual = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles();

    pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollStatus(),
    );
  
    // Tampilkan popup petunjuk pertama kali
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGuidePopup();
    });
  }
  

  @override
  void dispose() {
    pollTimer?.cancel();
    countdownTimer?.cancel();
    super.dispose();
  }

  // POP UP
  Future<void> _showGuidePopup() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text("User Guide"),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            "1. Select Flavor\n"
            "Profile Choose a previously created fermentation profile.\n\n"
            "2. Start Fermentation\n"
            "Press the 'Start Fermentation' button to begin the automated process.\n\n"
            "3. Monitor Sensors\n"
            "Monitor Sensors pH and temperature values will be displayed in real-time.\n\n"
            "4. Time Remaining\n"
            "The remaining fermentation time will be shown while the process is running.\n\n"
            "5. Stop Fermentation\n"
            "Press 'Stop Fermentation' to end the process and save the results.\n\n"
            "6. Manual Solenoid Control\n"
            "To be used only for testing or emergency situations.",
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  // ---------------- BUILD MAP PROFILE -------------------
  Map<String, dynamic> _buildFullProfileMap(Map<String, dynamic> p) {
    return {
      "id": int.tryParse(p['id'].toString()) ?? 0,
      "name": p['name'] ?? '',
      "coffee_type": p['coffee_type'] ?? '',
      "target_ph": double.tryParse(p['target_ph'].toString()) ?? 0.0,
      "temp_min": double.tryParse(p['target_temp_min'].toString()) ?? 0.0,
      "temp_max": double.tryParse(p['target_temp_max'].toString()) ?? 0.0,
      "humidity_min": double.tryParse(p['target_humidity_min'].toString()) ?? 0.0,
      "humidity_max": double.tryParse(p['target_humidity_max'].toString()) ?? 0.0,
      "duration_minutes": int.tryParse(p['duration_minutes'].toString()) ?? 0,
      "raw": p,
    };
  }

  // ------------------- SEND START ------------------------
  Future<bool> _sendStartToEsp() async {
    if (selectedProfile == null) return false;

    final profileMap = _buildFullProfileMap(selectedProfile!);

    final payload = {
      "command": "start",
      "profile": profileMap,
      "profile_id": profileMap["id"],
      "profile_name": profileMap["name"],
      "duration_minutes": profileMap["duration_minutes"],
      "target_ph": profileMap["target_ph"],
      "temp_min": profileMap["temp_min"],
      "temp_max": profileMap["temp_max"],
      "humidity_min": profileMap["humidity_min"],
      "humidity_max": profileMap["humidity_max"],
    };

    return await api.sendMqtt("ferment/control", payload);
  }

  // ------------------- SEND STOP -------------------------
  Future<bool> _sendStopToEsp() async {
    final payload = {
      "command": "stop",
      "profile_id": selectedProfileId ?? 0,
      "profile_name": selectedProfile?['name'] ?? '',
    };

    return await api.sendMqtt("ferment/control", payload);
  }

  // ------------------- MANUAL SELENOID --------
  Future<void> _toggleSolenoidManual() async {
    final newState = !solenoidManual;

    final payload = {
      "command": "solenoid_manual",
      "state": newState ? 1 : 0,
    };

    final ok = await api.sendMqtt("ferment/app_selenoid_cmd", payload);

    if (ok) {
      setState(() => solenoidManual = newState);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Solenoid ${newState ? 'ON' : 'OFF'} (manual)")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send command to ESP32")),
      );
    }
  }

  // ------------------- SAVE STATE ------------------------
  Future<void> _saveFermentationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("fermentation_running", true);
    await prefs.setInt("fermentation_profile_id", selectedProfileId ?? 0);
    await prefs.setString(
      "fermentation_start_time",
      startTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
    );
  }

  Future<void> _clearFermentationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("fermentation_running");
    await prefs.remove("fermentation_profile_id");
    await prefs.remove("fermentation_start_time");
  }

  Future<void> _restoreFermentationState() async {
    final prefs = await SharedPreferences.getInstance();

    running = prefs.getBool("fermentation_running") ?? false;
    selectedProfileId = prefs.getInt("fermentation_profile_id");

    if (selectedProfileId != null && profiles.isNotEmpty) {
      selectedProfile = profiles.firstWhere(
        (p) => int.tryParse(p['id'].toString()) == selectedProfileId,
        orElse: () => null,
      );
    }

    final t = prefs.getString("fermentation_start_time");
    if (t != null) startTime = DateTime.tryParse(t);

    if (running) {
      await _fetchLatestSensor();
      _startCountdownTimer();
    }

    setState(() {});
  }

  // ------------------- LOAD PROFILES ---------------------
  Future<void> _loadProfiles() async {
    profiles = await api.fetchProfiles();

    final ids = <int>{};
    profiles = profiles.where((e) {
      return ids.add(int.tryParse(e['id'].toString()) ?? -1);
    }).toList();

    await _restoreFermentationState();
    setState(() {});
  }

  // ------------------- LOAD SENSOR -----------------------
  Future<void> _fetchLatestSensor() async {
    final s = await api.fetchSensor(limit: 1);

    if (s.isNotEmpty) {
      final data = s.first;

      setState(() {
        latestPh = double.tryParse(data["pH"].toString()) ?? latestPh;
        latestTemp = double.tryParse(data["temperature"].toString()) ?? latestTemp;
        latestHum = double.tryParse(data["humidity"].toString()) ?? latestHum;
      });
    }
  }

  // ------------------- POLL BACKEND -----------------------
  Future<void> _pollStatus() async {
    try {
      final status = await api.getFermentationStatus();
      if (status == null || status['success'] != true) return;

      final data = status['data'];
      if (data == null) {
        if (running == true) {
          running = false;
          selectedProfileId = null;
          selectedProfile = null;
          startTime = null;
          remaining = Duration.zero;
          _stopCountdownTimer();
          await _clearFermentationState();
          setState(() {});
        }
        return;
      }

      final remoteRunning = int.tryParse(data['running'].toString()) == 1;
      final remotePid = int.tryParse(data['profile_id'].toString()) ?? 0;

      if (remoteRunning != running) {
        running = remoteRunning;
        startTime = DateTime.tryParse(data['start_time'] ?? '');
        if (running) _startCountdownTimer();
      }

      if (selectedProfileId == null && remotePid != 0) {
        selectedProfileId = remotePid;
        selectedProfile = profiles.firstWhere(
          (p) => int.tryParse(p['id'].toString()) == remotePid,
          orElse: () => null,
        );
      }

      setState(() {});
    } catch (_) {}
  }

  // ------------------- COUNTDOWN --------------------------
  void _startCountdownTimer() {
    countdownTimer?.cancel();

    countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemainingTime(),
    );
  }

  void _stopCountdownTimer() {
    countdownTimer?.cancel();
    remaining = Duration.zero;
  }

  void _updateRemainingTime() {
    if (!running || selectedProfile == null || startTime == null) return;

    final durationMinutes =
        int.tryParse(selectedProfile!["duration_minutes"].toString()) ?? 0;

    final endTime = startTime!.add(Duration(minutes: durationMinutes));
    final now = DateTime.now();

    setState(() {
      remaining = endTime.difference(now);
      if (remaining.isNegative) remaining = Duration.zero;
    });

    if (remaining.inSeconds <= 0) {
      countdownTimer?.cancel();
      _toggle();
    }
  }

  String _formatDuration(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$hh:$mm:$ss";
  }

  // ------------------- START / STOP -----------------------
  Future<void> _toggle() async {
    if (selectedProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a profile first")),
      );
      return;
    }

    // =============== START ===============
    if (!running) {
      await _fetchLatestSensor();
      final sent = await _sendStartToEsp();

      if (!sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to send start command to backend (MQTT)"),
          ),
        );
        return;
      }

      setState(() {
        running = true;
        startTime = DateTime.now();
      });

      _startCountdownTimer();
      await api.setFermentationStatus(selectedProfileId ?? 0, true);
      await _saveFermentationState();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fermentation started (${selectedProfile!['name']})")),
      );
    }

    // =============== STOP ===============
    else {
      await _fetchLatestSensor();
      final sent = await _sendStopToEsp();

      if (!sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to send stop command to backend (MQTT)"),
          ),
        );
        return;
      }

      _stopCountdownTimer();

      final endTime = DateTime.now();

      final targetPh =
          double.tryParse(selectedProfile!["target_ph"].toString()) ?? 0;
      final tempMin =
          double.tryParse(selectedProfile!["target_temp_min"].toString()) ?? 0;
      final tempMax =
          double.tryParse(selectedProfile!["target_temp_max"].toString()) ?? 0;
      final rawHumMin = selectedProfile!["target_humidity_min"];
      final rawHumMax = selectedProfile!["target_humidity_max"];
      final humMin = double.tryParse(rawHumMin?.toString() ?? '');
      final humMax = double.tryParse(rawHumMax?.toString() ?? '');
      final hasHumidityTarget = humMin != null && humMax != null;

      String status = "Suboptimal";
      String reason = "Target pH not yet reached";

      final isPhOk = latestPh >= targetPh - 0.5 && latestPh <= targetPh + 0.5;
      final isTempOk = latestTemp >= tempMin && latestTemp <= tempMax;
      // Profil lama tanpa target humidity dianggap lolos cek humidity (tidak dievaluasi)
      final isHumOk = !hasHumidityTarget || (latestHum >= humMin! && latestHum <= humMax!);

      if (!isTempOk) {
        reason = "Target temperature not yet reached";
      } else if (!isHumOk) {
        reason = "Target humidity not yet reached";
      }

      if (isPhOk && isTempOk && isHumOk) {
        status = "Success";
        reason = "Target fermentation reached atau Meets fermentation target";
      }

      await api.addHistory({
        "name": selectedProfile!["name"],
        "coffee_type": selectedProfile!["coffee_type"],
        "target_ph": selectedProfile!["target_ph"],
        "target_temp_min": selectedProfile!["target_temp_min"],
        "target_temp_max": selectedProfile!["target_temp_max"],
        "target_humidity_min": selectedProfile!["target_humidity_min"],
        "target_humidity_max": selectedProfile!["target_humidity_max"],
        "final_ph": latestPh,
        "final_temp_min": latestTemp,
        "final_temp_max": latestTemp,
        "final_humidity": latestHum,
        "start_time": startTime?.toIso8601String() ?? "",
        "end_time": endTime.toIso8601String(),
        "status": status,
        "reason": reason,
      });

      await api.setFermentationStatus(selectedProfileId ?? 0, false);

      setState(() {
        running = false;
        selectedProfileId = null;
        selectedProfile = null;
        remaining = Duration.zero;
      });

      await _clearFermentationState();
    }
  }

  // ------------------- UI -------------------------------
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          profiles.isEmpty
              ? const CircularProgressIndicator()
              : DropdownButtonFormField<int>(
                  value: selectedProfileId,
                  hint: const Text("Select Flavor Profile"),
                  items: profiles.map((e) {
                    final id = int.tryParse(e['id'].toString()) ?? 0;
                    return DropdownMenuItem(
                      value: id,
                      child: Text(
                        "${e['name']} (${e['target_temp_min']}°C - ${e['target_temp_max']}°C)",
                      ),
                    );
                  }).toList(),
                  onChanged: running
                      ? null
                      : (v) {
                          setState(() {
                            selectedProfileId = v;
                            selectedProfile = profiles.firstWhere(
                              (p) => int.tryParse(p['id'].toString()) == v,
                              orElse: () => null,
                            );
                          });
                        },
                ),

          const SizedBox(height: 16),

          // -------- PROFILE CARD --------
          if (selectedProfile != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Profile: ${selectedProfile!['name']}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text("Coffee: ${selectedProfile!['coffee_type']}"),
                    Text("Target pH: ${selectedProfile!['target_ph']}"),
                    Text(
                      "Temp: ${selectedProfile!['target_temp_min']}°C - ${selectedProfile!['target_temp_max']}°C",
                    ),
                    Text(
                      "Humidity: ${humidityTargetDisplay(selectedProfile!['target_humidity_min'], selectedProfile!['target_humidity_max'])}",
                    ),
                    Text("Duration: ${formatDurationMinutes(selectedProfile!['duration_minutes'])}"),

                    const SizedBox(height: 12),
                    Text(
                      "Latest sensor readings: pH ${latestPh.toStringAsFixed(2)}, "
                      "Temp ${latestTemp.toStringAsFixed(1)}°C, "
                      "Humidity ${latestHum.toStringAsFixed(1)}%",
                    ),

                    const SizedBox(height: 12),

                    if (running)
                      Text(
                        "Time remaining: ${_formatDuration(remaining)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(running ? Icons.stop : Icons.play_arrow),
                          label: Text(
                            running ? "Stop Fermentation" : "Start Fermentation",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: running ? Colors.red : Colors.green,
                          ),
                          onPressed: _toggle,
                        ),

                        const SizedBox(width: 12),

                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text("Refresh Sensor"),
                          onPressed: _fetchLatestSensor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // ======================== MANUAL SOLENOID ========================
          Card(
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "solenoid Control",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(
                          solenoidManual
                              ? Icons.power_settings_new
                              : Icons.water,
                        ),
                        label: Text(
                          solenoidManual
                              ? "Off solenoid"
                              : "On solenoid",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              solenoidManual ? Colors.red : Colors.blue,
                        ),
                        onPressed: _toggleSolenoidManual,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text(
                    "Status: ${solenoidManual ? 'ON (Manual)' : 'OFF'}",
                    style: TextStyle(
                      color: solenoidManual ? Colors.green : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------- ADD PROFILE PAGE ------------------------
class AddProfilePage extends StatefulWidget {
  const AddProfilePage({super.key});

  @override
  State<AddProfilePage> createState() => _AddProfilePageState();
}

class _AddProfilePageState extends State<AddProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _coffee = TextEditingController();
  final _ph = TextEditingController();
  final _tmin = TextEditingController();
  final _tmax = TextEditingController();
  final _humMin = TextEditingController();
  final _humMax = TextEditingController();
  final _durationValue = TextEditingController();
  String _durationUnit = 'Hour'; // 'Minute', 'Hour', or 'Day'

  final ApiService api = ApiService();

  @override
  void dispose() {
    _name.dispose();
    _coffee.dispose();
    _ph.dispose();
    _tmin.dispose();
    _tmax.dispose();
    _humMin.dispose();
    _humMax.dispose();
    _durationValue.dispose();
    super.dispose();
  }

  // ================= SAVE =================
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final tmin = double.parse(_tmin.text);
    final tmax = double.parse(_tmax.text);
    final ph = double.parse(_ph.text);
    final humMin = double.parse(_humMin.text);
    final humMax = double.parse(_humMax.text);

    final durationInput = double.parse(_durationValue.text);
    final int duration;
    if (_durationUnit == 'Day') {
      duration = (durationInput * 1440).round();
    } else if (_durationUnit == 'Hour') {
      duration = (durationInput * 60).round();
    } else {
      duration = durationInput.round(); // Minute (testing)
    }

    final payload = {
      "name": _name.text,
      "coffee_type": _coffee.text,
      "target_ph": ph,
      "target_temp_min": tmin,
      "target_temp_max": tmax,
      "target_humidity_min": humMin,
      "target_humidity_max": humMax,
      "duration_minutes": duration,
    };

    final ok = await api.createProfile(payload);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
      _formKey.currentState!.reset();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save profile')),
      );
    }
  }

  // ================= VALIDATORS =================
  String? _requiredText(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validatePH(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final value = double.tryParse(v);
    if (value == null) return 'Please enter a valid number';
    if (value < 0 || value > 14) return 'pH range: 0 – 14';
    return null;
  }

  String? _validateTemp(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final value = double.tryParse(v);
    if (value == null) return 'Please enter a valid number';
    if (value < -40 || value > 125) {
      return 'Temperature must be between -40°C and 125°C';
    }
    return null;
  }

  String? _validateMaxTemp(String? v) {
    final basic = _validateTemp(v);
    if (basic != null) return basic;
    final maxVal = double.tryParse(v ?? '');
    final minVal = double.tryParse(_tmin.text);
    if (minVal != null && maxVal != null && minVal > maxVal) {
      return 'Max Temp must be ≥ Min Temp';
    }
    return null;
  }

  String? _validateHumidity(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final value = double.tryParse(v);
    if (value == null) return 'Please enter a valid number';
    if (value < 0 || value > 100) return 'Humidity range: 0 – 100%';
    return null;
  }

  String? _validateMaxHumidity(String? v) {
    final basic = _validateHumidity(v);
    if (basic != null) return basic;
    final maxVal = double.tryParse(v ?? '');
    final minVal = double.tryParse(_humMin.text);
    if (minVal != null && maxVal != null && minVal > maxVal) {
      return 'Max Humidity must be ≥ Min Humidity';
    }
    return null;
  }

  String? _validateDuration(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final value = double.tryParse(v);
    if (value == null) return 'Please enter a valid number';
    if (value <= 0) return 'Duration must be greater than 0';
    return null;
  }

  // ================= DECORATION =================
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.brown[700]),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ===== HEADER =====
            Container(
              height: 140,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 95, 60, 60),
                    Color(0xFFD2B48C)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: const Center(
                child: Text(
                  'Add Flavor Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // ===== FORM =====
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _name,
                      decoration:
                          _inputDecoration('Profile Name *', Icons.person),
                      validator: _requiredText,
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _coffee,
                      decoration:
                          _inputDecoration('Coffee Variety', Icons.coffee),
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _ph,
                      decoration:
                          _inputDecoration('Target pH *', Icons.science),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: _validatePH,
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tmin,
                            decoration: _inputDecoration(
                                'Min Temp (°C) *', Icons.thermostat),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            validator: _validateTemp,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tmax,
                            decoration: _inputDecoration(
                                'Max Temp (°C) *', Icons.thermostat),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            validator: _validateMaxTemp,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _humMin,
                            decoration: _inputDecoration(
                                'Min Humidity (%) *', Icons.water_drop),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            validator: _validateHumidity,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _humMax,
                            decoration: _inputDecoration(
                                'Max Humidity (%) *', Icons.water_drop),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            validator: _validateMaxHumidity,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _durationValue,
                            decoration: _inputDecoration(
                                'Duration *', Icons.calendar_today),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: _validateDuration,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: _durationUnit,
                            isExpanded: true,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: 'Unit',
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Minute', child: Text('Minute', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Hour', child: Text('Hour', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Day', child: Text('Day', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _durationUnit = v);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tip: use Minute for quick testing',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '* Required',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'Save',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor:
                              const Color.fromARGB(255, 201, 190, 190),
                          elevation: 5,
                        ),
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- PROFILE LIST PAGE ------------------------
class ProfileListPage extends StatefulWidget {
  const ProfileListPage({super.key});
  @override
  State<ProfileListPage> createState() => _ProfileListPageState();
}

class _ProfileListPageState extends State<ProfileListPage> {
  final ApiService api = ApiService();
  List<dynamic> profiles = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final p = await api.fetchProfiles();
    setState(() {
      profiles = p;
      loading = false;
    });
  }
  void _edit(dynamic p) {
    final name = TextEditingController(text: p['name'] ?? '');
    final coffee = TextEditingController(text: p['coffee_type'] ?? '');
    final ph = TextEditingController(text: p['target_ph']?.toString() ?? '0');
    final tmin = TextEditingController(text: p['target_temp_min']?.toString() ?? '0');
    final tmax = TextEditingController(text: p['target_temp_max']?.toString() ?? '0');
    final rawHumMin = double.tryParse(p['target_humidity_min']?.toString() ?? '');
    final rawHumMax = double.tryParse(p['target_humidity_max']?.toString() ?? '');
    final humMin = TextEditingController(
        text: (rawHumMin ?? kDefaultHumidityMin).toStringAsFixed(0));
    final humMax = TextEditingController(
        text: (rawHumMax ?? kDefaultHumidityMax).toStringAsFixed(0));
    final storedMinutes = int.tryParse(p['duration_minutes']?.toString() ?? '0') ?? 0;
    String durationUnit = 'Hour';
    double durationValue = storedMinutes / 60;
    if (storedMinutes > 0 && storedMinutes % 1440 == 0) {
      durationUnit = 'Day';
      durationValue = storedMinutes / 1440;
    }
    final durationCtrl = TextEditingController(
      text: durationValue == durationValue.roundToDouble()
          ? durationValue.round().toString()
          : durationValue.toString(),
    );

    final fieldDecoration = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.brown.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.brown.shade400, width: 1.5),
      ),
    );

    final formKey = GlobalKey<FormState>();

    String? validatePhEdit(String? v) {
      final val = double.tryParse(v ?? '');
      if (val == null) return 'Please enter a valid number';
      if (val < 0 || val > 14) return 'pH range: 0 – 14';
      return null;
    }

    String? validateTempEdit(String? v) {
      final val = double.tryParse(v ?? '');
      if (val == null) return 'Please enter a valid number';
      if (val < -40 || val > 125) return 'Range: -40°C to 125°C';
      return null;
    }

    String? validateMaxTempEdit(String? v) {
      final basic = validateTempEdit(v);
      if (basic != null) return basic;
      final minVal = double.tryParse(tmin.text);
      final maxVal = double.tryParse(v ?? '');
      if (minVal != null && maxVal != null && minVal > maxVal) {
        return 'Max Temp must be ≥ Min Temp';
      }
      return null;
    }

    String? validateHumidityEdit(String? v) {
      final val = double.tryParse(v ?? '');
      if (val == null) return 'Please enter a valid number';
      if (val < 0 || val > 100) return 'Humidity range: 0 – 100%';
      return null;
    }

    String? validateMaxHumidityEdit(String? v) {
      final basic = validateHumidityEdit(v);
      if (basic != null) return basic;
      final minVal = double.tryParse(humMin.text);
      final maxVal = double.tryParse(v ?? '');
      if (minVal != null && maxVal != null && minVal > maxVal) {
        return 'Max Humidity must be ≥ Min Humidity';
      }
      return null;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  decoration: fieldDecoration.copyWith(labelText: 'Name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: coffee,
                  decoration: fieldDecoration.copyWith(labelText: 'Coffee Variety'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: ph,
                  decoration: fieldDecoration.copyWith(labelText: 'Target pH'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: validatePhEdit,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: tmin,
                        decoration: fieldDecoration.copyWith(labelText: 'Min Temp (°C)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: validateTempEdit,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: tmax,
                        decoration: fieldDecoration.copyWith(labelText: 'Max Temp (°C)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: validateMaxTempEdit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: humMin,
                        decoration: fieldDecoration.copyWith(labelText: 'Min Humidity (%)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: validateHumidityEdit,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: humMax,
                        decoration: fieldDecoration.copyWith(labelText: 'Max Humidity (%)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: validateMaxHumidityEdit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: durationCtrl,
                        decoration: fieldDecoration.copyWith(labelText: 'Duration'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final val = double.tryParse(v ?? '');
                          if (val == null) return 'Please enter a valid number';
                          if (val <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: durationUnit,
                        isExpanded: true,
                        isDense: true,
                        decoration: fieldDecoration.copyWith(labelText: 'Unit'),
                        items: const [
                          DropdownMenuItem(value: 'Minute', child: Text('Minute', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'Hour', child: Text('Hour', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'Day', child: Text('Day', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => durationUnit = v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final double phVal = double.parse(ph.text);
              final double tminVal = double.parse(tmin.text);
              final double tmaxVal = double.parse(tmax.text);
              final double humMinVal = double.parse(humMin.text);
              final double humMaxVal = double.parse(humMax.text);

              final double durationInput = double.parse(durationCtrl.text);
              final int durationMinutes;
              if (durationUnit == 'Day') {
                durationMinutes = (durationInput * 1440).round();
              } else if (durationUnit == 'Hour') {
                durationMinutes = (durationInput * 60).round();
              } else {
                durationMinutes = durationInput.round(); // Minute (testing)
              }

              final payload = {
                "id": p['id'],
                "name": name.text,
                "coffee_type": coffee.text,
                "target_ph": phVal,
                "target_temp_min": tminVal,
                "target_temp_max": tmaxVal,
                "target_humidity_min": humMinVal,
                "target_humidity_max": humMaxVal,
                "duration_minutes": durationMinutes
              };

              final ok = await api.updateProfile(payload);
              if (ok) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
                _load();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile')));
              }
            },
            child: const Text('Save'),
          )
        ],
        ),
      ),
    );
  }

  Future<void> _delete(dynamic p) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text("Delete '${p['name']}' ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure == true) {
      final ok = await api.deleteProfile(int.parse(p['id'].toString()));
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile removed')));
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (profiles.isEmpty) return const Center(child: Text('No profiles available'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: profiles.length,
        itemBuilder: (ctx, i) {
          final p = profiles[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              title: Text(p['name'] ?? ''),
              subtitle: Text(
                  'Temp: ${p['target_temp_min'] ?? '-'}°C — ${p['target_temp_max'] ?? '-'}°C\n'
                  'Humidity: ${humidityTargetDisplay(p['target_humidity_min'], p['target_humidity_max'])}\n'
                  'pH target: ${p['target_ph'] ?? '-'}\n'
                  'Duration: ${formatDurationMinutes(p['duration_minutes'])}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _edit(p)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(p)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------- HISTORY PAGE ------------------------
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ApiService api = ApiService();
  List<dynamic> hist = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final h = await api.fetchHistory();
    setState(() {
      hist = h;
      loading = false;
    });
  }

  Future<void> _delete(dynamic item) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete History'),
        content: Text("Delete history from ${item['start_time'] ?? item['created_at'] ?? '-'} ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure == true) {
      final id = int.tryParse(item['id'].toString()) ?? 0;
      final ok = await api.deleteHistory(id);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('History deleted')));
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to clear history')));
      }
    }
  }

  Color _statusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'berhasil':
        return Colors.green;
      case 'tidak berhasil':
        return Colors.red;
      case 'selesai':
        return Colors.blueGrey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (hist.isEmpty) return const Center(child: Text('No history available'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: hist.length,
        itemBuilder: (ctx, i) {
          final h = hist[i];
          final start = h['start_time'] ?? h['created_at'] ?? '-';
          final end = h['end_time'] ?? '-';
          final tmin = h['target_temp_min'] ?? h['target_temp'] ?? '-';
          final tmax = h['target_temp_max'] ?? '-';
          final humidityTargetText =
              humidityTargetDisplay(h['target_humidity_min'], h['target_humidity_max']);
          final finalHumidityText = finalHumidityDisplay(
              h['final_humidity'], h['target_humidity_min'], h['target_humidity_max']);
          final status = h['status'] ?? '-';
          final reason = h['reason'] ?? '';

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    h['name'] ?? '-',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _statusColor(status)),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Start: $start\nEnd: $end'),
                  const SizedBox(height: 4),
                  Text('Target Temperature: $tmin — $tmax °C'),
                  Text('Target Humidity: $humidityTargetText'),
                  Text('Final pH: ${h['final_ph'] ?? '-'}'),
                  Text('Final Humidity: $finalHumidityText'),
                  if (reason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Reason: $reason',
                        style: const TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _delete(h)),
            ),
          );
        },
      ),
    );
  }
}