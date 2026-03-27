import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color bgDark = Color(0xFF020B18);
  static const Color bgMid = Color(0xFF051428);
  static const Color cardStart = Color(0xFF0A2040);
  static const Color cardEnd = Color(0xFF041020);
  static const Color borderColor = Color(0xFF1E90FF);
  static const Color accentBlue = Color(0xFF1E90FF);
  static const Color accentCyan = Color(0xFF00D4FF);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textSub = Color(0xFF8BAFC8);
  static const Color success = Color(0xFF00E676);
  static const Color danger = Color(0xFFFF1744);
  static const Color warning = Color(0xFFFFAB00);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        fontFamily: 'ComicRelief',
        colorScheme: const ColorScheme.dark(
          primary: accentBlue,
          secondary: accentCyan,
          surface: bgMid,
          error: danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgMid,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: textWhite,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'ComicRelief',
          ),
          iconTheme: IconThemeData(color: accentBlue),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentBlue,
            foregroundColor: textWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'ComicRelief',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardStart,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: accentCyan, width: 2),
          ),
          labelStyle: const TextStyle(color: textSub),
          hintStyle: const TextStyle(color: textSub),
          prefixIconColor: accentBlue,
        ),
      );

  // Gradient box decoration
  static BoxDecoration get cardDecoration => BoxDecoration(
        gradient: const LinearGradient(
          colors: [cardStart, cardEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      );
    
    static Color typeColor(String type) {
      switch (type.toLowerCase()) {
        case 'fire':      return const Color(0xffff4422);
        case 'water':     return const Color(0xff3399ff);
        case 'grass':     return const Color(0xff77cc55);
        case 'electric':  return const Color(0xffffcc33);
        case 'psychic':   return const Color(0xffff5599);
        case 'ghost':     return const Color(0xff6666bb);
        case 'dragon':    return const Color(0xff7766ee);
        case 'dark':      return const Color(0xff775544);
        case 'ice':       return const Color(0xff77ddff);
        case 'fighting':  return const Color(0xffbb5544);
        case 'poison':    return const Color(0xffaa5599);
        case 'ground':    return const Color(0xffddbb55);
        case 'flying':    return const Color(0xff6699ff);
        case 'rock':      return const Color(0xffbbaa66);
        case 'steel':     return const Color(0xffaaaabb);
        case 'bug':       return const Color(0xff77cc55);
        case 'fairy':     return const Color(0xffffaaff);
        case 'normal':    return const Color(0xffbbbbaa);
        default:          return const Color(0xff1E90FF);
      }
    }

  static const List<String> monsterTypes = [
    'Normal', 'Fire', 'Water', 'Grass', 'Electric',
    'Ice', 'Fighting', 'Poison', 'Ground', 'Flying',
    'Psychic', 'Bug', 'Rock', 'Ghost', 'Dragon',
    'Dark', 'Steel', 'Fairy',
  ];
}