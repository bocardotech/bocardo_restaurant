import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../themes/brand.dart';

class RestaurantHomePage extends StatelessWidget {
  const RestaurantHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final name =
        AuthService.instance.restaurantName ?? 'your restaurant';

    final t = Theme
        .of(context)
        .textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Brand.cyan,
        foregroundColor: Colors.white,
        title: const BrandMark(size: 36),
        actions: [
          IconButton(
            tooltip: 'Auth Test Bench',
            icon: const Icon(Icons.science_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/auth-test-bench');
            },
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hello, $name',
            style: t.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Brand.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AuthService.instance.currentUser != null
                ? 'Logged in as ${AuthService.instance.currentUser!.ownerName} (${AuthService.instance.currentUser!.email})'
                : 'Here is how your day looks.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.receipt_long,
                  label: 'Orders today',
                  value: '0',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  icon: Icons.restaurant_menu,
                  label: 'Menu items',
                  value: '0',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Icon(
            Icons.inbox_outlined,
            size: 56,
            color: Brand.cyanDark,
          ),
          const SizedBox(height: 8),
          Text(
            'No orders yet',
            textAlign: TextAlign.center,
            style: t.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'New orders will appear here.',
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFCDE8EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Brand.cyanDark,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme
                .of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(
              fontWeight: FontWeight.w800,
              color: Brand.ink,
            ),
          ),
          Text(label),
        ],
      ),
    );
  }
}
