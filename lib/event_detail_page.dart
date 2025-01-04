import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventDetailPage extends StatefulWidget {
  final Map<String, dynamic> event;

  EventDetailPage({required this.event});

  @override
  _EventDetailPageState createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _isFavorite = false;
  TextEditingController _commentController = TextEditingController();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  void _loadCurrentUser() {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _checkIfFavorite();
    }
  }

  Future<void> _checkIfFavorite() async {
    final eventId = widget.event['id'];
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('favorites')
        .doc(eventId)
        .get();

    setState(() {
      _isFavorite = doc.exists;
    });
  }

  Future<void> _addParticipant(String eventId) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      String username = userDoc.exists
          ? userDoc['username'] ?? 'Bilinmeyen Kullanıcı'
          : 'Bilinmeyen Kullanıcı';

      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('participants')
          .doc(currentUser.uid)
          .set({
        'userId': currentUser.uid,
        'username': username,
        'timestamp': Timestamp.now(),
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUser == null) return;

    final eventId = widget.event['id'];
    if (_isFavorite) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('favorites')
          .doc(eventId)
          .delete();
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('favorites')
          .doc(eventId)
          .set(widget.event);
    }

    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  Future<void> _addComment() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    String username = 'Bilinmeyen Kullanıcı';
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (userDoc.exists && userDoc.data() != null) {
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      username = userData['username'] ?? 'Bilinmeyen Kullanıcı';
    }

    if (_commentController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.event['id'])
        .collection('comments')
        .add({
      'comment': _commentController.text.trim(),
      'userId': currentUser.uid, 
      'username': username,
      'timestamp': Timestamp.now(),
    });

    _commentController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Yorum eklendi!')),
    );
  }

  void _launchMapsUrl(double latitude, double longitude) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      throw 'Harita açılamıyor: $googleMapsUrl';
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Scaffold(
      appBar: AppBar(
        title: Text(event['name']),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event['imageUrl'] != '')
                Image.network(
                  event['imageUrl'],
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              SizedBox(height: 16),
              Text(
                event['name'],
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Kategori: ${event['category']}',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              Text(
                'Tarih: ${event['date']}',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              Text(
                'Düzenleyen: ${event['organizer']}',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 16),
              Text(
                event['description'],
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _launchMapsUrl(event['latitude'], event['longitude']);
                },
                icon: Icon(Icons.map),
                label: Text('Konuma Git'),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : null,
                ),
                label: Text(
                    _isFavorite ? 'Favorilerden Çıkar' : 'Favorilere Ekle'),
              ),
              ElevatedButton.icon(
                onPressed: () => _addParticipant(widget.event['id']),
                icon: Icon(Icons.person_add),
                label: Text('Etkinliğe Katıl'),
              ),
              SizedBox(height: 16),
              Divider(),
              Text(
                'Katılımcılar:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .doc(widget.event['id'])
                    .collection('participants')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final participants = snapshot.data!.docs;

                  if (participants.isEmpty) {
                    return Text('Henüz katılımcı yok.');
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final participant = participants[index];
                      return ListTile(
                        leading: Icon(Icons.person),
                        title: Text(
                            participant['username'] ?? 'Bilinmeyen Kullanıcı'),
                        subtitle: Text(
                          'Katılım Tarihi: ${(participant['timestamp'] as Timestamp).toDate()}',
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 16),
              Divider(),
              Text(
                'Yorumlar:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Yorumunuzu yazın...',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send),
                    onPressed: _addComment,
                  ),
                ),
              ),
              SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .doc(widget.event['id'])
                    .collection('comments')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final comments = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return ListTile(
                        title: Text(comment['comment']),
                        subtitle: Text('Kullanıcı ID: ${comment['username']}'),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
