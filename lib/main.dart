import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final temaModo = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await Avisos.iniciar();
  final p = await SharedPreferences.getInstance();
  temaModo.value = switch (p.getString('agenda.tema')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  runApp(const AgendaApp());
}

class AgendaApp extends StatelessWidget {
  const AgendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData tema(Brightness b) => ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2B3FD6), brightness: b),
        );
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: temaModo,
      builder: (_, modo, __) => MaterialApp(
        title: 'Agenda diaria',
        debugShowCheckedModeBanner: false,
        theme: tema(Brightness.light),
        darkTheme: tema(Brightness.dark),
        themeMode: modo,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Inicio(),
      ),
    );
  }
}

// ---------------------------------------------------------------- Utilidades

String claveDia(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String mayus(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String fechaLarga(DateTime d) =>
    mayus(DateFormat("EEEE d 'de' MMMM", 'es').format(d));
int lim(int v, int a, int b) => v < a ? a : (v > b ? b : v);
String nuevoId() => DateTime.now().microsecondsSinceEpoch.toString();

const repTxt = {'d': 'cada día', 'w': 'cada semana', 'm': 'cada mes'};

Color colorMat(String s) {
  var h = 0;
  for (final c in s.runes) {
    h = (h * 31 + c) % 360;
  }
  return HSLColor.fromAHSL(1, h.toDouble(), 0.65, 0.48).toColor();
}

DateTime siguiente(DateTime f, String r) {
  if (r == 'd') return DateTime(f.year, f.month, f.day + 1);
  if (r == 'w') return DateTime(f.year, f.month, f.day + 7);
  final ult = DateTime(f.year, f.month + 2, 0).day;
  return DateTime(f.year, f.month + 1, f.day > ult ? ult : f.day);
}

// -------------------------------------------------------------------- Modelo

class Sub {
  Sub(this.x, [this.d = false]);
  String x;
  bool d;
}

class Tarea {
  Tarea({
    required this.id,
    required this.titulo,
    required this.fecha,
    this.hora,
    this.nota = '',
    this.prioridad = 0, // 0 normal, 1 alta, 2 baja
    this.hecha = false,
    this.mat = '',
    this.rep = '',
    List<Sub>? subs,
    this.doneAt,
    this.spawned = false,
    this.recordar = false,
  }) : subs = subs ?? [];

  final String id;
  String titulo;
  DateTime fecha;
  TimeOfDay? hora;
  String nota;
  int prioridad;
  bool hecha;
  String mat;
  String rep;
  List<Sub> subs;
  String? doneAt;
  bool spawned;
  bool recordar;

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'fecha': claveDia(fecha),
        'hora': hora == null ? null : '${hora!.hour}:${hora!.minute}',
        'nota': nota,
        'prioridad': prioridad,
        'hecha': hecha,
        'mat': mat,
        'rep': rep,
        'subs': subs.map((s) => {'x': s.x, 'd': s.d}).toList(),
        'doneAt': doneAt,
        'spawned': spawned,
        'recordar': recordar,
      };

  factory Tarea.fromJson(Map<String, dynamic> j) {
    final h = j['hora'] as String?;
    final rep = (j['rep'] as String?) ?? '';
    final tit = (j['titulo'] as String).trim();
    if (tit.isEmpty) throw const FormatException('título vacío');
    return Tarea(
      id: j['id'] as String,
      titulo: tit.length > 120 ? tit.substring(0, 120) : tit,
      fecha: DateTime.parse(j['fecha'] as String),
      hora: h == null
          ? null
          : TimeOfDay(
              hour: int.parse(h.split(':')[0]),
              minute: int.parse(h.split(':')[1])),
      nota: (j['nota'] as String?) ?? '',
      prioridad: lim((j['prioridad'] as int?) ?? 0, 0, 2),
      hecha: (j['hecha'] as bool?) ?? false,
      mat: (j['mat'] as String?) ?? '',
      rep: repTxt.containsKey(rep) ? rep : '',
      subs: ((j['subs'] as List?) ?? [])
          .map((e) => Sub((e as Map)['x'] as String, (e['d'] as bool?) ?? false))
          .toList(),
      doneAt: j['doneAt'] as String?,
      spawned: (j['spawned'] as bool?) ?? false,
      recordar: (j['recordar'] as bool?) ?? false,
    );
  }
}

class Almacen {
  static const _llave = 'agenda.tareas.v1';

  static Future<List<Tarea>> cargar() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_llave);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Tarea.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> guardar(List<Tarea> tareas) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _llave, jsonEncode(tareas.map((t) => t.toJson()).toList()));
  }
}

