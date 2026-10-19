import 'package:flutter/material.dart';

class Brand {
  static const cyan = Color(0xFF0CC4E8);
  static const cyanDark = Color(0xFF067A94);
  static const ink = Color(0xFF053A4A);
  static const yellow = Color(0xFFFFC61A);
  static const lime = Color(0xFFB7DE1F);
  static const mist = Color(0xFFEAF9FC);
}

ThemeData brandTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Brand.cyan).copyWith(
    primary: Brand.cyanDark,
    onPrimary: Colors.white,
    secondary: Brand.yellow,
    onSurface: Brand.ink,
  );
  OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.mist,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Brand.mist,
      border: border(const Color(0xFFCDE8EE)),
      enabledBorder: border(const Color(0xFFCDE8EE)),
      focusedBorder: border(Brand.cyanDark, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.yellow,
        foregroundColor: Brand.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Brand.cyanDark),
    ),
  );
}

InputDecoration fieldDeco(String label, IconData icon, {Widget? suffix}) =>
    InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixIcon: suffix);

Widget btnLabel(bool loading, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 14),
  child: loading
      ? const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: Brand.ink))
      : Text(text),
);

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48});
  final double size;

  Widget _fallback() => Center(
    child: Text('B',
        style: TextStyle(
            color: Brand.lime,
            fontSize: size * 0.56,
            fontWeight: FontWeight.w900,
            height: 1)),
  );

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Brand.cyan,
      border: Border.all(color: Colors.white, width: size * 0.07),
      boxShadow: const [
        BoxShadow(
            color: Color(0x33053A4A), blurRadius: 12, offset: Offset(0, 4)),
      ],
    ),
    child: ClipOval(
      child: Image.asset(
        'assets/images/logo.jpeg',
        fit: BoxFit.cover,
        semanticLabel: 'bocardo logo',
        errorBuilder: (_, _, _) => _fallback(),
      ),
    ),
  );
}

/// Logo + white "bocardo" wordmark + yellow dot.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandLogo(size: size),
      const SizedBox(width: 10),
      Text('bocardo',
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.62,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5)),
      Padding(
        padding: EdgeInsets.only(left: 4, bottom: size * 0.4),
        child: const CircleAvatar(radius: 4, backgroundColor: Brand.yellow),
      ),
    ],
  );
}

/// Cyan screen with the brand on top and a white card for the form.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Brand.cyan,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBack)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Back',
                        color: Colors.white,
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  const Center(child: BrandMark()),
                  const SizedBox(height: 6),
                  Text('Restaurant partner portal',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: Brand.ink, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Color(0x2E053A4A), blurRadius: 30, offset: Offset(0, 12)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title,
                            style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: Brand.ink)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: t.bodyMedium?.copyWith(color: const Color(0xFF4F6F7A))),
                        const SizedBox(height: 22),
                        child,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}