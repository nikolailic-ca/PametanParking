import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Potrebno za Timer
import '../user_session.dart';

class ProfilEkran extends StatefulWidget {
  const ProfilEkran({super.key});

  @override
  State<ProfilEkran> createState() => _ProfilEkranState();
}

class _ProfilEkranState extends State<ProfilEkran> {
  Map<String, dynamic> korisnik = {};
  bool ucitavam = true;
  Duration preostaloVreme = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchProfil();
  }

  @override
  void dispose() {
    _timer?.cancel(); // OBAVEZNO: Ugasi timer kad izađeš sa ekrana
    super.dispose();
  }

  Future<void> fetchProfil() async {
    final response = await http.get(Uri.parse('https://pametanparking-production.up.railway.app/profil/${UserSession.loggedInUserId}'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        korisnik = data;
        ucitavam = false;
        if (korisnik['rezervacija'] != null) {
          startajTimer(
            DateTime.parse(
              korisnik['rezervacija']['expire_time']
            ).add(const Duration(hours: 2))
          );
        }
      });
    }
  }

  void startajTimer(DateTime expireTime) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final sada = DateTime.now();
      final razlika = expireTime.difference(sada);
      if (razlika.isNegative) {
        timer.cancel();
        setState(() => preostaloVreme = Duration.zero);
      } else {
        setState(() => preostaloVreme = razlika);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String formatVreme = "${preostaloVreme.inMinutes}:${(preostaloVreme.inSeconds % 60).toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(title: const Text('Moj Profil'), backgroundColor: Colors.blueAccent),
      body: ucitavam ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Card(child: ListTile(leading: const Icon(Icons.person), title: Text(korisnik['name']), subtitle: Text(korisnik['email']))),
            const SizedBox(height: 20),
            if (korisnik['rezervacija'] != null &&
    preostaloVreme.inSeconds > 0)
              Card(
                color: Colors.blue[50],
                child: ListTile(
                  leading: const Icon(Icons.timer, color: Colors.blueAccent),
                  title: Text('Rezervisano mesto: ${korisnik['rezervacija']['spot_id']}'),
                  trailing: Text(formatVreme, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}