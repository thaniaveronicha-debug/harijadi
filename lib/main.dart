import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Timezone
  tz.initializeTimeZones();
  
  // Initialize Notifications
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBR4rCkl8-zBsbGGw4XlxefcQCALj_Fwe0",
          authDomain: "birthday-cfe.firebaseapp.com",
          projectId: "birthday-cfe",
          storageBucket: "birthday-cfe.firebasestorage.app",
          messagingSenderId: "811132241802",
          appId: "1:811132241802:web:250b79ece8c528d5206a73",
          measurementId: "G-0TPLD9SGKD",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    print("Firebase init error: $e");
  }
  runApp(const BirthdayApp());
}

class Birthday {
  String id;
  final String name;
  final DateTime date;
  final String phoneNumber;

  Birthday({this.id = "", required this.name, required this.date, required this.phoneNumber});

  Map<String, dynamic> toJson() => {
        'name': name,
        'date': date.toIso8601String(),
        'phoneNumber': phoneNumber,
      };

  factory Birthday.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Birthday(
      id: doc.id,
      name: data['name'] ?? "",
      date: DateTime.parse(data['date']),
      phoneNumber: data['phoneNumber'] ?? "",
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Birthday &&
          runtimeType == other.runtimeType &&
          name.toLowerCase() == other.name.toLowerCase() &&
          date.day == other.date.day &&
          date.month == other.date.month &&
          date.year == other.date.year;

  @override
  int get hashCode => name.toLowerCase().hashCode ^ date.hashCode;
}

class BirthdayListScreen extends StatefulWidget {
  const BirthdayListScreen({super.key});

  @override
  State<BirthdayListScreen> createState() => _BirthdayListScreenState();
}

class _BirthdayListScreenState extends State<BirthdayListScreen> {
  final CollectionReference _db = FirebaseFirestore.instance.collection('birthdays');
  late stt.SpeechToText _speech;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestPermissions();
  }

  void _requestPermissions() {
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  int _daysUntilNextBirthday(DateTime birthday) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime next = DateTime(now.year, birthday.month, birthday.day);
    if (next.isBefore(today)) {
      next = DateTime(now.year + 1, birthday.month, birthday.day);
    }
    return next.difference(today).inDays;
  }

