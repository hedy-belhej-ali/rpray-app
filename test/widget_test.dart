import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rafel/core/rafel_theme.dart';
import 'package:rafel/ui/widgets/rafel_widgets.dart';

void main() {
  testWidgets('Rpray uses the specified brand colours in dark mode', (tester) async {
    final dark = RafelThemeScheme.dark();
    expect(dark.scaffoldBackgroundColor, const Color(0xFF090909));

    await tester.pumpWidget(
      MaterialApp(
        theme: RafelThemeScheme.light(),
        darkTheme: RafelThemeScheme.dark(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          backgroundColor: Color(0xFF090909),
          body: Center(
            child: RafelPill(
              label: 'Fajr in 10 minutes',
              icon: Icons.notifications_none,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Fajr in 10 minutes'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
  });

  testWidgets('section labels render with and without trailing widgets',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RafelThemeScheme.light(),
        home: const Scaffold(
          body: Column(
            children: <Widget>[
              RafelSectionLabel('Prayers'),
              RafelSectionLabel('Occasions', trailing: Text('Later')),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Prayers'), findsOneWidget);
    expect(find.text('Occasions'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });
}
