import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/map_screen.dart';

void main() {
  testWidgets('abre planificador y muestra controles básicos', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MapScreen()));

    // Abre el menú de overflow (⋮)
    final menuFinder = find.byType(PopupMenuButton<String>);
    expect(menuFinder, findsOneWidget);
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();

    // Selecciona "Planificar ruta"
    expect(find.text('Planificar ruta'), findsOneWidget);
    await tester.tap(find.text('Planificar ruta'));
    await tester.pumpAndSettle();

    // Verifica elementos del panel
    expect(find.text('Planificador de ruta'), findsOneWidget);
    expect(find.text('Caminar'), findsOneWidget);
    expect(find.text('Conducir (aprox. bus)'), findsOneWidget);
    expect(find.text('Buscar dirección o lugar'), findsOneWidget);
    expect(find.text('Calcular ruta'), findsOneWidget);
  });
}

