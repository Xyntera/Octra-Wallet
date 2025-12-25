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
