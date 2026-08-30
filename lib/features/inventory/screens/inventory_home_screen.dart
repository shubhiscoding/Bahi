import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/constants/strings.dart';

/// Placeholder: Inventory Home screen (Inventory + Team tabs)
class InventoryHomeScreen extends StatefulWidget {
  const InventoryHomeScreen({super.key});

  @override
  State<InventoryHomeScreen> createState() => _InventoryHomeScreenState();
}

class _InventoryHomeScreenState extends State<InventoryHomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('बही'),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          _selectedTab == 0 ? 'सामान सूची' : 'साथी',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (idx) => setState(() => _selectedTab = idx),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: Strings.inventory,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: Strings.team,
          ),
        ],
      ),
    );
  }
}