// ------------------------------------------------------------ Notificaciones

class Avisos {
  static final _p = FlutterLocalNotificationsPlugin();
  static bool _listo = false;

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'recordatorios',
      'Recordatorios de tareas',
      channelDescription: 'Avisos de tus tareas a la hora indicada',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static AndroidFlutterLocalNotificationsPlugin? get _android => _p
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> iniciar() async {
    try {
      tzdata.initializeTimeZones();
      await _p.initialize(
        settings: InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _listo = true;
    } catch (_) {
      _listo = false;
    }
  }

  /// Pide permiso de notificaciones y, si hace falta, de alarmas exactas.
  static Future<bool> pedirPermisos() async {
    final a = _android;
    if (a == null) return false;
    final ok = await a.requestNotificationsPermission() ?? false;
    if (ok && !(await a.canScheduleExactNotifications() ?? false)) {
      await a.requestExactAlarmsPermission();
    }
    return ok;
  }

  static int _numero(String id) {
    var h = 7;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  /// Reprograma todos los avisos pendientes según las tareas actuales.
  static Future<void> sincronizar(List<Tarea> tareas) async {
    if (!_listo) return;
    try {
      await _p.cancelAllPendingNotifications();
      final ahora = DateTime.now();
      final exacto = await _android?.canScheduleExactNotifications() ?? false;
      final proximas = <(DateTime, Tarea)>[];
      for (final t in tareas) {
        if (!t.recordar || t.hecha || t.hora == null) continue;
        final cuando = DateTime(t.fecha.year, t.fecha.month, t.fecha.day,
            t.hora!.hour, t.hora!.minute);
        if (cuando.isAfter(ahora)) proximas.add((cuando, t));
      }
      proximas.sort((a, b) => a.$1.compareTo(b.$1));
      for (final e in proximas.take(50)) {
        final t = e.$2;
        await _p.zonedSchedule(
          id: _numero(t.id),
          title: t.titulo,
          body: t.mat.isEmpty
              ? 'Es la hora de tu tarea'
              : 'Es la hora de tu tarea · ${t.mat}',
          scheduledDate: tz.TZDateTime.from(e.$1, tz.UTC),
          notificationDetails: _detalles,
          androidScheduleMode: exacto
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {}
  }

  static Future<void> probar() async {
    if (!_listo) return;
    await _p.show(
      id: 1,
      title: 'Agenda diaria',
      body: 'Las notificaciones funcionan correctamente',
      notificationDetails: _detalles,
    );
  }
}

// -------------------------------------------- Captura en lenguaje natural

({String titulo, DateTime? fecha, TimeOfDay? hora}) interpretar(String texto) {
  var t = texto;
  DateTime? fecha;
  TimeOfDay? hora;
  final hoy = soloFecha(DateTime.now());

  final dia = RegExp(r'\b(pasado mañana|mañana|hoy)\b', caseSensitive: false)
      .firstMatch(t);
  final esMomento =
      RegExp(r'\b(la|esta) mañana\b', caseSensitive: false).hasMatch(t);
  if (dia != null && !esMomento) {
    final p = dia.group(1)!.toLowerCase();
    final n = p == 'hoy' ? 0 : (p == 'mañana' ? 1 : 2);
    fecha = DateTime(hoy.year, hoy.month, hoy.day + n);
    t = t.replaceFirst(dia.group(0)!, '');
  }

  if (fecha == null) {
    const dias = {
      'lunes': 1,
      'martes': 2,
      'miércoles': 3,
      'miercoles': 3,
      'jueves': 4,
      'viernes': 5,
      'sábado': 6,
      'sabado': 6,
      'domingo': 7,
    };
    final w = RegExp(
            r'(?:\bel\s+)?\b(lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)\b',
            caseSensitive: false)
        .firstMatch(t);
    if (w != null) {
      final d = dias[w.group(1)!.toLowerCase()]!;
      final falta = ((d - hoy.weekday + 6) % 7) + 1;
      fecha = DateTime(hoy.year, hoy.month, hoy.day + falta);
      t = t.replaceFirst(w.group(0)!, '');
    }
  }

  final m = RegExp(r'(?:\ba\s+las?\s+)?\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
              caseSensitive: false)
          .firstMatch(t) ??
      RegExp(r'\ba\s+las?\s+(\d{1,2})(?::(\d{2}))?\b', caseSensitive: false)
          .firstMatch(t) ??
      RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(t);
  if (m != null) {
    var h = int.parse(m.group(1)!);
    final mi = int.parse(m.group(2) ?? '0');
    final ap = m.groupCount >= 3 ? m.group(3)?.toLowerCase() : null;
    if (ap == 'pm' && h < 12) h += 12;
    if (ap == 'am' && h == 12) h = 0;
    if (h < 24 && mi < 60) {
      hora = TimeOfDay(hour: h, minute: mi);
      t = t.replaceFirst(m.group(0)!, '');
    }
  }

  t = t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return (titulo: t.isEmpty ? texto.trim() : t, fecha: fecha, hora: hora);
}

// ------------------------------------------------------------------ Pantalla

class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  List<Tarea> tareas = [];
  DateTime sel = soloFecha(DateTime.now());
  String mat = '';
  String q = '';
  bool buscando = false;

  @override
  void initState() {
    super.initState();
    Almacen.cargar().then((l) async {
      if (!mounted) return;
      setState(() => tareas = l);
      Avisos.sincronizar(l);
      final p = await SharedPreferences.getInstance();
      if (p.getBool('agenda.intro') != true && mounted) {
        await p.setBool('agenda.intro', true);
        await _intro();
      }
    });
  }

  Future<void> _intro() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true, builder: (_) => const Introduccion()));
  }

  void _guardar() {
    Almacen.guardar(tareas);
    Avisos.sincronizar(tareas);
  }

  void _aviso(String m) {
    final s = ScaffoldMessenger.of(context);
    s.clearSnackBars();
    s.showSnackBar(SnackBar(content: Text(m)));
  }

  int _peso(Tarea t) => t.prioridad == 1 ? 0 : (t.prioridad == 0 ? 1 : 2);

  List<String> get _materias =>
      (tareas.map((t) => t.mat).where((m) => m.isNotEmpty).toSet().toList()
        ..sort());

  bool _coincide(Tarea t) {
    if (mat.isNotEmpty && t.mat != mat) return false;
    if (q.isEmpty) return true;
    final s =
        '${t.titulo} ${t.nota} ${t.mat} ${t.subs.map((e) => e.x).join(' ')}'
            .toLowerCase();
    return s.contains(q);
  }

  List<Tarea> get _lista {
    if (q.isNotEmpty) {
      return tareas.where(_coincide).toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));
    }
    final l =
        tareas.where((t) => mismoDia(t.fecha, sel) && _coincide(t)).toList();
    int minutos(Tarea t) =>
        t.hora == null ? 9999 : t.hora!.hour * 60 + t.hora!.minute;
    l.sort((a, b) {
      if (a.hecha != b.hecha) return a.hecha ? 1 : -1;
      final c = minutos(a).compareTo(minutos(b));
      return c != 0 ? c : _peso(a).compareTo(_peso(b));
    });
    return l;
  }

  Future<void> _elegirFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: sel,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => sel = soloFecha(d));
  }

  Future<void> _form([Tarea? t]) async {
    final r = await showModalBottomSheet<Tarea>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FormTarea(tarea: t, fecha: sel, materias: _materias),
    );
    if (r == null) return;
    setState(() {
      if (!tareas.contains(r)) tareas.add(r);
      sel = soloFecha(r.fecha);
    });
    _guardar();
  }

  void _alternar(Tarea t) {
    setState(() {
      t.hecha = !t.hecha;
      t.doneAt = t.hecha ? claveDia(DateTime.now()) : null;
      if (t.hecha && t.rep.isNotEmpty && !t.spawned) {
        t.spawned = true;
        tareas.add(Tarea(
          id: nuevoId(),
          titulo: t.titulo,
          fecha: siguiente(t.fecha, t.rep),
          hora: t.hora,
          nota: t.nota,
          prioridad: t.prioridad,
          mat: t.mat,
          rep: t.rep,
          recordar: t.recordar,
          subs: t.subs.map((s) => Sub(s.x)).toList(),
        ));
      }
    });
    _guardar();
  }

  void _borrar(Tarea t) {
    final i = tareas.indexOf(t);
    setState(() => tareas.remove(t));
    _guardar();
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      content: const Text('Tarea eliminada'),
      action: SnackBarAction(
        label: 'Deshacer',
        onPressed: () {
          setState(() => tareas.insert(lim(i, 0, tareas.length), t));
          _guardar();
        },
      ),
    ));
  }

  // ---------------------------------------------------------------- Resumen

  void _resumen() {
    final hoy = soloFecha(DateTime.now());
    final lunes = DateTime(hoy.year, hoy.month, hoy.day - (hoy.weekday - 1));
    final dias = List.generate(7, (i) {
      final d = DateTime(lunes.year, lunes.month, lunes.day + i);
      final a = tareas.where((t) => mismoDia(t.fecha, d)).toList();
      return (d: d, n: a.length, h: a.where((t) => t.hecha).length);
    });
    final n = dias.fold<int>(0, (s, x) => s + x.n);
    final h = dias.fold<int>(0, (s, x) => s + x.h);
    final mx = dias.fold<int>(1, (s, x) => x.n > s ? x.n : s);
    final hechos =
        tareas.where((t) => t.doneAt != null).map((t) => t.doneAt!).toSet();
    var r = 0;
    var c = hechos.contains(claveDia(hoy))
        ? hoy
        : DateTime(hoy.year, hoy.month, hoy.day - 1);
    while (hechos.contains(claveDia(c))) {
      r++;
      c = DateTime(c.year, c.month, c.day - 1);
    }
    final pct = n > 0 ? ' (${(h * 100 / n).round()} %)' : '';
    final racha = r > 0
        ? 'Racha: $r ${r == 1 ? "día seguido" : "días seguidos"} completando tareas.'
        : 'Completa una tarea hoy para empezar una racha.';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resumen de la semana',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('$h de $n tareas completadas$pct'),
              const SizedBox(height: 16),
              SizedBox(
                height: 130,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final x in dias)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: 90 * x.n / mx + 4,
                                clipBehavior: Clip.antiAlias,
                                alignment: Alignment.bottomCenter,
                                decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Container(
                                  height: x.n == 0
                                      ? 0
                                      : (90 * x.n / mx + 4) * x.h / x.n,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(DateFormat('E', 'es').format(x.d),
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(racha),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- Ajustes

  String get _csv {
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final filas = [
      'Título,Fecha,Hora,Materia,Prioridad,Repetición,Subtareas,Nota,Completada',
      for (final t in tareas)
        [
          t.titulo,
          claveDia(t.fecha),
          t.hora == null
              ? ''
              : '${t.hora!.hour.toString().padLeft(2, '0')}:${t.hora!.minute.toString().padLeft(2, '0')}',
          t.mat,
          const ['Normal', 'Alta', 'Baja'][t.prioridad],
          repTxt[t.rep] ?? '',
          t.subs.map((s) => s.x).join('; '),
          t.nota,
          t.hecha ? 'Sí' : 'No',
        ].map(esc).join(','),
    ];
    return filas.join('\n');
  }

  Future<void> _copiar(String texto, String msg) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (mounted) _aviso(msg);
  }

  Future<void> _restaurar() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar copia'),
        content: TextField(
          controller: c,
          maxLines: 6,
          decoration:
              const InputDecoration(hintText: 'Pega aquí el JSON copiado'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final lista = jsonDecode(c.text) as List;
      final ids = tareas.map((t) => t.id).toSet();
      var n = 0;
      for (final e in lista) {
        try {
          final t = Tarea.fromJson(e as Map<String, dynamic>);
          if (ids.add(t.id)) {
            tareas.add(t);
            n++;
          }
        } catch (_) {}
      }
      setState(() {});
      _guardar();
      _aviso('$n tareas importadas');
    } catch (_) {
      _aviso('El texto no es una copia válida');
    }
  }

  Future<void> _borrarTodo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar todos los datos'),
        content: const Text('Se eliminarán todas las tareas. No se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => tareas.clear());
    _guardar();
    _aviso('Datos borrados');
  }

  void _ajustes() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajustes', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text('Tema'),
              const SizedBox(height: 8),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: temaModo,
                builder: (_, m, __) => SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
                  ],
                  selected: {m},
                  onSelectionChanged: (s) async {
                    temaModo.value = s.first;
                    final p = await SharedPreferences.getInstance();
                    await p.setString(
                        'agenda.tema',
                        s.first == ThemeMode.light
                            ? 'light'
                            : (s.first == ThemeMode.dark ? 'dark' : 'system'));
                  },
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Activar notificaciones'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await Avisos.pedirPermisos();
                  if (mounted) {
                    _aviso(ok
                        ? 'Notificaciones activadas'
                        : 'Permiso de notificaciones denegado');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.notification_add_outlined),
                title: const Text('Enviar notificación de prueba'),
                onTap: () {
                  Navigator.pop(ctx);
                  Avisos.probar();
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Ver la introducción'),
                onTap: () {
                  Navigator.pop(ctx);
                  _intro();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copiar copia de seguridad (JSON)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _copiar(
                      jsonEncode(tareas.map((t) => t.toJson()).toList()),
                      'Copia en el portapapeles. Pégala en un lugar seguro.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Copiar como CSV (Excel)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _copiar(_csv, 'CSV copiado al portapapeles');
                },
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restaurar copia (pegar JSON)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _restaurar();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_forever,
                    color: Theme.of(ctx).colorScheme.error),
                title: Text('Borrar todos los datos',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _borrarTodo();
                },
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Tus datos se guardan solo en este dispositivo.',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Componentes

  Widget _semana() {
    final cs = Theme.of(context).colorScheme;
    final lunes = DateTime(sel.year, sel.month, sel.day - (sel.weekday - 1));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(7, (i) {
          final d = DateTime(lunes.year, lunes.month, lunes.day + i);
          final on = mismoDia(d, sel);
          final esHoy = mismoDia(d, DateTime.now());
          final pend = tareas.any((t) => mismoDia(t.fecha, d) && !t.hecha);
          return Expanded(
            child: Semantics(
              button: true,
              selected: on,
              label: fechaLarga(d),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => sel = d),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? cs.primary : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: esHoy && !on
                        ? Border.all(color: cs.primary, width: 2)
                        : null,
                  ),
                  child: Column(children: [
                    Text(DateFormat('E', 'es').format(d),
                        style: TextStyle(
                            fontSize: 12,
                            color: on ? cs.onPrimary : cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text('${d.day}',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: on ? cs.onPrimary : cs.onSurface)),
                    const SizedBox(height: 4),
                    Icon(Icons.circle,
                        size: 6,
                        color: pend
                            ? (on ? cs.onPrimary : cs.primary)
                            : Colors.transparent),
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _chips() {
    final ms = _materias;
    if (mat.isNotEmpty && !ms.contains(mat)) mat = '';
    if (ms.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todas'),
              selected: mat.isEmpty,
              onSelected: (_) => setState(() => mat = ''),
            ),
          ),
          for (final m in ms)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(Icons.circle, size: 12, color: colorMat(m)),
                label: Text(m),
                selected: mat == m,
                onSelected: (_) => setState(() => mat = mat == m ? '' : m),
              ),
            ),
        ],
      ),
    );
  }

  Widget _item(Tarea t) {
    final cs = Theme.of(context).colorScheme;
    final partes = <String>[
      if (q.isNotEmpty) DateFormat('d MMM', 'es').format(t.fecha),
      if (t.hora != null) t.hora!.format(context),
      if (t.subs.isNotEmpty)
        '${t.subs.where((s) => s.d).length}/${t.subs.length} pasos',
      if (t.prioridad == 1) 'Prioridad alta',
      if (t.prioridad == 2) 'Prioridad baja',
      if (t.rep.isNotEmpty) 'Se repite ${repTxt[t.rep]}',
      if (t.nota.isNotEmpty) t.nota,
    ];
    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
            color: cs.errorContainer, borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.delete, color: cs.onErrorContainer),
      ),
      onDismissed: (_) => _borrar(t),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Container(
          decoration: t.prioridad == 0
              ? null
              : BoxDecoration(
                  border: Border(
                      left: BorderSide(
                          color: t.prioridad == 1 ? cs.error : cs.outline,
                          width: 5))),
          child: Column(children: [
            ListTile(
              leading: Checkbox(
                  value: t.hecha, onChanged: (_) => _alternar(t)),
              title: Text(t.titulo,
                  style: TextStyle(
                      decoration:
                          t.hecha ? TextDecoration.lineThrough : null,
                      color: t.hecha ? cs.onSurfaceVariant : null)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t.mat.isNotEmpty)
                    Row(children: [
                      Icon(Icons.circle, size: 10, color: colorMat(t.mat)),
                      const SizedBox(width: 6),
                      Flexible(child: Text(t.mat)),
                    ]),
                  if (partes.isNotEmpty) Text(partes.join(' · ')),
                ],
              ),
              onTap: () => _form(t),
            ),
            for (var i = 0; i < t.subs.length; i++)
              InkWell(
                onTap: () {
                  setState(() => t.subs[i].d = !t.subs[i].d);
                  _guardar();
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 4, 16, 4),
                  child: Row(children: [
                    Icon(
                        t.subs[i].d
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: t.subs[i].d ? cs.primary : cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(t.subs[i].x,
                          style: TextStyle(
                              decoration: t.subs[i].d
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: t.subs[i].d
                                  ? cs.onSurfaceVariant
                                  : null)),
                    ),
                  ]),
                ),
              ),
            if (t.subs.isNotEmpty) const SizedBox(height: 6),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _lista;
    final hechas = lista.where((t) => t.hecha).length;
    final hoy = soloFecha(DateTime.now());
    final venc = tareas.where((t) => !t.hecha && t.fecha.isBefore(hoy)).length;
    final items = <Widget>[];
    for (var i = 0; i < lista.length; i++) {
      if (q.isEmpty && lista[i].hecha && (i == 0 || !lista[i - 1].hecha)) {
        items.add(const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text('Completadas',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ));
      }
      items.add(_item(lista[i]));
    }
    final resumen = q.isNotEmpty
        ? '${lista.length} ${lista.length == 1 ? "resultado" : "resultados"}'
        : (lista.isEmpty
            ? 'Sin tareas'
            : '$hechas de ${lista.length} completadas');

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _elegirFecha,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
                child: Text(fechaLarga(sel),
                    style: const TextStyle(fontSize: 18),
                    overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ]),
        ),
        actions: [
          if (!mismoDia(sel, hoy))
            IconButton(
              tooltip: 'Ir a hoy',
              icon: const Icon(Icons.today),
              onPressed: () => setState(() => sel = hoy),
            ),
          IconButton(
            tooltip: 'Buscar',
            icon: Icon(buscando ? Icons.search_off : Icons.search),
            onPressed: () => setState(() {
              buscando = !buscando;
              if (!buscando) q = '';
            }),
          ),
          IconButton(
              tooltip: 'Resumen semanal',
              icon: const Icon(Icons.bar_chart),
              onPressed: _resumen),
          IconButton(
              tooltip: 'Ajustes',
              icon: const Icon(Icons.tune),
              onPressed: _ajustes),
        ],
      ),
      body: Column(children: [
        if (buscando)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar en todas las fechas',
                  border: OutlineInputBorder()),
              onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
            ),
          ),
        const SizedBox(height: 8),
        _semana(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(resumen),
            const SizedBox(height: 6),
            LinearProgressIndicator(
                value: lista.isEmpty ? 0 : hechas / lista.length),
          ]),
        ),
        _chips(),
        if (mismoDia(sel, hoy) && venc > 0 && q.isEmpty)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: ListTile(
              leading: const Icon(Icons.warning_amber),
              title: Text('$venc ${venc == 1 ? "tarea vencida" : "tareas vencidas"}'),
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    for (final t in tareas) {
                      if (!t.hecha && t.fecha.isBefore(hoy)) t.fecha = hoy;
                    }
                  });
                  _guardar();
                  _aviso('Tareas movidas a hoy');
                },
                child: const Text('Pasar a hoy'),
              ),
            ),
          ),
        Expanded(
          child: lista.isEmpty
              ? Center(
                  child: Text(
                      q.isNotEmpty
                          ? 'Sin resultados'
                          : 'No hay nada planeado para este día.\nToca «Nueva tarea» para agregar una.',
                      textAlign: TextAlign.center))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 90), children: items),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
    );
  }
}

