import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedicalApp());
}

String dateText(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String normalizeDoctor(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

class MedicalVisit {
  final int? id;
  final String doctor;
  final String hospital;
  final String diagnosis;
  final String medicine;
  final String phone;
  final String symptoms;
  final String tests;
  final String dosage;
  final String location;
  final String doctorPhoto;
  final String hospitalPhoto;
  final String prescription;
  final String report;
  final DateTime date;

  const MedicalVisit({
    this.id,
    required this.doctor,
    required this.hospital,
    required this.diagnosis,
    required this.medicine,
    this.phone = '',
    this.symptoms = '',
    this.tests = '',
    this.dosage = '',
    this.location = '',
    this.doctorPhoto = '',
    this.hospitalPhoto = '',
    this.prescription = '',
    this.report = '',
    required this.date,
  });

  Map<String, Object?> toMap() => {
        'doctor': doctor,
        'hospital': hospital,
        'diagnosis': diagnosis,
        'medicine': medicine,
        'phone': phone,
        'symptoms': symptoms,
        'tests': tests,
        'dosage': dosage,
        'location': location,
        'doctor_photo': doctorPhoto,
        'hospital_photo': hospitalPhoto,
        'prescription': prescription,
        'report': report,
        'date': date.toIso8601String(),
      };

  factory MedicalVisit.fromMap(Map<String, Object?> map) => MedicalVisit(
        id: map['id'] as int,
        doctor: map['doctor'] as String,
        hospital: map['hospital'] as String,
        diagnosis: map['diagnosis'] as String,
        medicine: map['medicine'] as String,
        phone: map['phone'] as String? ?? '',
        symptoms: map['symptoms'] as String? ?? '',
        tests: map['tests'] as String? ?? '',
        dosage: map['dosage'] as String? ?? '',
        location: map['location'] as String? ?? '',
        doctorPhoto: map['doctor_photo'] as String? ?? '',
        hospitalPhoto: map['hospital_photo'] as String? ?? '',
        prescription: map['prescription'] as String? ?? '',
        report: map['report'] as String? ?? '',
        date: DateTime.parse(map['date'] as String),
      );
}

class MedicalDatabase {
  MedicalDatabase._();
  static final MedicalDatabase instance = MedicalDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final directory = await getDatabasesPath();
    _db = await openDatabase(
      p.join(directory, 'medical_history.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE visits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            doctor TEXT NOT NULL,
            hospital TEXT NOT NULL,
            diagnosis TEXT NOT NULL,
            medicine TEXT NOT NULL,
            phone TEXT DEFAULT '',
            symptoms TEXT DEFAULT '',
            tests TEXT DEFAULT '',
            dosage TEXT DEFAULT '',
            location TEXT DEFAULT '',
            doctor_photo TEXT DEFAULT '',
            hospital_photo TEXT DEFAULT '',
            prescription TEXT DEFAULT '',
            report TEXT DEFAULT '',
            date TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final field in ['phone','symptoms','tests','dosage',
            'location','doctor_photo','hospital_photo','prescription','report']) {
            await db.execute("ALTER TABLE visits ADD COLUMN $field TEXT DEFAULT ''");
          }
        }
      },
    );
    return _db!;
  }

  Future<List<MedicalVisit>> getVisits() async {
    final db = await database;
    final rows = await db.query('visits', orderBy: 'date DESC, id DESC');
    return rows.map(MedicalVisit.fromMap).toList();
  }

  Future<void> saveVisit(MedicalVisit visit) async {
    final db = await database;
    if (visit.id == null) {
      await db.insert('visits', visit.toMap());
    } else {
      await db.update(
        'visits',
        visit.toMap(),
        where: 'id = ?',
        whereArgs: [visit.id],
      );
    }
  }

  Future<void> exportBackup() async {
    final visits = await getVisits();
    final records = visits.map((v) => {...v.toMap(), 'id': v.id}).toList();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'medical_history_backup.json'));
    await file.writeAsString(jsonEncode({'version': 2, 'visits': records}));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'Medical History backup — save this file to Google Drive.',
    ));
  }

  Future<int> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return 0;
    final raw = await File(result.files.single.path!).readAsString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final rows = (data['visits'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final db = await database;
    await db.transaction((txn) async {
      for (final row in rows) {
        final restored = Map<String, Object?>.from(row);
        final visit = MedicalVisit.fromMap(restored);
        await txn.insert('visits', {
          ...visit.toMap(),
          'id': visit.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return rows.length;
  }

  Future<void> deleteVisit(int id) async {
    final db = await database;
    await db.delete('visits', where: 'id = ?', whereArgs: [id]);
  }
}

class MedicalApp extends StatelessWidget {
  const MedicalApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'My Medical History',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
          scaffoldBackgroundColor: const Color(0xFFF5F8FC),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: const HomeScreen(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MedicalVisit> visits = [];
  bool loading = true;
  String? error;
  int selectedTab = 0;
  String search = '';
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final data = await MedicalDatabase.instance.getVisits();
      if (!mounted) return;
      setState(() {
        visits = data;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  void notify(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> addOrEdit({MedicalVisit? existing, String? doctor, String? hospital}) async {
    final result = await Navigator.push<MedicalVisit>(
      context,
      MaterialPageRoute(
        builder: (_) => VisitFormScreen(
          existing: existing,
          initialDoctor: doctor,
          initialHospital: hospital,
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await MedicalDatabase.instance.saveVisit(result);
      await refresh();
      notify(existing == null ? 'Visit saved on this phone' : 'Visit updated');
    } catch (e) {
      notify('Could not save visit: $e');
    }
  }

  Future<void> openVisit(MedicalVisit visit) async {
    final action = await Navigator.push<VisitAction>(
      context,
      MaterialPageRoute(builder: (_) => VisitDetailScreen(visit: visit)),
    );
    if (!mounted) return;
    if (action == VisitAction.edit) {
      await addOrEdit(existing: visit);
    } else if (action == VisitAction.delete) {
      try {
        await MedicalDatabase.instance.deleteVisit(visit.id!);
        await refresh();
        notify('Visit deleted');
      } catch (e) {
        notify('Could not delete visit: $e');
      }
    }
  }

  List<MedicalVisit> visitsByDoctor(String key) =>
      visits.where((v) => normalizeDoctor(v.doctor) == key).toList();

  Future<void> openDoctor(String key) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorScreen(
          doctorKey: key,
          getVisits: () => visitsByDoctor(key),
          onOpenVisit: openVisit,
          onAddVisit: (doctor, hospital) =>
              addOrEdit(doctor: doctor, hospital: hospital),
        ),
      ),
    );
    if (mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final doctorKeys = visits.map((v) => normalizeDoctor(v.doctor)).toSet().toList()..sort();
    final query = search.trim().toLowerCase();
    bool matches(MedicalVisit v) => [
      v.doctor, v.phone, v.hospital, v.diagnosis,
      v.medicine, v.tests, v.symptoms, v.location,
    ].join(' ').toLowerCase().contains(query);
    final filteredVisits = visits.where(matches).toList();
    final filteredDoctors = doctorKeys.where((key) =>
      visitsByDoctor(key).any(matches)).toList();
    const names = ['Recent Visits', 'My Doctors', 'Medical History'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medical History'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Backup options',
            onSelected: (action) async {
              try {
                if (action == 'export') {
                  await MedicalDatabase.instance.exportBackup();
                } else {
                  final count = await MedicalDatabase.instance.importBackup();
                  await refresh();
                  notify('$count visits imported');
                }
              } catch (e) { notify('Backup error: $e'); }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Share backup to Google Drive')),
              PopupMenuItem(value: 'import', child: Text('Restore JSON backup')),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Database error: $error', textAlign: TextAlign.center),
                      TextButton(onPressed: refresh, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (selectedTab == 0)
                      Card(
                        margin: const EdgeInsets.all(16),
                        color: const Color(0xFF1976D2),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Icon(Icons.health_and_safety, color: Colors.white, size: 40),
                              const SizedBox(height: 8),
                              const Text('Your Health Records',
                                  style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                              Text('${visits.length} visits • ${doctorKeys.length} doctors',
                                  style: const TextStyle(color: Colors.white)),
                              const Text('Saved offline on your phone',
                                  style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        onChanged: (text) => setState(() => search = text),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search by doctor name',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(names[selectedTab],
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: selectedTab == 1
                          ? filteredDoctors.isEmpty
                              ? const Center(child: Text('No doctors found. Add a visit first.'))
                              : ListView.builder(
                                  itemCount: filteredDoctors.length,
                                  itemBuilder: (context, i) {
                                    final key = filteredDoctors[i];
                                    final history = visitsByDoctor(key);
                                    return Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                      child: ListTile(
                                        leading: const CircleAvatar(child: Icon(Icons.person)),
                                        title: Text(history.first.doctor),
                                        subtitle: Text('${history.first.hospital} • ${history.length} visits'),
                                        trailing: const Icon(Icons.chevron_right),
                                        onTap: () => openDoctor(key),
                                      ),
                                    );
                                  },
                                )
                          : filteredVisits.isEmpty
                              ? const Center(child: Text('No visits found. Tap Add Visit.'))
                              : ListView.builder(
                                  itemCount: filteredVisits.length,
                                  itemBuilder: (context, i) {
                                    final visit = filteredVisits[i];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                      child: ListTile(
                                        leading: const CircleAvatar(child: Icon(Icons.medical_services)),
                                        title: Text(visit.doctor),
                                        subtitle: Text('${visit.hospital}\n${visit.diagnosis} • ${dateText(visit.date)}'),
                                        isThreeLine: true,
                                        trailing: const Icon(Icons.chevron_right),
                                        onTap: () => openVisit(visit),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
      floatingActionButton: loading || error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('Add Visit'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
            search = '';
            searchController.clear();
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Doctors'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

class DoctorScreen extends StatefulWidget {
  final String doctorKey;
  final List<MedicalVisit> Function() getVisits;
  final Future<void> Function(MedicalVisit) onOpenVisit;
  final Future<void> Function(String, String) onAddVisit;

  const DoctorScreen({
    super.key,
    required this.doctorKey,
    required this.getVisits,
    required this.onOpenVisit,
    required this.onAddVisit,
  });

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  @override
  Widget build(BuildContext context) {
    final history = widget.getVisits();
    if (history.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Doctor Profile')),
        body: const Center(child: Text('No visits under this doctor.')),
      );
    }
    final doctor = history.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(radius: 34, child: Icon(Icons.person, size: 38)),
                  const SizedBox(height: 12),
                  Text(doctor.doctor,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(doctor.hospital),
                  Chip(label: Text('${history.length} Total Visits')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Visit for This Doctor'),
            onPressed: () async {
              await widget.onAddVisit(doctor.doctor, doctor.hospital);
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 18),
          const Text('Visit History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ...history.map((visit) => Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: Text(dateText(visit.date)),
                  subtitle: Text('${visit.diagnosis}\n${visit.medicine}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await widget.onOpenVisit(visit);
                    if (mounted) setState(() {});
                  },
                ),
              )),
        ],
      ),
    );
  }
}

class VisitFormScreen extends StatefulWidget {
  final MedicalVisit? existing;
  final String? initialDoctor;
  final String? initialHospital;

  const VisitFormScreen({super.key, this.existing, this.initialDoctor, this.initialHospital});

  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  final formKey = GlobalKey<FormState>();
  final doctor = TextEditingController();
  final hospital = TextEditingController();
  final diagnosis = TextEditingController();
  final medicine = TextEditingController();
  final phone = TextEditingController();
  final symptoms = TextEditingController();
  final tests = TextEditingController();
  final dosage = TextEditingController();
  final location = TextEditingController();
  String doctorPhoto = '';
  String hospitalPhoto = '';
  String prescription = '';
  String report = '';

  Future<void> chooseFile(String kind) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom,
      allowedExtensions: ['jpg','jpeg','png','pdf']);
    if (result == null || result.files.single.path == null) return;
    final picked = result.files.single;
    final directory = await getApplicationDocumentsDirectory();
    final extension = p.extension(picked.name).toLowerCase();
    final name = '${DateTime.now().microsecondsSinceEpoch}_$kind$extension';
    final saved = await File(picked.path!).copy(p.join(directory.path, name));
    if (!mounted) return;
    setState(() {
      switch (kind) {
        case 'doctor': doctorPhoto = saved.path; break;
        case 'hospital': hospitalPhoto = saved.path; break;
        case 'prescription': prescription = saved.path; break;
        case 'report': report = saved.path; break;
      }
    });
  }

  Widget fileButton(String title, String kind, String value) =>
    Padding(padding: const EdgeInsets.only(bottom: 9),
      child: OutlinedButton.icon(
        onPressed: () => chooseFile(kind),
        icon: const Icon(Icons.attach_file),
        label: Text(value.isEmpty ? 'Attach $title' : '$title selected ✓'),
      ));
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    doctor.text = widget.existing?.doctor ?? widget.initialDoctor ?? '';
    hospital.text = widget.existing?.hospital ?? widget.initialHospital ?? '';
    diagnosis.text = widget.existing?.diagnosis ?? '';
    medicine.text = widget.existing?.medicine ?? '';
    phone.text = widget.existing?.phone ?? '';
    symptoms.text = widget.existing?.symptoms ?? '';
    tests.text = widget.existing?.tests ?? '';
    dosage.text = widget.existing?.dosage ?? '';
    location.text = widget.existing?.location ?? '';
    doctorPhoto = widget.existing?.doctorPhoto ?? '';
    hospitalPhoto = widget.existing?.hospitalPhoto ?? '';
    prescription = widget.existing?.prescription ?? '';
    report = widget.existing?.report ?? '';
    selectedDate = widget.existing?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    doctor.dispose();
    hospital.dispose();
    diagnosis.dispose();
    medicine.dispose();
    phone.dispose();
    symptoms.dispose();
    tests.dispose();
    dosage.dispose();
    location.dispose();
    super.dispose();
  }

  Widget field(String title, TextEditingController controller, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: title, prefixIcon: Icon(icon)),
          validator: (text) =>
            title.contains('(optional)') || title.contains('Address') ||
            title.startsWith('Dosage') || title.startsWith('Medical Tests')
            ? null : (text == null || text.trim().isEmpty ? 'Please enter $title' : null),
        ),
      );

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      MedicalVisit(
        id: widget.existing?.id,
        doctor: doctor.text.trim(),
        hospital: hospital.text.trim(),
        diagnosis: diagnosis.text.trim(),
        medicine: medicine.text.trim(),
        phone: phone.text.trim(),
        symptoms: symptoms.text.trim(),
        tests: tests.text.trim(),
        dosage: dosage.text.trim(),
        location: location.text.trim(),
        doctorPhoto: doctorPhoto,
        hospitalPhoto: hospitalPhoto,
        prescription: prescription,
        report: report,
        date: selectedDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.existing == null ? 'Add Visit' : 'Edit Visit')),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.medical_services, size: 54, color: Color(0xFF1976D2)),
              const SizedBox(height: 20),
              field('Doctor Name', doctor, Icons.person),
              field('Doctor Phone (optional)', phone, Icons.phone),
              fileButton('Doctor Photo', 'doctor', doctorPhoto),
              field('Hospital Name', hospital, Icons.local_hospital),
              field('Hospital Address / Maps Search', location, Icons.place),
              fileButton('Hospital Photo', 'hospital', hospitalPhoto),
              field('Symptoms (optional)', symptoms, Icons.notes),
              field('Diagnosis', diagnosis, Icons.health_and_safety),
              field('Medicine(s), comma-separated', medicine, Icons.medication),
              field('Dosage / Duration (optional)', dosage, Icons.schedule),
              field('Medical Tests / Results (optional)', tests, Icons.science),
              fileButton('Prescription Image/PDF', 'prescription', prescription),
              fileButton('Medical Report Image/PDF', 'report', report),
              Card(
                child: ListTile(
                  title: const Text('Visit Date'),
                  subtitle: Text(dateText(selectedDate)),
                  leading: const Icon(Icons.calendar_today),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) setState(() => selectedDate = date);
                  },
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: save,
                icon: const Icon(Icons.save),
                label: Text(widget.existing == null ? 'Save Visit' : 'Save Changes'),
              ),
            ],
          ),
        ),
      );
}

enum VisitAction { edit, delete }

class VisitDetailScreen extends StatelessWidget {
  final MedicalVisit visit;
  const VisitDetailScreen({super.key, required this.visit});

  Future<void> confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete Medical Visit?'),
        content: const Text('This visit will be permanently removed from this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.pop(context, VisitAction.delete);
    }
  }

  Widget info(String title, String value, IconData icon) => Card(
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF1976D2)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(value),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Visit Details'),
          actions: [
            IconButton(
              tooltip: 'Delete Visit',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => confirmDelete(context),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const CircleAvatar(radius: 34, child: Icon(Icons.person, size: 38)),
            const SizedBox(height: 20),
            info('Doctor', visit.doctor, Icons.person),
            info('Hospital', visit.hospital, Icons.local_hospital),
            info('Diagnosis', visit.diagnosis, Icons.health_and_safety),
            info('Medicine(s)', visit.medicine, Icons.medication),
            if (visit.phone.isNotEmpty) info('Doctor Phone', visit.phone, Icons.phone),
            if (visit.symptoms.isNotEmpty) info('Symptoms', visit.symptoms, Icons.notes),
            if (visit.dosage.isNotEmpty) info('Dosage / Duration', visit.dosage, Icons.schedule),
            if (visit.tests.isNotEmpty) info('Tests / Results', visit.tests, Icons.science),
            if (visit.location.isNotEmpty) Card(child: ListTile(
              leading: const Icon(Icons.map),
              title: Text(visit.location),
              subtitle: const Text('Open location search in Google Maps'),
              onTap: () async {
                final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(visit.location)}');
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
            )),
            ...[
              ('Doctor Photo', visit.doctorPhoto),
              ('Hospital Photo', visit.hospitalPhoto),
              ('Prescription', visit.prescription),
              ('Report', visit.report),
            ].where((entry) => entry.$2.isNotEmpty).map((entry) => Card(child: ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(entry.$1),
              subtitle: Text(p.basename(entry.$2)),
              trailing: const Icon(Icons.description),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved on phone: ${entry.$2}'))),
            ))),
            info('Visit Date', dateText(visit.date), Icons.calendar_today),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, VisitAction.edit),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Medical Visit'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => confirmDelete(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Medical Visit'),
            ),
          ],
        ),
      );
}