  Future<void> _scheduleNotification(Birthday bday) async {
    if (kIsWeb) return;

    DateTime now = DateTime.now();
    DateTime next = DateTime(now.year, bday.date.month, bday.date.day, 8, 0); // Pukul 8 Pagi
    if (next.isBefore(now)) {
      next = DateTime(now.year + 1, bday.date.month, bday.date.day, 8, 0);
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      bday.hashCode,
      '🎂 Hari Jadi Hari Ini!',
      'Jangan lupa ucapkan selamat hari jadi kepada ${bday.name}!',
      tz.TZDateTime.from(next, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'birthday_channel',
          'Peringatan Hari Jadi',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.monthDay,
    );
  }

  Future<void> _scanBulkImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Imbasan AI hanya di telefon.")));
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    
    List<Birthday> detected = [];
    RegExp icReg = RegExp(r'(\d{6})[-\s]?\d{2}[-\s]?\d{4}');

    List<Map<String, dynamic>> allLines = [];
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        allLines.add({'text': line.text.trim(), 'y': line.boundingBox.top, 'x': line.boundingBox.left});
      }
    }

    for (var lineData in allLines) {
      String text = lineData['text'];
      if (icReg.hasMatch(text)) {
        var match = icReg.firstMatch(text);
        String icNum = match!.group(0)!;
        String dobPart = match.group(1)!;

        int year = int.parse(dobPart.substring(0, 2));
        int month = int.parse(dobPart.substring(2, 4));
        int day = int.parse(dobPart.substring(4, 6));
        year += (year > (DateTime.now().year % 100)) ? 1900 : 2000;
        DateTime bday = DateTime(year, month, day);

        String name = text.split(icNum)[0].trim().replaceFirst(RegExp(r'^\d+\s*'), '');
        if (name.length < 3) {
          for (var other in allLines) {
            if (other['text'] != text && (other['y'] - lineData['y']).abs() < 15 && other['x'] < lineData['x']) {
              String t = other['text'];
              if (t.length > 3 && !t.contains(RegExp(r'\d{6}'))) {
                name = t.replaceFirst(RegExp(r'^\d+\s*'), '');
                break;
              }
            }
          }
        }
        if (name.length > 3) detected.add(Birthday(name: name, date: bday, phoneNumber: ""));
      }
    }
    textRecognizer.close();

    if (detected.isNotEmpty) {
      final uniqueDetected = detected.toSet().toList();
      final existingDocs = await _db.get();
      final existingBirthdays = existingDocs.docs.map((doc) => Birthday.fromFirestore(doc)).toList();
      final toAdd = uniqueDetected.where((d) => !existingBirthdays.contains(d)).toList();

      if (toAdd.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semua rekod sudah wujud.")));
      } else {
        _confirmDetectedBirthdays(toAdd);
      }
    }
  }

  void _confirmDetectedBirthdays(List<Birthday> detected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dijumpai ${detected.length} Rekod Baru'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: detected.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(detected[i].name),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(detected[i].date)),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              for (var b in detected) { 
                _db.add(b.toJson()); 
                _scheduleNotification(b);
              }
              Navigator.pop(context);
            },
            child: const Text('Tambah Semua'),
          ),
        ],
      ),
    );
  }

  void _showAddBirthdaySheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 10),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tambah Rekod', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.document_scanner, color: kIsWeb ? Colors.grey : Colors.blue), 
                      onPressed: () {
                        if (kIsWeb) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Imbasan AI di telefon.")));
                        } else {
                          Navigator.pop(context); _scanBulkImage();
                        }
                      }
                    ),
                  ],
                ),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Penuh')),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'WhatsApp')),
                ListTile(
                  title: Text("Tarikh: ${DateFormat('dd/MM/yyyy').format(selectedDate)}"),
                  onTap: () async {
                    final p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(1900), lastDate: DateTime.now());
                    if (p != null) setModalState(() => selectedDate = p);
                  },
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      final newBday = Birthday(name: nameController.text, date: selectedDate, phoneNumber: phoneController.text);
                      final existing = await _db.where('name', isEqualTo: newBday.name).where('date', isEqualTo: newBday.date.toIso8601String()).get();

                      if (existing.docs.isEmpty) {
                        _db.add(newBday.toJson());
                        _scheduleNotification(newBday);
                        if (mounted) Navigator.pop(context);
                      } else {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rekod ini sudah wujud!"), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎂 Peringatan AI'), 
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _isRefreshing ? Colors.grey : Colors.blue),
            onPressed: () async {
              setState(() => _isRefreshing = true);
              await Future.delayed(const Duration(seconds: 1));
              setState(() => _isRefreshing = false);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          List<Birthday> birthdays = snapshot.data!.docs.map((doc) => Birthday.fromFirestore(doc)).toList();
          birthdays.sort((a, b) => _daysUntilNextBirthday(a.date).compareTo(_daysUntilNextBirthday(b.date)));

          // Sync notifications when data is loaded
          for (var b in birthdays) { _scheduleNotification(b); }

          if (birthdays.isEmpty) return const Center(child: Text('Kosong. Klik + untuk tambah.'));

          return ListView.builder(
            itemCount: birthdays.length,
            itemBuilder: (context, index) {
              final b = birthdays[index];
              final daysLeft = _daysUntilNextBirthday(b.date);
              Color cardColor = daysLeft == 0 ? Colors.pinkAccent : (daysLeft <= 7 ? Colors.orange[100]! : (daysLeft <= 30 ? Colors.yellow[50]! : Colors.white));

              return Card(
                color: cardColor,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(b.name, style: TextStyle(fontWeight: FontWeight.bold, color: daysLeft == 0 ? Colors.white : Colors.black87)),
                  subtitle: Text("${DateFormat('dd MMM').format(b.date)} • ${daysLeft == 0 ? 'HARI INI!' : '$daysLeft hari lagi'}", style: TextStyle(color: daysLeft == 0 ? Colors.white70 : Colors.black54)),
                  trailing: IconButton(icon: Icon(Icons.delete, color: daysLeft == 0 ? Colors.white : Colors.red), onPressed: () {
                    _db.doc(b.id).delete();
                    flutterLocalNotificationsPlugin.cancel(b.hashCode);
                  }),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddBirthdaySheet, child: const Icon(Icons.add)),
    );
  }
}

class BirthdayApp extends StatelessWidget {
  const BirthdayApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent), useMaterial3: true), home: const BirthdayListScreen());
  }
}
