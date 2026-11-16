import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/attendance.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  final bool showAppBar;
  const AttendanceScreen({super.key, this.showAppBar = true});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    final content = Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.blue[800], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40))),
          child: Column(
            children: [
              if (user?.profilePhoto != null)
                CircleAvatar(radius: 40, backgroundImage: NetworkImage(user!.profilePhoto!))
              else
                const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
              const SizedBox(height: 16),
              Text(user?.fullName ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(user?.assignedRole ?? 'Staff', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.nfc, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Tap your RFID card at the device',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today\'s Log Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<AttendanceModel>>(
                    stream: firestoreService.streamAttendance(),
                    builder: (context, snapshot) {
                      final now = DateTime.now();
                      final logs = snapshot.data?.where((l) => 
                        l.staffId == user?.uid && 
                        l.timestamp.year == now.year && 
                        l.timestamp.month == now.month && 
                        l.timestamp.day == now.day
                      ).toList() ?? [];
                      
                      if (logs.isEmpty) return const Center(child: Text('No attendance logs for today.'));
                      
                      return ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final l = logs[index];
                          return ListTile(
                            leading: Icon(l.type == 'Time-In' ? Icons.login : Icons.logout, color: l.type == 'Time-In' ? Colors.green : Colors.red),
                            title: Text(l.type),
                            subtitle: Text(DateFormat('MMM dd, yyyy').format(l.timestamp)),
                            trailing: Text(DateFormat('hh:mm:ss a').format(l.timestamp), style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        },
                      );
                    }
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Shift Time Tracking'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: content,
    );
  }
}
