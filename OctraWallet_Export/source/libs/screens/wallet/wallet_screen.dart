import 'package:flutter/material.dart';
import 'dashboard_tab.dart';
import 'history_tab.dart';
import 'send_tab.dart';
import 'privacy_tab.dart';
import 'settings_tab.dart'; // Make sure you create this file

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ouqro.'),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: tabIndex,
        // Updated children list as requested
        children: const [
          DashboardTab(),
          HistoryTab(),
          SendTab(),
          PrivacyTab(),
          SettingsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: (i) => setState(() => tabIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: 'history'),
          BottomNavigationBarItem(
              icon: Icon(Icons.send), label: 'send'),
          BottomNavigationBarItem(
              icon: Icon(Icons.lock), label: 'privacy'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'settings'),
        ],
      ),
    );
  }
}