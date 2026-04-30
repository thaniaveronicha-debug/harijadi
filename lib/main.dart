import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const BirthdayApp());
}

class BirthdayApp extends StatelessWidget {
  const BirthdayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peringatan Harijadi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
        brightness: Brightness.light,
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
  String _activeField = ""; // "name", "phone", "date"

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTodayBirthdays();
    });
  }

  Future<void> _saveBirthdays() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = jsonEncode(_birthdays.map((b) => b.toJson()).toList());
    await prefs.setString('birthdays', encodedList);
  }

  void _sortBirthdays() {
    _birthdays.sort((a, b) {
      int aNext = _daysUntilNextBirthday(a.date);
      int bNext = _daysUntilNextBirthday(b.date);
      return aNext.compareTo(bNext);
    });
  }

  void _addBirthday(String name, DateTime date, String phone) {
    setState(() {
      _birthdays.add(Birthday(name: name, date: date, phoneNumber: phone));
      _sortBirthdays();
    });
    _saveBirthdays();
    _checkTodayBirthdays();
  }

  void _deleteBirthday(int index) {
    setState(() {
      _birthdays.removeAt(index);
    });
    _saveBirthdays();
  }

  void _checkTodayBirthdays() {
    DateTime now = DateTime.now();
    List<Birthday> todayBirthdays = _birthdays.where((b) {
      return b.date.day == now.day && b.date.month == now.month;
    }).toList();

    if (todayBirthdays.isNotEmpty) {
      for (var bday in todayBirthdays) {
        _showReminderDialog(bday);
      }
    }
  }

  Future<void> _sendWhatsApp(Birthday bday) async {
    if (bday.phoneNumber.isEmpty) return;
    String phone = bday.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (!phone.startsWith('6')) phone = '6$phone';
    final message = "Selamat Hari Jadi, ${bday.name}! 🎉";
    final url = Uri.parse("https://wa.me/$phone/?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showReminderDialog(Birthday bday) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎂 Peringatan Harijadi!'),
        content: Text('Hari ini adalah harijadi ${bday.name}!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          if (bday.phoneNumber.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); _sendWhatsApp(bday); },
              icon: const Icon(Icons.message),
              label: const Text('WhatsApp'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
        ],
      ),
    );
  }

  int _daysUntilNextBirthday(DateTime birthday) {
    DateTime now = DateTime.now();
    DateTime next = DateTime(now.year, birthday.month, birthday.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, birthday.month, birthday.day);
    }
    return next.difference(DateTime(now.year, now.month, now.day)).inDays;
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
            
            void onSpeechResult(String words) {
              setModalState(() {
                if (_activeField == "name") {
                  nameController.text = words;
                } else if (_activeField == "phone") {
                  phoneController.text = words.replaceAll(RegExp(r'[^0-9]'), '');
                } else if (_activeField == "date") {
                  // Logik ringkas mengecam bulan melalui suara
                  final lowerWords = words.toLowerCase();
                  int month = selectedDate.month;
                  if (lowerWords.contains("januari")) month = 1;
                  else if (lowerWords.contains("februari")) month = 2;
                  else if (lowerWords.contains("mac")) month = 3;
                  else if (lowerWords.contains("april")) month = 4;
                  else if (lowerWords.contains("mei")) month = 5;
                  else if (lowerWords.contains("jun")) month = 6;
                  else if (lowerWords.contains("julai")) month = 7;
                  else if (lowerWords.contains("ogos")) month = 8;
                  else if (lowerWords.contains("september")) month = 9;
                  else if (lowerWords.contains("oktober")) month = 10;
                  else if (lowerWords.contains("november")) month = 11;
                  else if (lowerWords.contains("disember")) month = 12;

                  // Cuba cari nombor (hari & tahun)
                  final RegExp numReg = RegExp(r'\d+');
                  final matches = numReg.allMatches(words).toList();
                  int day = selectedDate.day;
                  int year = selectedDate.year;

                  if (matches.isNotEmpty) day = int.parse(matches[0].group(0)!);
                  if (matches.length > 1) year = int.parse(matches[matches.length - 1].group(0)!);

                  try {
                    selectedDate = DateTime(year > 100 ? year : 2000 + year, month, day);
                  } catch (e) { /* ignore parse errors */ }
                }
              });
            }

            void toggleListen(String field) async {
              if (_isListening && _activeField == field) {
                setModalState(() => _isListening = false);
                _speech.stop();
              } else {
                bool available = await _speech.initialize();
                if (available) {
                  setModalState(() {
                    _isListening = true;
                    _activeField = field;
                  });
                  _speech.listen(onResult: (val) => onSpeechResult(val.recognizedWords));
                }
              }
            }

            Widget micButton(String field) {
              bool active = _isListening && _activeField == field;
              return GestureDetector(
                onTap: () => toggleListen(field),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: active ? Colors.red : Colors.pinkAccent,
                  child: Icon(active ? Icons.mic : Icons.mic_none, color: Colors.white, size: 20),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Tambah Rekod Baru', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    // INPUT NAMA
                    Row(
                      children: [
                        Expanded(child: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama', prefixIcon: Icon(Icons.person)))),
                        const SizedBox(width: 8),
                        micButton("name"),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // INPUT TELEFON
                    Row(
                      children: [
                        Expanded(child: TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nombor Telefon', prefixIcon: Icon(Icons.phone)))),
                        const SizedBox(width: 8),
                        micButton("phone"),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // INPUT TARIKH
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(1900), lastDate: DateTime.now());
                              if (p != null) setModalState(() => selectedDate = p);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Tarikh Harijadi', prefixIcon: Icon(Icons.calendar_today)),
                              child: Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        micButton("date"),
                      ],
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
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
        title: const Text('🎂 Peringatan Harijadi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        centerTitle: true,
      ),
      body: _birthdays.isEmpty
          ? const Center(child: Text('Tiada rekod. Tekan + untuk tambah!'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _birthdays.length,
              itemBuilder: (context, index) {
                final b = _birthdays[index];
                final isToday = _daysUntilNextBirthday(b.date) == 0;
                return Card(
                  color: isToday ? Colors.pink[50] : null,
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: isToday ? Colors.pinkAccent : Colors.pink[100], child: Icon(isToday ? Icons.cake : Icons.favorite, color: Colors.white)),
                    title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${DateFormat('dd MMMM').format(b.date)} • ${_calculateAge(b.date)} tahun"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (b.phoneNumber.isNotEmpty) IconButton(icon: const Icon(Icons.message, color: Colors.green), onPressed: () => _sendWhatsApp(b)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteBirthday(index)),
                      ],
                    ),
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