// --------------------------------------------------------------- Formulario

class FormTarea extends StatefulWidget {
  const FormTarea(
      {super.key, this.tarea, required this.fecha, required this.materias});

  final Tarea? tarea;
  final DateTime fecha;
  final List<String> materias;

  @override
  State<FormTarea> createState() => _FormTareaState();
}

class _FormTareaState extends State<FormTarea> {
  late final TextEditingController titulo =
      TextEditingController(text: widget.tarea?.titulo ?? '');
  late final TextEditingController nota =
      TextEditingController(text: widget.tarea?.nota ?? '');
  late final TextEditingController materia =
      TextEditingController(text: widget.tarea?.mat ?? '');
  late final TextEditingController subs = TextEditingController(
      text: widget.tarea?.subs.map((s) => s.x).join('\n') ?? '');
  late DateTime fecha = widget.tarea?.fecha ?? widget.fecha;
  late TimeOfDay? hora = widget.tarea?.hora;
  late int prio = widget.tarea?.prioridad ?? 0;
  late String rep = widget.tarea?.rep ?? '';
  late bool recordar = widget.tarea?.recordar ?? false;

  @override
  void dispose() {
    titulo.dispose();
    nota.dispose();
    materia.dispose();
    subs.dispose();
    super.dispose();
  }

