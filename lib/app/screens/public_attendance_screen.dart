import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/config/scan_config.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/app_user.dart';
import 'package:intl/intl.dart';

class PublicAttendanceScreen extends StatefulWidget {
  const PublicAttendanceScreen({super.key});

  @override
  State<PublicAttendanceScreen> createState() => _PublicAttendanceScreenState();
}

class _PublicAttendanceScreenState extends State<PublicAttendanceScreen> {
  String _selectedType = 'Time-In';
  bool _isProcessing = false;
  Map<String, dynamic>? _successData;
  String? _error;
  String? _selectedStaffId;

  void _onLogAttendance() async {
    if (_selectedStaffId == null) return;
    setState(() {
      _isProcessing = true;
      _error = null;
      _successData = null;
    });

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_selectedStaffId!).get();
      if (!userDoc.exists) throw Exception('Staff not found.');
      final user = AppUser.fromMap(userDoc.data() as Map<String, dynamic>, userDoc.id);

      if (user.rfidUid == null || user.rfidUid!.isEmpty) {
        throw Exception('No RFID card assigned to ${user.fullName}.');
      }

      final response = await http.post(
        Uri.parse(scanUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': user.rfidUid, 'device': 'APP'}),
      );

      final code = response.statusCode;
      final body = response.body;

      if (code != 200) {
        throw Exception('Scan failed ($code): $body');
      }
      
      setState(() {
        _successData = {
          'name': user.fullName,
          'photo': user.profilePhoto,
          'timestamp': DateTime.now(),
        };
        _isProcessing = false;
        _selectedStaffId = null;
      });

      // Auto-reset UI for next person after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _successData = null);
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception:', '');
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(title: const Text('Public Attendance Station')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_successData == null) ...[
                const Icon(Icons.badge_outlined, size: 80, color: Colors.blueGrey),
                const SizedBox(height: 24),
                const Text(
                  'Select action and your name to log attendance',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    _typeBtn('Time-In', Colors.green),
                    const SizedBox(width: 16),
                    _typeBtn('Time-Out', Colors.red),
                  ],
                ),
                const SizedBox(height: 48),
                
                StreamBuilder<List<AppUser>>(
                  stream: fs.streamStaffAccounts(),
                  builder: (context, snapshot) {
                    final staff = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedStaffId,
                      decoration: const InputDecoration(labelText: 'Select Your Name', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                      items: staff.map((s) => DropdownMenuItem<String>(
                        value: s.uid, 
                        child: Text(s.fullName)
                      )).toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setState(() {
                            _selectedStaffId = v;
                          });
                          _onLogAttendance();
                        }
                      },
                    );
                  }
                ),
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: CircularProgressIndicator(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ] else ...[
                // Success View
                const Icon(Icons.check_circle, color: Colors.green, size: 100),
                const SizedBox(height: 24),
                if (_successData!['photo'] != null)
                  CircleAvatar(radius: 50, backgroundImage: NetworkImage(_successData!['photo'])),
                const SizedBox(height: 16),
                Text(
                  'Hello, ${_successData!['name']}!',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Successfully logged $_selectedType',
                  style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
                ),
                Text(
                  DateFormat('MMMM dd, HH:mm:ss').format(_successData!['timestamp']),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 48),
                const Text('Resetting for next person...', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBtn(String type, Color color) {
    bool active = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: active ? color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? color : Colors.grey[300]!),
            boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)] : null,
          ),
          child: Column(
            children: [
              Icon(type == 'Time-In' ? Icons.login : Icons.logout, color: active ? Colors.white : color),
              const SizedBox(height: 8),
              Text(
                type.toUpperCase(),
                style: TextStyle(color: active ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
