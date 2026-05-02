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
    RegExp dateReg = RegExp(r'(\d{1,2})[\/\-\. ]+(\d{1,2})[\/\-\. ]+(\d{2,4})');

    List<Map<String, dynamic>> allLines = [];
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        allLines.add({'text': line.text.trim(), 'y': line.boundingBox.top, 'x': line.boundingBox.left});
      }
    }

    for (var lineData in allLines) {
      String text = lineData['text'];
      DateTime? bday;
      String name = "";

      if (icReg.hasMatch(text)) {
        var match = icReg.firstMatch(text);
        String icNum = match!.group(0)!;
        String dobPart = match.group(1)!;
        int year = int.parse(dobPart.substring(0, 2));
        int month = int.parse(dobPart.substring(2, 4));
        int day = int.parse(dobPart.substring(4, 6));
        year += (year > (DateTime.now().year % 100)) ? 1900 : 2000;
        bday = DateTime(year, month, day, 8, 0);
        name = text.split(icNum)[0].trim();
      } else if (dateReg.hasMatch(text)) {
        var match = dateReg.firstMatch(text);
        int d = int.parse(match!.group(1)!);
        int m = int.parse(match.group(2)!);
        int y = int.parse(match.group(3)!);
        if (y < 100) y += 2000;
        try { bday = DateTime(y, m, d, 8, 0); name = text.split(match.group(0)!)[0].trim(); } catch (e) {}
      }

      if (bday != null) {
        name = name.replaceFirst(RegExp(r'^\d+\s*'), '').trim();
        if (name.length > 2) detected.add(Birthday(name: name, date: bday, phoneNumber: "", isBirthday: true));
      }
    }
    textRecognizer.close();

    if (detected.isNotEmpty) {
      final uniqueDetected = detected.toSet().toList();
      final existingDocs = await _db.get();
      final existingBirthdays = existingDocs.docs.map((doc) => Birthday.fromFirestore(doc)).toList();
      final toAdd = uniqueDetected.where((d) => !existingBirthdays.contains(d)).toList();

      if (toAdd.isNotEmpty) {
        _confirmDetectedBirthdays(toAdd);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semua rekod sudah wujud.")));
      }
    }
  }

  void _confirmDetectedBirthdays(List<Birthday> detected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dijumpai ${detected.length} Rekod Baru'),
        content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: detected.length, itemBuilder: (context, i) => ListTile(title: Text(detected[i].name), subtitle: Text(DateFormat('dd/MM/yyyy').format(detected[i].date))))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), 
          ElevatedButton(onPressed: () { 
            for (var b in detected) { 
              _db.add(b.toJson()); 
              _scheduleSmartNotification(b);
            } 
            Navigator.pop(context); 
          }, child: const Text('Tambah Semua'))
        ],
      ),
    );
  }

  void _confirmDelete(Birthday b) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sahkan Padam'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Masukkan kata laluan untuk memadam rekod ${b.name}:'),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Kata Laluan'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text == "219") {
                _db.doc(b.id).delete();
                flutterLocalNotificationsPlugin.cancel(b.hashCode);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kata laluan salah!"), backgroundColor: Colors.red));
              }
            },
            child: const Text('Padam'),
          ),
        ],
      ),
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
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Tambah Rekod Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.document_scanner, color: kIsWeb ? Colors.grey : Colors.blue), 
                      onPressed: () { if (!kIsWeb) { Navigator.pop(context); _scanBulkImage(); } }
                    ),
                  ]),
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
      stream: _db.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        List<Birthday> allItems = snapshot.data!.docs.map((doc) => Birthday.fromFirestore(doc)).toList();
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
            
            // Calculate age for birthday tab
            int age = DateTime.now().year - b.date.year;
            if (DateTime.now().month < b.date.month || (DateTime.now().month == b.date.month && DateTime.now().day < b.date.day)) age--;

            return Card(
              color: (isBirthdayTab && daysLeft == 0) ? Colors.pink[50] : Colors.white,
              child: ListTile(
                title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(isBirthdayTab 
                  ? "${DateFormat('dd MMM').format(b.date)} • $age thn • $daysLeft hari lagi" 
                  : "${DateFormat('dd MMM yyyy • HH:mm').format(b.date)}"),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.copy, color: Colors.blue), onPressed: () { copyGreetingStatic(b); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ucapan disalin!"))); }),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(b)),
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
