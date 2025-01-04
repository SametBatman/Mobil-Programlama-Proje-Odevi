import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EventAddPage extends StatefulWidget {
  @override
  _EventAddPageState createState() => _EventAddPageState();
}

class _EventAddPageState extends State<EventAddPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  String _category = 'Eğlence';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _imageUrl = '';
  bool _isFeatured = false;
  double? _latitude; 
  double? _longitude;

  final LatLng _initialPosition = LatLng(39.9334, 32.8597); 
  late GoogleMapController mapController;
  Marker? _selectedLocationMarker;

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate() &&
        _latitude != null &&
        _longitude != null &&
        _selectedDate != null &&
        _selectedTime != null) {
      _formKey.currentState!.save();

      try {
        User? currentUser = FirebaseAuth.instance.currentUser;

        String organizerName = 'Bilinmiyor';
        if (currentUser != null) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

          if (userDoc.exists && userDoc.data() != null) {
            Map<String, dynamic> userData =
                userDoc.data() as Map<String, dynamic>;
            organizerName = userData['username'] ?? 'Bilinmiyor';
          }
        }

        final selectedDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );

        await FirebaseFirestore.instance.collection('events').add({
          'name': _name,
          'description': _description,
          'latitude': _latitude,
          'longitude': _longitude,
          'category': _category,
          'date': selectedDateTime.toIso8601String(),
          'imageUrl': _imageUrl,
          'isFeatured': _isFeatured,
          'comments': [],
          'organizer': organizerName,
        });

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Etkinlik başarıyla eklendi!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Etkinlik eklenemedi: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen tüm alanları doldurun ve bir konum seçin!')),
      );
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _selectedLocationMarker = Marker(
        markerId: MarkerId('selected-location'),
        position: position,
        infoWindow: InfoWindow(title: 'Seçilen Konum'),
      );
    });
  }

  Future<void> _selectDateAndTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Etkinlik Ekle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Etkinlik Adı'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen etkinlik adını girin';
                  }
                  return null;
                },
                onSaved: (value) {
                  _name = value!;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Açıklama'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen açıklama girin';
                  }
                  return null;
                },
                onSaved: (value) {
                  _description = value!;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Kategori'),
                value: _category,
                items: ['Eğlence', 'Müzik', 'Spor', 'Sanat', 'Teknoloji']
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _category = value!;
                  });
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Görsel URL'),
                onSaved: (value) {
                  _imageUrl = value!;
                },
              ),
              Row(
                children: [
                  Text(
                    _selectedDate == null || _selectedTime == null
                        ? 'Tarih ve Saat Seçilmedi'
                        : 'Seçilen Tarih: ${_selectedDate!.toLocal()} Saat: ${_selectedTime!.format(context)}',
                  ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: () => _selectDateAndTime(context),
                    child: Text('Tarih ve Saat Seç'),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('Öne Çıkar'),
                  Spacer(),
                  Switch(
                    value: _isFeatured,
                    onChanged: (value) {
                      setState(() {
                        _isFeatured = value;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 10),
              Expanded(
                child: GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition,
                    zoom: 12.0,
                  ),
                  markers: _selectedLocationMarker != null ? {_selectedLocationMarker!} : {},
                  onTap: _onMapTap,
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _saveEvent,
                child: Text('Kaydet'),
              ),
              if (_latitude != null && _longitude != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Seçilen Konum: \nEnlem: $_latitude, Boylam: $_longitude',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
