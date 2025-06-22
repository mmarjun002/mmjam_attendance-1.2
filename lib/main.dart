import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Logger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.white,
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> authenticateWithBiometrics() async {
    final bool canAuthenticate = await auth.canCheckBiometrics;
    if (!canAuthenticate) return false;

    try {
      return await auth.authenticate(
        localizedReason: 'Scan fingerprint to log in',
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (e) {
      return false;
    }
  }

  void logAttendance(String uid) async {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final formattedTime = DateFormat('HH:mm:ss').format(now);

    await FirebaseFirestore.instance.collection('attendance').add({
      'userId': uid,
      'timestamp': now,
      'date': formattedDate,
      'time': formattedTime,
    });
  }

  void handleLogin(BuildContext context) async {
    final success = await authenticateWithBiometrics();
    if (success) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        logAttendance(user.uid);
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final role = snapshot.data()?['role'] ?? 'personnel';
        if (role == 'admin') {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => AdminPanel()));
        } else {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => DashboardScreen()));
        }
      } else {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        logAttendance(userCredential.user!.uid);
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => DashboardScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Biometric authentication failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance Logger')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
              backgroundColor: Colors.teal,
            ),
            icon: Icon(Icons.fingerprint),
            label: Text(
              'Login with Fingerprint',
              style: TextStyle(fontSize: 18),
            ),
            onPressed: () => handleLogin(context),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: Center(
        child: Text(
          'You are logged in. Attendance recorded.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class AdminPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Panel')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: EdgeInsets.all(10),
            separatorBuilder: (_, __) => Divider(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return ListTile(
                leading: Icon(Icons.access_time),
                title: Text("User: ${data['userId']}"),
                subtitle: Text("${data['date']} at ${data['time']}"),
              );
            },
          );
        },
      ),
    );
  }
}
