part of '../main.dart';

class OyudentPosApp extends StatelessWidget {
  const OyudentPosApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Oyudent POS',
    locale: const Locale('mn'),
    supportedLocales: const [Locale('mn')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      hoverColor: const Color(0x1668ECFF),
      focusColor: const Color(0x3368ECFF),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: aquaGlow,
        selectionColor: Color(0x5068ECFF),
      ),
      popupMenuTheme: const PopupMenuThemeData(color: deepSpaceMid),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: deepSpaceMid,
        contentTextStyle: TextStyle(color: ink),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: inputSurface,
        selectedColor: activeSurface,
        side: const BorderSide(color: lineColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(deepSpaceMid),
        headingTextStyle: TextStyle(
          color: aquaGlow,
          fontWeight: FontWeight.w600,
        ),
      ),

      scaffoldBackgroundColor: canvas,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: green,
            brightness: Brightness.light,
            surface: panelColor,
          ).copyWith(
            primary: green,
            onPrimary: deepSpace,
            secondary: aquaGlow,
            tertiary: violet,
            error: errorInk,
            onSurface: ink,
            onSurfaceVariant: muted,
            outline: lineColor,
            primaryContainer: activeSurface,
            onPrimaryContainer: green,
          ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: deepSpace,
          minimumSize: const Size(44, 42),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: green,
          minimumSize: const Size(44, 42),
          side: const BorderSide(color: lineColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panelColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lineColor),
        ),
      ),
      dividerTheme: const DividerThemeData(color: lineColor, thickness: 1),
      tooltipTheme: TooltipThemeData(
        textStyle: const TextStyle(color: ink),
        decoration: BoxDecoration(
          color: deepSpaceMid,
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: panelColor,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: green,
        linearTrackColor: lineColor,
        linearMinHeight: 5,
      ),
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: lineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: lineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: aquaGlow, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
      ),
      cardTheme: CardThemeData(
        color: panelColor,
        elevation: 0,
        shadowColor: const Color(0x160A1424),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: lineColor),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
    ),
    home: const LoginPage(),
  );
}
