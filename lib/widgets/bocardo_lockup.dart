import 'package:flutter/material.dart';
class BocardoLockup extends StatelessWidget {
  const BocardoLockup({super.key, this.compact = false});

  final bool compact;

  static const _name = 'Bocardo';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final size = compact ? 44.0 : 72.0;

    final mark = Container(
      padding: EdgeInsets.all(compact ? 6 : 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(compact ? 14 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: compact ? 10 : 16,
            offset: Offset(0, compact ? 3 : 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/images/logo.jpeg',
          height: size,
          width: compact ? size : null,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );

    final name = Text(
      _name,
      style: (compact ? text.titleLarge : text.headlineMedium)?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: scheme.primary,
      ),
    );

    return Semantics(
      label: _name,
      child: compact
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [mark, const SizedBox(width: 12), name],
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [mark, const SizedBox(height: 12), name],
      ),
    );
  }
}