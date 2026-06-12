import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobilna_aplikacija/screens/profil_ekran.dart';
import 'dart:convert';
import '../user_session.dart';
import 'login_ekran.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
//import 'package:geolocator/geolocator.dart';

class GlavniEkran extends StatefulWidget {
  const GlavniEkran({super.key});

  @override
  State<GlavniEkran> createState() => _GlavniEkranState();
}

class _GlavniEkranState extends State<GlavniEkran> {
  List<dynamic> parkingMesta = [];
  bool ucitavam = true;
  LatLng? mojaLokacija;
  LatLng parkingLokacija = const LatLng(44.8166, 20.4575);
  List<LatLng> ruta = [];

  @override
  void initState() {
    super.initState();
    fetchParkingStatus();
    mojaLokacija = const LatLng(44.8266, 20.4575);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRuta();
    });
  }

  Future<void> _fetchRuta() async {
    if (mojaLokacija == null) return;
    final url = "https://router.project-osrm.org/route/v1/driving/${mojaLokacija!.longitude},${mojaLokacija!.latitude};${parkingLokacija.longitude},${parkingLokacija.latitude}?overview=full&geometries=geojson&snapping=any";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List coords = data['routes'][0]['geometry']['coordinates'];
          setState(() {
            ruta = coords.map((c) => LatLng(c[1], c[0])).toList();
            parkingLokacija = ruta.last;
          });
        }
      }
    } catch (e) {
      //print("Greška pri dohvatanju rute: $e");
    }
  }

  Future<void> fetchParkingStatus() async {
    try {
      final response = await http.get(Uri.parse('http://10.0.2.2:8000/parking-status'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            parkingMesta = json.decode(response.body);
            ucitavam = false;
          });
        }
      }
    } catch (e) {
      //print("Greška pri dohvatanju: $e");
    }
  }

  Future<void> posaljiRezervaciju(int spotId) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/rezervisi'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"spot_id": spotId, "user_id": UserSession.loggedInUserId}),
    );
    if (response.statusCode == 200) fetchParkingStatus();
  }

  Future<void> posaljiOdrezervaciju(int spotId) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/odrezervisi'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"spot_id": spotId, "user_id": UserSession.loggedInUserId}),
    );
    if (response.statusCode == 200) fetchParkingStatus();
  }

  void _logout() {
    UserSession.loggedInUserId = null;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginEkran()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pametan Parking'),
        backgroundColor: Colors.blueAccent,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (value) {
              if (value == 'profil') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilEkran()));
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'profil', child: Text('Profil')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: ucitavam
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 200,
                  child: mojaLokacija == null
                      ? const Center(child: CircularProgressIndicator())
                      : FlutterMap(
                          key: ValueKey(ruta.length),
                          options: MapOptions(initialCenter: mojaLokacija!, initialZoom: 14),
                          children: [
                           TileLayer(
  urlTemplate:
      'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.example.mobilna_aplikacija',
),
                            PolylineLayer(polylines: [Polyline(points: ruta, color: Colors.blue, strokeWidth: 5)]),
                            MarkerLayer(markers: [
                              Marker(point: mojaLokacija!, child: const Icon(Icons.my_location, color: Colors.blue)),
                              Marker(point: parkingLokacija, child: const Icon(Icons.local_parking, color: Colors.red, size: 40)),
                            ]),
                          ],
                        ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16),
                    itemCount: parkingMesta.length,
                    itemBuilder: (context, index) {
                      final mesto = parkingMesta[index];
                      return _napraviParkingMesto(context, 'Mesto ${mesto['id']}', mesto['status'], mesto['id']);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _napraviParkingMesto(BuildContext context, String naziv, String status, int id) {
    Color boja = status == 'slobodno' ? Colors.green : (status == 'zauzeto' ? Colors.red : Colors.orange);
    return GestureDetector(
      onTap: () {
        if (status == 'slobodno') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Rezervacija: $naziv'),
              content: const Text('Da li želite da rezervišete ovo mesto?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani')),
                ElevatedButton(onPressed: () { posaljiRezervaciju(id); Navigator.pop(context); }, child: const Text('Potvrdi')),
              ],
            ),
          );
        } else if (status == 'rezervisano') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Otkaži rezervaciju: $naziv'),
              content: const Text('Da li želite da oslobodite ovo mesto?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani')),
                ElevatedButton(onPressed: () { posaljiOdrezervaciju(id); Navigator.pop(context); }, child: const Text('Da, oslobodi')),
              ],
            ),
          );
        }
      },
      child: Card(
        color: boja,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_parking, color: boja, size: 40),
            Text(naziv, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(status.toUpperCase(), style: TextStyle(color: boja)),
          ],
        ),
      ),
    );
  }
}