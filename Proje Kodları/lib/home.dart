import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mobil_proje/event_add_page.dart';
import 'package:mobil_proje/event_discovery_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final Set<Marker> _markers = {};
  late GoogleMapController mapController;
  final LatLng _initialPosition = const LatLng(
      39.9334, 32.8597);

  @override
  void initState() {
    super.initState();
  
    _loadEventLocations(); 
  }

  Future<void> _loadEventLocations() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('events').get();
    Set<Marker> newMarkers = {}; 

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      final marker = Marker(
        markerId: MarkerId(data['name']),
        position: LatLng(data['latitude'], data['longitude']),
        infoWindow: InfoWindow(
          title: data['name'],
          snippet: data['description'],
          onTap: () {
            _launchMapsUrl(data['latitude'], data['longitude']);
          },
        ),
      );
      newMarkers.add(marker);
    }
    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
  }

  void _launchMapsUrl(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Harita açılamıyor $url';
    }
  }
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Harita'),
        actions: [
         
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 12.0,
              ),
              markers: _markers,
            ),
          ),
          Center(
            child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EventDiscoveryPage()),
              );
            },
            child: Text('Etkinlik Listesini Aç'),
          ),
          ),
        ],
      ),
    );
  }
}
