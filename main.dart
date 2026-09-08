import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(const StretchApp());
}

class StretchApp extends StatelessWidget {
  const StretchApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Студия Растяжки',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> _clients = [];
  final _fioController = TextEditingController();
  final _timeController = TextEditingController();
  final _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _onDateChanged(String value) {
    String text = value.replaceAll('.', '');
    String newText = "";
    if (text.length >= 1) newText += text.substring(0, text.length >= 2 ? 2 : text.length);
    if (text.length >= 3) newText += "." + text.substring(2, text.length >= 4 ? 4 : text.length);
    if (text.length >= 5) newText += "." + text.substring(4, text.length >= 6 ? 6 : text.length);

    _dateController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.fromPosition(TextPosition(offset: newText.length)),
    );
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('clients_db');
    if (saved != null) {
      setState(() {
        _clients.addAll(List<Map<String, dynamic>>.from(json.decode(saved)));
      });
    }
    _checkExpired();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clients_db', json.encode(_clients));
  }

  void _checkExpired() {
    final today = DateTime.now();
    List<String> expiredNames = [];
    
    for (var client in _clients) {
      try {
        final end = DateFormat('dd.MM.yy').parse(client['end_date']);
        if (end.isBefore(today) && end.day != today.day) {
          expiredNames.add(client['fio']);
        }
      } catch (_) {}
    }

    if (expiredNames.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Срок истёк!'),
            content: Text('Закончились абонементы у:\n\n' + expiredNames.join('\n')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОК')),
            ],
          ),
        );
      });
    }
  }

  void _addClient() {
    final fio = _fioController.text.trim();
    final time = _timeController.text.trim().isEmpty ? 'Не указано' : _timeController.text.trim();
    final dateStr = _dateController.text.trim();

    if (fio.isEmpty || dateStr.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните ФИО и Дату (6 цифр)!')),
      );
      return;
    }

    setState(() {
      _clients.add({
        'fio': fio,
        'time': time,
        'end_date': dateStr,
      });
      _saveData();
    });

    _fioController.clear();
    _timeController.clear();
    _dateController.clear();
  }

  void _deleteClient(Map<String, dynamic> client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Удалить клиента ${client['fio']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              setState(() {
                _clients.remove(client);
                _saveData();
              });
              Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final activeClients = <Map<String, dynamic>>[];
    final expiredClients = <Map<String, dynamic>>[];

    for (var client in _clients) {
      try {
        final end = DateFormat('dd.MM.yy').parse(client['end_date']);
        if (end.isBefore(today) && end.day != today.day) {
          expiredClients.add(client);
        } else {
          activeClients.add(client);
        }
      } catch (_) {
        activeClients.add(client);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Учёт абонементов растяжки')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TextField(controller: _fioController, decoration: const InputDecoration(labelText: 'ФИО')),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _timeController, decoration: const InputDecoration(labelText: 'Время'))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _dateController, 
                            decoration: const InputDecoration(labelText: 'Дата конца (ДДММГГ)', hintText: '080926'),
                            keyboardType: TextInputType.number,
                            onChanged: _onDateChanged,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: _addClient, child: const Text('Добавить абонемент')),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const ContainerLabel(text: '🟢 АКТИВНЫЕ', color: Colors.green),
                      Expanded(child: _buildList(activeClients, Colors.green[100]!)),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      const ContainerLabel(text: '🔴 ИСТЁКШИЕ', color: Colors.red),
                      Expanded(child: _buildList(expiredClients, Colors.red[100]!)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, Color bgColor) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final client = list[index];
        return Card(
          color: bgColor,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: ListTile(
            title: Text(client['fio'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Время: ${client['time']}\nДо: ${client['end_date']}', style: const TextStyle(fontSize: 11)),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
              onPressed: () => _deleteClient(client),
            ),
          ),
        );
      },
    );
  }
}

class ContainerLabel extends StatelessWidget {
  final String text;
  final Color color;
  const ContainerLabel({Key? key, required this.text, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      color: color,
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
