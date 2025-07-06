import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = '';
  bool pumpStatus = false;
  bool fanStatus = false;
  double temperature = 0.0;
  double humidity = 0.0;
  double soilMoisture = 0.0;
  bool automatic = true; // true = Automatic, false = Manual
  bool _showQuickActions = false; // State for quick actions visibility
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
    } else {
      _loadUserData();
      _setupDatabaseListeners();
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userData.exists) {
          setState(() {
            userName = userData.data()?['name'] ?? 'User';
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load user data: $e'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }

  void _setupDatabaseListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _databaseRef
          .child('sensors/${user.uid}')
          .onValue
          .listen(
            (event) {
              final data = event.snapshot.value as Map?;
              if (data != null && mounted) {
                setState(() {
                  temperature =
                      (data['temperature'] as num?)?.toDouble() ?? 0.0;
                  humidity = (data['humidity'] as num?)?.toDouble() ?? 0.0;
                  soilMoisture =
                      (data['soil_moisture'] as num?)?.toDouble() ?? 0.0;
                  fanStatus = (data['fan_state'] as bool?) ?? false;
                  pumpStatus = (data['pump_state'] as bool?) ?? false;
                });
              }
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Database error: $error')),
                );
              }
            },
          );

      _databaseRef
          .child('controls/${user.uid}')
          .onValue
          .listen(
            (event) {
              final data = event.snapshot.value as Map?;
              if (data != null && mounted) {
                setState(() {
                  fanStatus = (data['fan'] as bool?) ?? fanStatus;
                  pumpStatus = (data['pump'] as bool?) ?? pumpStatus;
                  automatic =
                      (data['mode'] as bool?) ??
                      automatic; // Inverted logic: true = Automatic
                });
              }
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Controls database error: $error')),
                );
              }
            },
          );
    }
  }

  void _sendControlCommand({bool? fan, bool? pump, bool? mode}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = _databaseRef.child('controls/${user.uid}');
      ref
          .set({
            'fan': fan ?? fanStatus,
            'pump': pump ?? pumpStatus,
            'mode': mode ?? automatic, // true = Automatic, false = Manual
          })
          .then((_) {
            setState(() {
              if (fan != null) fanStatus = fan;
              if (pump != null) pumpStatus = pump;
              if (mode != null) automatic = mode;
            });
          })
          .catchError((error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to send command: $error')),
              );
            }
          });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _toggleQuickActions() {
    setState(() {
      _showQuickActions = !_showQuickActions;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: const Text(
          'Smart Farming',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: null,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.white),
            onPressed: _toggleQuickActions,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, $userName',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Monitor and control your smart farming system',
                    style: TextStyle(fontSize: 14, color: AppColors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sensors',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSensorCard(
                    'Temperature',
                    '${temperature.toStringAsFixed(1)}°C',
                    Icons.thermostat,
                    AppColors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSensorCard(
                    'Humidity',
                    '${humidity.toStringAsFixed(1)}%',
                    Icons.water_drop,
                    AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSensorCard(
              'Soil Moisture',
              '${soilMoisture.toStringAsFixed(1)}%',
              Icons.grass,
              AppColors.primaryGreen,
            ),
            const SizedBox(height: 24),
            const Text(
              'Controls',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 12),
            _buildControlCard(
              'Mode',
              'Automatic/Manual Control',
              Icons.settings,
              !automatic, // Inverted: off = Automatic, on = Manual
              (value) {
                setState(() {
                  automatic = !value; // Invert logic
                });
                _sendControlCommand(mode: !value); // Send inverted value
              },
              modeText: automatic ? 'Automatic' : 'Manual',
            ),
            const SizedBox(height: 12),
            _buildControlCard(
              'Pump',
              'Water irrigation system',
              Icons.water,
              pumpStatus,
              (value) {
                setState(() {
                  pumpStatus = value;
                });
                _sendControlCommand(pump: value);
              },
            ),
            const SizedBox(height: 12),
            _buildControlCard(
              'Fan',
              'Ventilation control',
              Icons.air,
              fanStatus,
              (value) {
                setState(() {
                  fanStatus = value;
                });
                _sendControlCommand(fan: value);
              },
            ),
            if (_showQuickActions) ...[
              const SizedBox(height: 24),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                'Logout',
                Icons.logout,
                AppColors.red,
                _logout,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.mediumGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged, {
    String? modeText,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mediumGray,
                  ),
                ),
                if (modeText != null)
                  Text(
                    modeText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGray,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: user != null
                ? (newValue) {
                    onChanged(newValue);
                    _sendControlCommand(
                      fan: title == 'Fan' ? newValue : null,
                      pump: title == 'Pump' ? newValue : null,
                      mode: title == 'Mode'
                          ? !newValue
                          : null, // Invert for mode
                    );
                  }
                : null,
            activeColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
