import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
  
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        final b = Birthday(name: data['name'], date: DateTime.parse(data['date']), phoneNumber: data['phoneNumber'] ?? "", isBirthday: data['isBirthday'] ?? true);
        _BirthdayListScreenState.copyGreetingStatic(b);
      }
    },
  );

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
    print("Firebase error: $e");
  }
  runApp(const BirthdayApp());
}

class Birthday {
  String id;
  final String name;
  final DateTime date;
  final String phoneNumber;
  final bool isBirthday;

  Birthday({this.id = "", required this.name, required this.date, required this.phoneNumber, this.isBirthday = true});

  Map<String, dynamic> toJson() => {
    'name': name, 
    'date': date.toIso8601String(), 
    'phoneNumber': phoneNumber,
    'isBirthday': isBirthday
  };

  factory Birthday.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Birthday(
      id: doc.id, 
      name: data['name'] ?? "", 
      date: DateTime.parse(data['date']), 
      phoneNumber: data['phoneNumber'] ?? "",
      isBirthday: data['isBirthday'] ?? true,
    );
  }
}

class BirthdayListScreen extends StatefulWidget {
  const BirthdayListScreen({super.key});
  @override
  State<BirthdayListScreen> createState() => _BirthdayListScreenState();
}

class _BirthdayListScreenState extends State<BirthdayListScreen> {
  final CollectionReference _db = FirebaseFirestore.instance.collection('birthdays');
  final stt.SpeechToText _speech = stt.SpeechToText();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  void _requestPermissions() async {
    final android = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'birthday_urgent_v4', 
      'Peringatan Pintar (Urgent)', 
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await android?.createNotificationChannel(channel);
  }

  static void copyGreetingStatic(Birthday b) {
    if (!b.isBirthday) {
      Clipboard.setData(ClipboardData(text: "Peringatan: ${b.name} pada ${DateFormat('dd MMM yyyy HH:mm').format(b.date)}"));
      return;
    }
    final age = DateTime.now().year - b.date.year;
    final now = DateTime.now();
    DateTime bdayThisYear = DateTime(now.year, b.date.month, b.date.day);
    if (bdayThisYear.isBefore(DateTime(now.year, now.month, now.day))) bdayThisYear = DateTime(now.year + 1, b.date.month, b.date.day);
    
    Map<String, String> days = {'Monday': 'Isnin', 'Tuesday': 'Selasa', 'Wednesday': 'Rabu', 'Thursday': 'Khamis', 'Friday': 'Jumaat', 'Saturday': 'Sabtu', 'Sunday': 'Ahad'};
    String dayName = days[DateFormat('EEEE').format(bdayThisYear)] ?? DateFormat('EEEE').format(bdayThisYear);
    String formattedDate = "${bdayThisYear.day}${DateFormat('MMM').format(bdayThisYear)}${bdayThisYear.year} $dayName";

    final text = """🌟。🤩。😉。🍀
  。🎁 。🎉 。🌟
 ✨。＼｜／。🌺

SANNAH HELWAH 

Selamat Hari Lahir 
${b.name}✨
ke-$age
$formattedDate

👱‍♂️ Semoga dipanjangkan umur
😂  Ceria Selalu
🏧  Dimurahkan Rezeki sentiasa
💪🏼  Diberikan Kesihatan yang berpanjangan
📿  Ditetapkan Iman
 🤲🏻 Berbahagia Dunia Akhirat 
🕋  Serta mendapat Keberkatan dalam hidup

  °   آمِيّنْ.. آمِيّنْ.. آمِّيْنَ يَا رَبَّ الْعَالَمِيْنَ..""";
    
    Clipboard.setData(ClipboardData(text: text));
  }

