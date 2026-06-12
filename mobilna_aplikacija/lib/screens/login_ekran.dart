import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'glavni_ekran.dart';
import 'registracija_ekran.dart';
import '../user_session.dart'; // OVO JE BILO NEOPHODNO

class LoginEkran extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  LoginEkran({super.key});

  Future<void> _login(BuildContext context) async {
    try {
      final response = await http.post(
        Uri.parse('https://pametanparking-production.up.railway.app/login'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "email": _emailController.text,
          "password": _passwordController.text
        }),
      );

      if (response.statusCode == 200) {
        // ISPRAVKA: Ovde hvatamo user_id i čuvamo ga u sesiju
        final data = json.decode(response.body);
        UserSession.loggedInUserId = data['user_id']; 
        
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GlavniEkran()),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pogrešni podaci!')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška servera: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prijava u sistem'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_parking, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Šifra',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _login(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('Prijavi se', style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RegistracijaEkran()),
              ),
              child: const Text('Nemaš nalog? Registruj se ovde.'),
            ),
          ],
        ),
      ),
    );
  }
}