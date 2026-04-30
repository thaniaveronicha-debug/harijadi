import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  runApp(const BirthdayApp());
}

class BirthdayApp extends StatelessWidget {
  const BirthdayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peringatan Harijadi AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: const BirthdayListScreen(),
    );
  }
}

class Birthday {
  final String name;
  final DateTime date;
  final String phoneNumber;

  Birthday({required this.name, required this.date, required this.phoneNumber});

  Map<String, dynamic> toJson() => {
        'name': name,
        'date': date.toIso8601String(),
        'phoneNumber': phoneNumber,
      };

  factory Birthday.fromJson(Map<String, dynamic> json) => Birthday(
        name: json['name'],
        date: DateTime.parse(json['date']),
        phoneNumber: json['phoneNumber'] ?? "",
      );
}

class BirthdayListScreen extends StatefulWidget {
  const BirthdayListScreen({super.key});

  @override
  State<BirthdayListScreen> createState() => _BirthdayListScreenState();
}

class _BirthdayListScreenState extends State<BirthdayListScreen> {
  List<Birthday> _birthdays = [];
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _activeField = "";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadBirthdays();
  }

  Future<void> _loadBirthdays() async {
    final prefs = await SharedPreferences.getInstance();
    final String? birthdaysJson = prefs.getString('birthdays');
    if (birthdaysJson != null) {
      final List<dynamic> decodedList = jsonDecode(birthdaysJson);
      setState(() {
        _birthdays = decodedList.map((item) => Birthday.fromJson(item)).toList();
        _sortBirthdays();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTodayBirthdays());
  }

  Future<void> _saveBirthdays() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('birthdays', jsonEncode(_birthdays.map((b) => b.toJson()).toList()));
  }

  void _sortBirthdays() {
    _birthdays.sort((a, b) => _daysUntilNextBirthday(a.date).compareTo(_daysUntilNextBirthday(b.date)));
  }

  void _addBirthday(String name, DateTime date, String phone) {
    setState(() {
      _birthdays.add(Birthday(name: name, date: date, phoneNumber: phone));
      _sortBirthdays();
    });
    _saveBirthdays();
  }

  int _daysUntilNextBirthday(DateTime birthday) {
    DateTime now = DateTime.now();
    DateTime next = DateTime(now.year, birthday.month, birthday.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, birthday.month, birthday.day);
    }
    return next.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  void _checkTodayBirthdays() {
    DateTime now = DateTime.now();
    for (var bday in _birthdays) {
      if (bday.date.day == now.day && bday.date.month == now.month) {
        _showReminderDialog(bday);
      }
    }
  }

  void _showReminderDialog(Birthday bday) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎂 Harijadi Hari Ini!'),
        content: Text('Selamat Harijadi kepada ${bday.name}!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        ],
      ),
    );
  }

  // FUNGSI AI: IMBAS GAMBAR
  Future<void> _scanImage(Function(String, DateTime) onDataExtracted) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    
    String extractedName = "";
    DateTime extractedDate = DateTime.now();

    // Logik ringkas AI untuk mencari tarikh & nama dalam teks
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String text = line.text;
        // Cari tarikh (Format: DD/MM/YYYY atau DD-MM-YYYY)
        RegExp dateReg = RegExp(r'(\d{1,2})[\/\- ](\d{1,2})[\/\- ](\d{2,4})');
        if (dateReg.hasMatch(text)) {
          var match = dateReg.firstMatch(text);
          int day = int.parse(match!.group(1)!);
          int month = int.parse(match.group(2)!);
          int year = int.parse(match.group(3)!);
          if (year < 100) year += 2000;
          try { extractedDate = DateTime(year, month, day); } catch (e) {}
        } else if (extractedName.isEmpty && text.length > 3) {
          extractedName = text; // Anggap baris teks pertama yang panjang sebagai nama
        }
      }
    }
    textRecognizer.close();
    onDataExtracted(extractedName, extractedDate);
  }

  void _showAddBirthdaySheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            void toggleListen(String field) async {
              bool available = await _speech.initialize();
              if (available) {
                setModalState(() { _isListening = true; _activeField = field; });
                _speech.listen(onResult: (val) => setModalState(() {
                  if (field == "name") nameController.text = val.recognizedWords;
                  if (field == "phone") phoneController.text = val.recognizedWords.replaceAll(RegExp(r'[^0-9]'), '');
                }));
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 10),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.drag_handle, color: Colors.grey),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tambah Rekod AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.document_scanner, color: Colors.blue),
                          onPressed: () => _scanImage((name, date) {
                            setModalState(() {
                              nameController.text = name;
                              selectedDate = date;
                            });
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: nameController, 
                      decoration: InputDecoration(
                        labelText: 'Nama', 
                        suffixIcon: IconButton(icon: Icon(_isListening && _activeField=="name" ? Icons.mic : Icons.mic_none), onPressed: () => toggleListen("name"))
                      )
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController, 
                      decoration: InputDecoration(
                        labelText: 'WhatsApp', 
                        suffixIcon: IconButton(icon: Icon(_isListening && _activeField=="phone" ? Icons.mic : Icons.mic_none), onPressed: () => toggleListen("phone"))
                      )
                    ),
                    const SizedBox(height: 15),
                    ListTile(
                      title: Text("Tarikh: ${DateFormat('dd MMMM yyyy').format(selectedDate)}"),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(1900), lastDate: DateTime.now());
                        if (p != null) setModalState(() => selectedDate = p);
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      onPressed: () {
                        if (nameController.text.isNotEmpty) {
                          _addBirthday(nameController.text, selectedDate, phoneController.text);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Simpan Rekod'),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎂 Peringatan AI'),
        backgroundColor: Colors.pink[50],
        centerTitle: true,
      ),
      body: _birthdays.isEmpty
          ? const Center(child: Text('Kosong. Guna AI untuk imbas gambar!'))
          : ListView.builder(
              itemCount: _birthdays.length,
              itemBuilder: (context, index) {
                final b = _birthdays[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(b.name[0])),
                    title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${DateFormat('dd MMM').format(b.date)} • ${_daysUntilNextBirthday(b.date)} hari lagi"),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _birthdays.removeAt(index))),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddBirthdaySheet, child: const Icon(Icons.add)),
    );
  }

  int _calculateAge(DateTime bday) {
    DateTime now = DateTime.now();
    int age = now.year - bday.year;
    if (now.month < bday.month || (now.month == bday.month && now.day < bday.day)) age--;
    return age;
  }
}
