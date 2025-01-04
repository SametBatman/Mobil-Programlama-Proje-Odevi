import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobil_proje/event_add_page.dart';
import 'package:mobil_proje/home.dart';
import 'package:mobil_proje/login.dart';

import 'event_detail_page.dart';

class EventDiscoveryPage extends StatefulWidget {
  @override
  _EventDiscoveryPageState createState() => _EventDiscoveryPageState();
}

class _EventDiscoveryPageState extends State<EventDiscoveryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  String _searchQuery = '';
  String _selectedCategory = 'Tümü';
  final List<String> _categories = [
    'Tümü',
    'Müzik',
    'Spor',
    'Sanat',
    'Teknoloji',
    'Eğlence'
  ];
  User? _user;
  bool _notificationsEnabled = false;
  String _username = 'Bilinmiyor';
  String _email = 'Bilinmiyor';
  List<String> _favoriteEvents = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadUserData();
    _loadFavoriteEvents();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _user = FirebaseAuth.instance.currentUser;
        _email = _user?.email ?? 'Bilinmiyor';
      });

      if (_user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _username = userDoc['username'] ?? 'Bilinmiyor';
            _notificationsEnabled = userDoc['notificationsEnabled'] ?? false;
          });
        } else {
          print('Kullanıcı belgesi Firestore\'da bulunamadı.');
        }
      }
    } catch (e) {
      print('Kullanıcı verileri yüklenirken hata: $e');
    }
  }

  Future<void> _loadFavoriteEvents() async {
    if (_user != null) {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('favorites')
          .get();

      setState(() {
        _favoriteEvents = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .map((event) => event['name'] as String)
            .toList();
      });
    }
  }

  Future<void> _loadEvents() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('events').get();
    List<Map<String, dynamic>> events = snapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': data['name'],
        'description': data['description'],
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'category': data['category'],
        'date': data['date'],
        'imageUrl': data['imageUrl'] ?? '',
        'comments': data['comments'] ?? [],
        'organizer': data['organizer'] ?? 'Bilinmiyor',
      };
    }).toList();

    setState(() {
      _events = events;
      _filteredEvents = events;
    });
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents = _events.where((event) {
        final matchesCategory = _selectedCategory == 'Tümü' ||
            event['category'] == _selectedCategory;
        final matchesSearch =
            event['name'].toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  Future<void> _updateUsername(String username) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .update({'username': username});

      setState(() {
        _username = username;
      });
    } catch (e) {
      _showDialog('Hata', 'Kullanıcı adı güncellenemedi: ${e.toString()}');
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

  Future<void> _toggleNotification(bool value, BuildContext context) async {
    if (_user != null) {
      try {
        setState(() {
          _notificationsEnabled = value;
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .update({'notificationsEnabled': value});
      } catch (e) {
        setState(() {
          _notificationsEnabled = !value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bildirim ayarı güncellenemedi: $e')),
        );
      }
    }
  }

  Future<void> _updateEmail(String email) async {
    try {
      await _user!.updateEmail(email);
      await _user!.reload();
      _user = _auth.currentUser;

      _loadUserData();

      _showDialog('Başarılı',
          'E-posta başarıyla güncellendi. Lütfen yeni e-posta adresinizle giriş yapın.');

      await _auth.signOut();
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      _showDialog('Hata', 'E-posta güncellenemedi: ${e.toString()}');
    }
  }

  void _showEditDialog(
      String title, String currentValue, Function(String) onSave) {
    TextEditingController controller =
        TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$title Düzenle'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: title),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                onSave(controller.text);
                Navigator.of(context).pop();
                _loadUserData();
              },
              child: Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context) async {
    await _loadFavoriteEvents();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ayarlar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Kullanıcı Adı',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_username),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showEditDialog('Kullanıcı Adı', _username, (value) {
                        _updateUsername(value);
                      });
                    },
                  ),
                ),
                Divider(),
                ListTile(
                  title: Text('E-posta',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_email),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showEditDialog('E-posta', _email, (value) {
                        _updateEmail(value);
                      });
                    },
                  ),
                ),
                Divider(),
                ListTile(
                  title: Text('Bildirim Almak İstiyorum'),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (bool value) {
                      _toggleNotification(value, context);
                                          Navigator.of(context).pop();

                    },
                  ),
                ),
                Divider(),
                ExpansionTile(
                  title: Text('Favori Etkinlikler',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  children: _favoriteEvents.isNotEmpty
                      ? _favoriteEvents.map((event) {
                          return ListTile(
                            title: Text(event),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16.0),
                          );
                        }).toList()
                      : [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Henüz favori etkinlik yok'),
                          ),
                        ],
                ),
                Divider(),
                ElevatedButton(
                  onPressed: () async {
                    await _auth.signOut();
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: Text('Çıkış Yap'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Etkinlik Keşfet'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: _selectedCategory,
              items: _categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                  _filterEvents();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Etkinlik Ara...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterEvents();
                });
              },
            ),
          ),
          Expanded(
            child: _filteredEvents.isEmpty
                ? Center(
                    child: Text(
                      'Henüz etkinlik yok.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = _filteredEvents[index];
                      return Card(
                        margin: EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        child: ListTile(
                          leading: event['imageUrl'] != ''
                              ? Image.network(event['imageUrl'],
                                  width: 50, height: 50, fit: BoxFit.cover)
                              : Icon(Icons.event, size: 50),
                          title: Text(event['name']),
                          subtitle: Text(
                              '${event['description']} - ${event['date']}'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EventDetailPage(event: event),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            },
            child: Text('Etkinliklere Haritada Bak'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EventAddPage()),
              ).then((value) {
                _loadEvents();
              });
            },
            child: Text('Etkinlik Oluştur'),
          ),
        ],
      ),
    );
  }
}