  void _guardar() {
    var tit = titulo.text.trim();
    if (tit.isEmpty) return;
    var f = fecha;
    var h = hora;
    if (widget.tarea == null) {
      final r = interpretar(tit);
      tit = r.titulo;
      if (r.fecha != null) f = r.fecha!;
      if (h == null && r.hora != null) h = r.hora;
    }
    final antes = widget.tarea?.subs ?? <Sub>[];
    final pasos = subs.text
        .split('\n')
        .map((x) => x.trim())
        .where((x) => x.isNotEmpty)
        .take(20)
        .map((x) => Sub(x, antes.any((o) => o.x == x && o.d)))
        .toList();
    final t = widget.tarea ?? Tarea(id: nuevoId(), titulo: tit, fecha: f);
    t.titulo = tit;
    t.fecha = f;
    t.hora = h;
    t.nota = nota.text.trim();
    t.prioridad = prio;
    t.mat = materia.text.trim();
    t.rep = rep;
    t.recordar = recordar && h != null;
    t.subs = pasos;
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tarea == null ? 'Nueva tarea' : 'Editar tarea',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: titulo,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej. Informe de física mañana 3pm',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('d MMM y', 'es').format(fecha)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: fecha,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => fecha = soloFecha(d));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(hora?.format(context) ?? 'Sin hora'),
                  onPressed: () async {
                    final h = await showTimePicker(
                        context: context,
                        initialTime: hora ?? TimeOfDay.now());
                    if (h != null) setState(() => hora = h);
                  },
                ),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recordarme a la hora indicada'),
              subtitle:
                  hora == null ? const Text('Elige una hora para activarlo') : null,
              value: recordar && hora != null,
              onChanged: hora == null
                  ? null
                  : (v) async {
                      setState(() => recordar = v);
                      if (v) {
                        final ok = await Avisos.pedirPermisos();
                        if (!ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Sin permiso de notificaciones no sonará el aviso')));
                        }
                      }
                    },
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Normal')),
                ButtonSegment(value: 1, label: Text('Alta')),
                ButtonSegment(value: 2, label: Text('Baja')),
              ],
              selected: {prio},
              onSelectionChanged: (s) => setState(() => prio = s.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: rep,
              decoration: const InputDecoration(
                  labelText: 'Repetir', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: '', child: Text('No')),
                DropdownMenuItem(value: 'd', child: Text('Cada día')),
                DropdownMenuItem(value: 'w', child: Text('Cada semana')),
                DropdownMenuItem(value: 'm', child: Text('Cada mes')),
              ],
              onChanged: (v) => setState(() => rep = v ?? ''),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: materia,
              maxLength: 24,
              decoration: const InputDecoration(
                  labelText: 'Materia o etiqueta (opcional)',
                  border: OutlineInputBorder()),
            ),
            if (widget.materias.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  for (final m in widget.materias)
                    ActionChip(
                      label: Text(m),
                      onPressed: () => setState(() => materia.text = m),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            TextField(
              controller: subs,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                  labelText: 'Subtareas (una por línea)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nota,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Nota (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              const SizedBox(width: 8),
              FilledButton(onPressed: _guardar, child: const Text('Guardar')),
            ]),
          ],
        ),
      ),
    );
  }
}


