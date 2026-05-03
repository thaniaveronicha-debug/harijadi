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
import 'package:google_fonts/google_fonts.dart';

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
  String _searchQuery = "";

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
        title: Text('Dijumpai ${detected.length} Rekod Baru', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
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
        title: Text('Sahkan Padam', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan kata laluan untuk memadam rekod:', textAlign: TextAlign.center),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
                labelText: 'Kata Laluan',
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
    bool isBirthday = _selectedIndex == 0;
    bool isListening = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 10),
        child: StatefulBuilder(
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

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.symmetric(vertical: 10)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(isBirthday ? 'Tambah Hari Jadi' : 'Tambah Tugasan', style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    IconButton(
                      icon: Icon(Icons.document_scanner, color: kIsWeb ? Colors.grey : Colors.blueAccent), 
                      onPressed: () { if (!kIsWeb) { Navigator.pop(context); _scanBulkImage(); } }
                    ),
                  ]),
                  const SizedBox(height: 15),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    FilterChip(label: const Text("🎂 Hari Jadi"), selected: isBirthday, onSelected: (s) => setModalState(() => isBirthday = true)),
                    const SizedBox(width: 10),
                    FilterChip(label: const Text("🚀 Tugasan"), selected: !isBirthday, onSelected: (s) => setModalState(() => isBirthday = false)),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController, 
                    decoration: InputDecoration(
                      labelText: isBirthday ? 'Nama Penuh' : 'Tajuk Tugasan',
                      prefixIcon: Icon(isBirthday ? Icons.person_outline : Icons.task_outlined),
                      suffixIcon: IconButton(icon: Icon(isListening ? Icons.mic : Icons.mic_none, color: Colors.pink), onPressed: toggleListen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    )
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: phoneController, 
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'WhatsApp (Opsyenal)',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    )
                  ),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(color: Colors.pink[50], borderRadius: BorderRadius.circular(15)),
                    child: Row(children: [
                      Expanded(child: ListTile(
                        title: Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis), 
                        subtitle: const Text("Tarikh", style: TextStyle(fontSize: 11)),
                        leading: const Icon(Icons.calendar_month, color: Colors.pinkAccent, size: 20), 
                        onTap: () async {
                          final p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(1900), lastDate: DateTime(2100));
                          if (p != null) setModalState(() => selectedDate = p);
                        }
                      )),
                      if (!isBirthday) Expanded(child: ListTile(
                        title: Text(selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis), 
                        subtitle: const Text("Masa", style: TextStyle(fontSize: 11)),
                        leading: const Icon(Icons.access_time, color: Colors.pinkAccent, size: 20), 
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: selectedTime);
                          if (t != null) setModalState(() => selectedTime = t);
                        }
                      )),
                    ]),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: () {
                        if (nameController.text.isNotEmpty) {
                          final finalDate = isBirthday ? DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 8, 0) : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                          final b = Birthday(name: nameController.text, date: finalDate, phoneNumber: phoneController.text, isBirthday: isBirthday);
                          _db.add(b.toJson());
                          _scheduleSmartNotification(b);
                          Navigator.pop(context);
                        }
                      }, 
                      child: const Text('Simpan Rekod', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                    ),
                  ),
                  const SizedBox(height: 20)
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    int crossAxisCount = width > 1200 ? 3 : (width > 800 ? 2 : 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.pinkAccent,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _selectedIndex == 0 ? 'Hari Jadi' : 'Tugasan Pintar', 
                style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.2)
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.pinkAccent, Colors.orangeAccent]),
                ),
                child: Stack(
                  children: [
                    Positioned(right: -30, bottom: -30, child: Icon(Icons.cake, size: 180, color: Colors.white.withOpacity(0.12))),
                    Positioned(left: 30, top: 60, child: Icon(Icons.celebration, size: 100, color: Colors.white.withOpacity(0.12))),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => setState(() {})),
            ],
          ),
          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Cari ${_selectedIndex == 0 ? "nama" : "tugasan"}...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                ),
              ),
            ),
          ),
          _buildListStream(crossAxisCount),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15)]),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() { _selectedIndex = index; _searchQuery = ""; }),
          selectedItemColor: Colors.pinkAccent,
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.cake_rounded), label: "Hari Jadi"),
            BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_motion_rounded), label: "Tugasan"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet, 
        backgroundColor: Colors.pinkAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Tambah"),
      ),
    );
  }

  Widget _buildListStream(int crossAxisCount) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SliverFillRemaining(child: Center(child: Text('Tiada rekod dijumpai.')));
        
        bool isBirthdayTab = _selectedIndex == 0;
        List<Birthday> allItems = snapshot.data!.docs.map((doc) => Birthday.fromFirestore(doc)).toList();
        
        List<Birthday> items = allItems.where((item) => 
          item.isBirthday == isBirthdayTab && 
          item.name.toLowerCase().contains(_searchQuery)
        ).toList();
        
        if (isBirthdayTab) {
          items.sort((a, b) => _daysUntilNextBirthday(a.date).compareTo(_daysUntilNextBirthday(b.date)));
        } else {
          items.sort((a, b) => a.date.compareTo(b.date));
        }

        if (items.isEmpty) return const SliverFillRemaining(child: Center(child: Text('Carian tidak dijumpai.')));

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: 140, // Tetapkan tinggi kad
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final b = items[index];
                final daysLeft = isBirthdayTab ? _daysUntilNextBirthday(b.date) : b.date.difference(DateTime.now()).inDays;
                
                bool isToday = isBirthdayTab && daysLeft == 0;
                bool isThisWeek = isBirthdayTab && daysLeft > 0 && daysLeft <= 7;

                int age = DateTime.now().year - b.date.year;
                if (DateTime.now().month < b.date.month || (DateTime.now().month == b.date.month && DateTime.now().day < b.date.day)) age--;

                return _buildBirthdayCard(b, isToday, isThisWeek, isBirthdayTab, age, daysLeft);
              },
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBirthdayCard(Birthday b, bool isToday, bool isThisWeek, bool isBirthdayTab, int age, int daysLeft) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isToday ? const Color(0xFFFFEBF2) : (isThisWeek ? const Color(0xFFFFF7E6) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: isToday ? Border.all(color: Colors.pinkAccent, width: 2.5) : (isThisWeek ? Border.all(color: Colors.orangeAccent, width: 1.5) : null),
          boxShadow: [
            BoxShadow(
              color: isToday ? Colors.pink.withOpacity(0.2) : Colors.black.withOpacity(0.04), 
              blurRadius: 15, 
              offset: const Offset(0, 6)
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              if (isToday) Positioned(right: -10, top: -10, child: Icon(Icons.stars, size: 60, color: Colors.pinkAccent.withOpacity(0.1))),
              Column(
                children: [
                  if (isToday) Container(
                    width: double.infinity, 
                    padding: const EdgeInsets.symmetric(vertical: 6), 
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.pinkAccent, Color(0xFFFF4081)])),
                    child: Text("🎂 HARI INI - SANNAH HELWAH!", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                  ),
                  if (isThisWeek && !isToday) Container(
                    width: double.infinity, 
                    padding: const EdgeInsets.symmetric(vertical: 6), 
                    color: Colors.orangeAccent, 
                    child: Text("🌟 MINGGU INI", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2))
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: isToday ? Colors.pinkAccent : (isThisWeek ? Colors.orange[200] : Colors.grey[200]),
                            child: Text(b.name.isNotEmpty ? b.name[0].toUpperCase() : "?", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 24, color: isToday ? Colors.white : (isThisWeek ? Colors.orange[900] : Colors.grey[800]))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.name, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: isToday ? const Color(0xFF880E4F) : Colors.black87), overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.event, size: 14, color: isToday ? Colors.pinkAccent : Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Text(isBirthdayTab ? DateFormat('dd MMM').format(b.date) : DateFormat('dd MMM yyyy').format(b.date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                                if (isBirthdayTab) Text("Umur $age • $daysLeft Hari Lagi", style: TextStyle(color: isToday ? Colors.pinkAccent : (isThisWeek ? Colors.orange[900] : Colors.grey[600]), fontSize: 12, fontWeight: (isToday || isThisWeek) ? FontWeight.bold : FontWeight.normal)),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _actionButton(
                                icon: Icons.copy_rounded, 
                                color: Colors.blue, 
                                bgColor: Colors.blue[50]!, 
                                onTap: () { copyGreetingStatic(b); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ucapan disalin!"), behavior: SnackBarBehavior.floating)); }
                              ),
                              const SizedBox(height: 8),
                              _actionButton(
                                icon: Icons.delete_outline_rounded, 
                                color: Colors.red, 
                                bgColor: Colors.red[50]!, 
                                onTap: () => _confirmDelete(b)
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({required IconData icon, required Color color, required Color bgColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class BirthdayApp extends StatelessWidget {
  const BirthdayApp({super.key});
  @override
  Widget build(BuildContext context) { 
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent, primary: Colors.pinkAccent), 
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ), 
      home: const BirthdayListScreen()
    ); 
  }
}
