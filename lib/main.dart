
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
      title: 'Attendance App',
      theme: ThemeData(primarySwatch: Colors.blue),
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
        localizedReason: 'Scan your fingerprint to log in',
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
        final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final role = snapshot.data()?['role'] ?? 'personnel';
        if (role == 'admin') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPanel()));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardScreen()));
        }
      } else {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        logAttendance(userCredential.user!.uid);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardScreen()));
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
      appBar: AppBar(title: Text('Personnel Login')),
      body: Center(
        child: ElevatedButton(
          child: Text('Login with Fingerprint'),
          onPressed: () => handleLogin(context),
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
      body: Center(child: Text('You are logged in. Attendance recorded.')),
    );
  }
}

class AdminPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Panel')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('attendance').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return ListTile(
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
