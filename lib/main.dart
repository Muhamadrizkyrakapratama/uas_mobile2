import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/transaction_provider.dart';
import 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => TransactionProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    // Color tokens matching the web app design system
    const primaryColor = Color(0xFF10B981); // Emerald Green
    const primaryHover = Color(0xFF059669); // Darker Green
    
    // Dark Theme Colors
    const darkBgColor = Color(0xFF050D09); // Deep Forest Green Black
    const darkCardColor = Color(0xFF0D1B14); // Frosted Glass Dark Green Card
    
    // Light Theme Colors
    const lightBgColor = Color(0xFFF5F8F6); // Soft off-white (not too bright)
    const lightCardColor = Color(0xFFFFFFFF); // White Card

    return MaterialApp(
      title: 'SimPay',
      debugShowCheckedModeBanner: false,
      themeMode: context.watch<TransactionProvider>().themeMode,
      
      // Light Mode (Mint Green & White)
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBgColor,
        primaryColor: primaryColor,
        colorScheme: const ColorScheme.light(
          primary: primaryColor,
          secondary: primaryHover,
          background: lightBgColor,
          surface: lightCardColor,
          onPrimary: Colors.white,
          onSurface: Color(0xFF0F2015), // Deep forest text
        ),
        cardTheme: const CardTheme(
          color: lightCardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0x2610B981), width: 1.5), // Subtle green border
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0F2015)),
        ),
        fontFamily: 'Inter',
      ),

      // Dark Mode (Deep Forest/Emerald Green)
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBgColor,
        primaryColor: primaryColor,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: primaryHover,
          background: darkBgColor,
          surface: darkCardColor,
          onPrimary: Colors.white,
          onSurface: Color(0xFFF2FAF6), // Light text
        ),
        cardTheme: const CardTheme(
          color: darkCardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0x1F10B981), width: 1.5), // Subtle glowing border
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFF2FAF6)),
        ),
        fontFamily: 'Inter',
      ),
      home: const HomePage(),
    );
  }
}
