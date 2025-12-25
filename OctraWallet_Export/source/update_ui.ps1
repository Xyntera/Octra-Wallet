Write-Host "=== Fixing Octra Wallet UI (escaping-safe) ==="

function WriteFile($path, $content) {
    $dir = Split-Path $path
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    Set-Content -Path $path -Value $content -Encoding UTF8
    Write-Host "Updated $path"
}

# ---------------- DASHBOARD TAB ----------------
WriteFile "lib\screens\wallet\dashboard_tab.dart" @'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WalletProvider>();

    return RefreshIndicator(
      onRefresh: wp.refreshBalance,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'balance',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wp.publicBalance.toStringAsFixed(6) + ' OCT',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'nonce: ' + wp.nonce.toString(),
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
'@

# ---------------- HISTORY TAB ----------------
WriteFile "lib\screens\wallet\history_tab.dart" @'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WalletProvider>();
    final myAddress = wp.wallet!.address;

    if (wp.historyLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (wp.history.isEmpty) {
      return const Center(child: Text('no transactions'));
    }

    return RefreshIndicator(
      onRefresh: wp.refreshHistory,
      child: ListView.builder(
        itemCount: wp.history.length,
        itemBuilder: (context, i) {
          final tx = wp.history[i];
          final sent = tx.isSent(myAddress);

          return ListTile(
            leading: Icon(
              sent ? Icons.call_made : Icons.call_received,
              color: sent ? Colors.redAccent : Colors.greenAccent,
            ),
            title: Text(
              sent
                  ? 'to ' + tx.to.substring(0, 10) + '...'
                  : 'from ' + tx.from.substring(0, 10) + '...',
            ),
            subtitle: Text('epoch ' + tx.epoch.toString()),
            trailing: Text(
              (sent ? '-' : '+') + tx.amount.toStringAsFixed(4),
              style: TextStyle(
                color: sent ? Colors.redAccent : Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}
'@

Write-Host "=== UI FIX COMPLETE ==="
