import 'package:agenda_diaria/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interpreta «mañana» y la hora en pm', () {
    final r = interpretar('Informe de física mañana 3pm');
    final hoy = soloFecha(DateTime.now());
    expect(r.titulo, 'Informe de física');
    expect(r.fecha, DateTime(hoy.year, hoy.month, hoy.day + 1));
    expect(r.hora, const TimeOfDay(hour: 15, minute: 0));
  });

  test('no confunde «por la mañana» con la fecha de mañana', () {
    final r = interpretar('Estudiar por la mañana');
    expect(r.fecha, isNull);
    expect(r.titulo, 'Estudiar por la mañana');
  });

  test('la repetición mensual ajusta el fin de mes', () {
    expect(siguiente(DateTime(2026, 1, 31), 'm'), DateTime(2026, 2, 28));
  });

  test('la repetición semanal suma 7 días', () {
    expect(siguiente(DateTime(2026, 10, 12), 'w'), DateTime(2026, 10, 19));
  });
}