// ------------------------------------------------------------- Introducción

class Introduccion extends StatefulWidget {
  const Introduccion({super.key});

  @override
  State<Introduccion> createState() => _IntroduccionState();
}

class _IntroduccionState extends State<Introduccion> {
  final _c = PageController();
  int _i = 0;

  static const _pasos = [
    (
      Icons.today,
      'Tu día en una sola pantalla',
      'Toca la fecha para saltar a cualquier día del calendario y usa la tira semanal para moverte rápido.'
    ),
    (
      Icons.edit_note,
      'Escribe como hablas',
      'Prueba «Informe de física mañana 3pm» o «Reunión el viernes a las 15:30»: la app detecta la fecha y la hora. Agrega subtareas, materias y repeticiones al crear la tarea.'
    ),
    (
      Icons.notifications_active,
      'Recordatorios y datos tuyos',
      'Activa «Recordarme» en una tarea con hora y recibirás una notificación aunque la app esté cerrada. Todo se guarda solo en este teléfono.'
    ),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_i < _pasos.length - 1) {
      _c.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Omitir')),
          ),
          Expanded(
            child: PageView(
              controller: _c,
              onPageChanged: (v) => setState(() => _i = v),
              children: [
                for (final p in _pasos)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(p.$1, size: 96, color: cs.primary),
                        const SizedBox(height: 32),
                        Text(p.$2,
                            textAlign: TextAlign.center,
                            style: tt.headlineSmall),
                        const SizedBox(height: 16),
                        Text(p.$3,
                            textAlign: TextAlign.center, style: tt.bodyLarge),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < _pasos.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                width: k == _i ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                    color: k == _i ? cs.primary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _siguiente,
                  child: Text(_i == _pasos.length - 1 ? 'Empezar' : 'Siguiente')),
            ),
          ),
        ]),
      ),
    );
  }
}