  int _daysUntilNextBirthday(DateTime birthday) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime next = DateTime(now.year, birthday.month, birthday.day);
    if (next.isBefore(today)) next = DateTime(now.year + 1, birthday.month, birthday.day);
    return next.difference(today).inDays;
  }

  Future<void> _scheduleSmartNotification(Birthday b) async {
    if (kIsWeb) return;
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(b.date, tz.local);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      b.hashCode,
      b.isBirthday ? '🎂 Hari Jadi Hari Ini!' : '🔔 Peringatan Tugasan!',
      '${b.name}',
      scheduledDate,
      const NotificationDetails(android: AndroidNotificationDetails('birthday_urgent_v4', 'Peringatan Pintar', importance: Importance.max, priority: Priority.high, fullScreenIntent: true)),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(b.toJson()),
    );
  }

  void _showAddSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isBirthday = true;
    bool isListening = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void toggleListen() async {
            if (!isListening) {
              bool available = await _speech.initialize();
              if (available) {
                setModalState(() => isListening = true);
                _speech.listen(onResult: (val) => setModalState(() => nameController.text = val.recognizedWords));
              }
            } else {
              setModalState(() => isListening = false);
              _speech.stop();
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 10),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tambah Rekod Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    ChoiceChip(label: const Text("🎂 Hari Jadi"), selected: isBirthday, onSelected: (s) => setModalState(() => isBirthday = true)),
                    const SizedBox(width: 10),
                    ChoiceChip(label: const Text("🚀 Tugasan"), selected: !isBirthday, onSelected: (s) => setModalState(() => isBirthday = false)),
                  ]),
                  Row(children: [
                    Expanded(child: TextField(controller: nameController, decoration: InputDecoration(labelText: isBirthday ? 'Nama' : 'Tugasan'))),
                    IconButton(icon: Icon(isListening ? Icons.mic : Icons.mic_none, color: Colors.pink), onPressed: toggleListen)
                  ]),
                  TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'WhatsApp (Opsyenal)')),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ListTile(title: Text(DateFormat('dd/MM/yyyy').format(selectedDate)), leading: const Icon(Icons.calendar_today), onTap: () async {
                      final p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(1900), lastDate: DateTime(2100));
                      if (p != null) setModalState(() => selectedDate = p);
                    })),
                    if (!isBirthday) Expanded(child: ListTile(title: Text(selectedTime.format(context)), leading: const Icon(Icons.access_time), onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: selectedTime);
                      if (t != null) setModalState(() => selectedTime = t);
                    })),
                  ]),
                  ElevatedButton(onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      final finalDate = isBirthday ? DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 8, 0) : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                      final b = Birthday(name: nameController.text, date: finalDate, phoneNumber: phoneController.text, isBirthday: isBirthday);
                      _db.add(b.toJson());
                      _scheduleSmartNotification(b);
                      Navigator.pop(context);
                    }
                  }, child: const Text('Simpan')),
                  const SizedBox(height: 20)
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 Peringatan Pintar AI'),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.blue), onPressed: () => setState(() {}))],
      ),
      body: _selectedIndex == 0 
          ? _buildList(true) // Tab Hari Jadi
          : _buildList(false), // Tab Tugasan
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.pinkAccent,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.cake), label: "Hari Jadi"),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "Tugasan"),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddSheet, child: const Icon(Icons.add)),
    );
  }

  Widget _buildList(bool isBirthdayTab) {
    return StreamBuilder<QuerySnapshot>(
      // Kita ambil semua data dahulu supaya rekod lama tidak tercicir
      stream: _db.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // Tukar data Firestore kepada senarai objek Birthday
        List<Birthday> allItems = snapshot.data!.docs.map((doc) => Birthday.fromFirestore(doc)).toList();
        
        // Tapis data: Rekod lama (tanpa field isBirthday) akan masuk ke tab Hari Jadi secara automatik
        List<Birthday> items = allItems.where((item) => item.isBirthday == isBirthdayTab).toList();
        
        if (isBirthdayTab) {
          items.sort((a, b) => _daysUntilNextBirthday(a.date).compareTo(_daysUntilNextBirthday(b.date)));
        } else {
          items.sort((a, b) => a.date.compareTo(b.date));
        }

        if (items.isEmpty) return Center(child: Text(isBirthdayTab ? 'Tiada rekod Hari Jadi.' : 'Tiada tugasan masa hadapan.'));

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final b = items[index];
            final daysLeft = isBirthdayTab ? _daysUntilNextBirthday(b.date) : b.date.difference(DateTime.now()).inDays;
            return Card(
              color: (isBirthdayTab && daysLeft == 0) ? Colors.pink[50] : Colors.white,
              child: ListTile(
                title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(isBirthdayTab ? "${DateFormat('dd MMM').format(b.date)} • $daysLeft hari lagi" : "${DateFormat('dd MMM yyyy • HH:mm').format(b.date)}"),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.copy, color: Colors.blue), onPressed: () { copyGreetingStatic(b); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ucapan disalin!"))); }),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _db.doc(b.id).delete()),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class BirthdayApp extends StatelessWidget {
  const BirthdayApp({super.key});
  @override
  Widget build(BuildContext context) { return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent), useMaterial3: true), home: const BirthdayListScreen()); }
}
