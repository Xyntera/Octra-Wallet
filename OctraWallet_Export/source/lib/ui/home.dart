import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Colors, Icons, LinearGradient, Alignment, Scaffold, SelectableText; // Added SelectableText
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../wallet.dart';
import '../models.dart'; // Added Wallet model import
import '../rpc.dart'; // for response types
import 'wallet_setup.dart'; 
import 'scanner.dart';
import 'success_animation.dart';
import 'pin_screen.dart';

class HomeTabScaffold extends StatelessWidget {
  const HomeTabScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: const Color(0xCC1C1C1E),
        activeColor: CupertinoColors.systemBlue,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.lock_shield),
            label: 'Private',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.time),
            label: 'History',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return const DashboardTab();
          case 1:
            return const PrivateTab();
          case 2:
            return const HistoryTab();
          default:
            return const DashboardTab();
        }
      },
    );
  }
}

/// DASHBOARD TAB
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletController>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletCtrl = context.watch<WalletController>();
    final wallet = walletCtrl.currentWallet;

    if (wallet == null) return const Center(child: CupertinoActivityIndicator());

    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Octra', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: const Color(0xCC1C1C1E),
            leading: CupertinoButton(
               padding: EdgeInsets.zero,
               child: const Icon(CupertinoIcons.bars, color: CupertinoColors.systemBlue),
               onPressed: () => _showSideMenu(context),
            ),
             trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.square_list, color: CupertinoColors.systemBlue),
              onPressed: () => _showWalletsSheet(context),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
               await walletCtrl.refresh();
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // PUBLIC CARD
                  _buildBalanceCard(
                    title: 'Total Balance',
                    balance: walletCtrl.publicBalance,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: CupertinoIcons.globe,
                  ).animate().scale(delay: 100.ms),
                  const SizedBox(height: 32),
                  
                  // ACTIONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(context, icon: CupertinoIcons.arrow_up_right, label: 'Send', onTap: () => _showSendSheet(context)),
                      _buildActionButton(context, icon: CupertinoIcons.arrow_down_doc, label: 'Receive', onTap: () => _showReceiveSheet(context, wallet.address)),
                      _buildActionButton(context, icon: CupertinoIcons.lock_circle, label: 'Encrypt', onTap: () => _showEncryptSheet(context)),
                      _buildActionButton(context, icon: CupertinoIcons.lock_open, label: 'Decrypt', onTap: () => _showDecryptSheet(context)),
                    ],
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 40),
                  
                  // (Recent Activity Removed)
                ],
              ),
            ),
          ),
          
          // Padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 80))
        ],
      ),
    );
  }

  Widget _buildBalanceCard({required String title, required double balance, required Gradient gradient, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: gradient.colors.first.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: Colors.white70, size: 20), const SizedBox(width: 8), Text(title, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500))]),
          const SizedBox(height: 16),
          Text('${balance.toStringAsFixed(6)} OCT', style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return Column(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onTap,
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13)),
      ],
    );
  }
  
  // --- MENU & SHEETS ---

  void _showSideMenu(BuildContext context) {
    final walletCtrl = context.read<WalletController>(); // Access existing provider
    showCupertinoModalPopup(
       context: context,
       builder: (context) => Container(
         width: double.infinity,
         decoration: const BoxDecoration(color: Color(0xFF1C1C1E), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
         child: SafeArea(
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const SizedBox(height: 16),
               Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
               const SizedBox(height: 24),
               
               // WALLET INFO SECTION
               if (walletCtrl.hasWallet) ...[
                 Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color(walletCtrl.currentWallet!.color).withOpacity(0.3), width: 1)
                    ),
                    child: Row(
                      children: [
                         Container(width: 4, height: 36, decoration: BoxDecoration(color: Color(walletCtrl.currentWallet!.color), borderRadius: BorderRadius.circular(2))),
                         const SizedBox(width: 16),
                         Expanded(child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(walletCtrl.currentWallet!.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                             Text(walletCtrl.currentWallet!.address.substring(0,8)+"...", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                           ],
                         )),
                         CupertinoButton(
                           padding: EdgeInsets.zero,
                           minSize: 0,
                           child: const Icon(CupertinoIcons.pencil_circle_fill, color: Colors.white70, size: 28),
                           onPressed: () {
                              Navigator.pop(context); // Close Menu
                              showCupertinoModalPopup(context: context, builder: (_) => _EditWalletSheet(wallet: walletCtrl.currentWallet!));
                           }
                         )
                      ],
                    ),
                 ),
                 const SizedBox(height: 16),
                 _buildMenuItem(context, "Switch Wallet", CupertinoIcons.rectangle_stack_person_crop, () {
                    Navigator.pop(context);
                    _showWalletsSheet(context);
                 }),
                 Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SizedBox(height: 32, child: Center(child: Container(color: Colors.white12, height: 1, width: double.infinity)))),
               ],

               _buildMenuItem(context, "Security", CupertinoIcons.shield_fill, () {
                  Navigator.pop(context);
                  Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SecuritySettingsPage()));
               }),
               _buildMenuItem(context, "Export Wallet", CupertinoIcons.share, () {
                  Navigator.pop(context);
                  _exportWallet(context);
               }),
               _buildMenuItem(context, "GitHub", CupertinoIcons.layers_alt, () => launchUrl(Uri.parse("https://github.com/Xyntera/"))),
               _buildMenuItem(context, "Twitter / X", CupertinoIcons.at, () => launchUrl(Uri.parse("https://x.com/glaqzz"))),
               _buildMenuItem(context, "Website", CupertinoIcons.globe, () => launchUrl(Uri.parse("https://ouqro.tech"))),
               _buildMenuItem(context, "About", CupertinoIcons.info, () {
                  showCupertinoDialog(context: context, builder: (ctx) => CupertinoAlertDialog(
                    title: const Text("About Octra Wallet"),
                    content: const Text("Built by ouqro.tech\nCode by Xyntera"),
                    actions: [CupertinoDialogAction(child: const Text("Close"), onPressed: () => Navigator.pop(ctx))]
                  ));
               }),
               const SizedBox(height: 24),
             ],
           ),
         ),
       )
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
     return CupertinoButton(
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 16),
              Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
              const Spacer(),
              const Icon(CupertinoIcons.chevron_right, color: Colors.grey, size: 16),
            ],
          ),
        ),
     );
  }

  void _showWalletsSheet(BuildContext context) {
    // Re-implementation of wallets sheet
    final walletCtrl = context.read<WalletController>();
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 500,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text("Wallets", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: walletCtrl.wallets.length + 1,
                itemBuilder: (ctx, idx) {
                   if (idx == walletCtrl.wallets.length) {
                      return CupertinoButton(
                        child: const Row(children: [Icon(CupertinoIcons.add), SizedBox(width: 8), Text("Add Wallet")]),
                        onPressed: () {
                           Navigator.pop(context);
                           Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(builder: (_) => const WalletSetupPage()));
                        }
                      );
                   }
                   final w = walletCtrl.wallets[idx];
                   final isSelected = w == walletCtrl.currentWallet;
                   return CupertinoButton(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     child: Row(children: [
                       Icon(isSelected ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle, color: isSelected ? Colors.green : Colors.grey, size: 24),
                       const SizedBox(width: 16),
                       Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(w.color), shape: BoxShape.circle)),
                       const SizedBox(width: 12),
                       Expanded(child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            Text(w.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                            Text(w.address.substring(0,10)+"...", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                         ],
                       ))
                     ]),
                     onPressed: () {
                        walletCtrl.selectWallet(w);
                        Navigator.pop(context);
                     }
                   );
                },
              ),
            )
          ],
        ),
      )
    );
  }

  void _showSendSheet(BuildContext context) => _showTransactionForm(context, title: "Send Public", buttonText: "Send", isPublic: true);
  void _showEncryptSheet(BuildContext context) => _showTransactionForm(context, title: "Encrypt", buttonText: "Encrypt", isEncrypt: true);
  void _showDecryptSheet(BuildContext context) => _showTransactionForm(context, title: "Decrypt", buttonText: "Decrypt", isDecrypt: true);

  void _showReceiveSheet(BuildContext context, String address) {
     // ... (Previous implementation reused, but I should probably call the global function or keep it here?
     // It was defined inside State previously. I'll implement a simple caller to a Widget or copy logic.)
     // I'll define it locally since I replaced the class.
     showCupertinoModalPopup(
       context: context,
       builder: (context) => Container(
         height: MediaQuery.of(context).size.height * 0.85,
         decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
         child: Column(
           children: [
             const SizedBox(height: 32),
             QrImageView(data: address, size: 250, backgroundColor: Colors.white),
             const SizedBox(height: 32),
             Text(address, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
             const SizedBox(height: 16),
             CupertinoButton.filled(child: const Text("Copy"), onPressed: () {
                Clipboard.setData(ClipboardData(text: address));
                Navigator.pop(context);
             })
           ],
         ),
       )
     );
  }
}

// HELPER FOR TX ROW (Global or separate widget)
Widget _buildTransactionRow(BuildContext context, Map<String, dynamic> tx) {
  final hash = tx['hash'] ?? "";
  final direction = tx['direction'] ?? 'IN';
  final isIn = direction == 'IN';
  final amountStr = tx['amount'] ?? "0";
  double amt = double.tryParse(amountStr.toString()) ?? 0.0;
  
  return GestureDetector(
    onTap: () => _showTransactionDetails(context, tx),
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isIn ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(isIn ? CupertinoIcons.arrow_down_left : CupertinoIcons.arrow_up_right, color: isIn ? Colors.green : Colors.red, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isIn ? "Received" : "Sent", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(hash.length > 8 ? "${hash.substring(0, 8)}..." : hash, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ])),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
               Text("${isIn ? '+' : '-'}${amt.toStringAsFixed(2)} OCT", style: GoogleFonts.outfit(color: isIn ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
            ]
          )
        ],
      ),
    ),
  );
}

void _showTransactionDetails(BuildContext context, Map<String, dynamic> tx) {
  showCupertinoModalPopup(
    context: context,
    builder: (context) => _TransactionDetailsSheet(initialTx: tx),
  );
}

class _TransactionDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> initialTx;
  const _TransactionDetailsSheet({super.key, required this.initialTx});

  @override
  State<_TransactionDetailsSheet> createState() => _TransactionDetailsSheetState();
}

class _TransactionDetailsSheetState extends State<_TransactionDetailsSheet> {
  Map<String, dynamic>? fullTx;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final wallet = context.read<WalletController>();
    final hash = widget.initialTx['hash'];
    if (hash != null && hash.isNotEmpty) {
      final res = await wallet.getTransactionFullDetails(hash);
      if (mounted) {
         setState(() {
           if (res != null) fullTx = res;
           loading = false;
         });
      }
    } else {
      loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // effectiveTx is mostly for display. 
    // If fullTx exists, it wraps data in 'parsed_tx' sometimes, or top level?
    // User sample: {"parsed_tx": {...}, "status": "confirmed", "epoch": 216496 ... }
    // The list view tx is flat (from address info).
    
    final displayTx = fullTx != null ? (fullTx!['parsed_tx'] ?? fullTx!) : widget.initialTx;
    final meta = fullTx ?? widget.initialTx; // To access status, epoch outside parsed_tx

    final hash = displayTx['hash'] ?? displayTx['tx_hash'] ?? widget.initialTx['hash'] ?? "";
    final direction = widget.initialTx['direction'] ?? 'IN'; // Keep direction from list logic or re-calculate?
    // List logic used `from == myAddress`.
    // We can re-calc if we have wallet? But `widget.initialTx` has it correct.
    final isIn = direction == 'IN';
    
    // Amount
    // List view amount is string. 
    // Full API: "amount": "0.100000" (String).
    final amountStr = displayTx['amount'] ?? "0";
    double amt = double.tryParse(amountStr.toString()) ?? 0.0;
    
    final status = meta['status'] ?? "Unknown";
    final epoch = meta['epoch'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Color(0xFF1C1C1E), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            if (loading) 
               const Padding(padding: EdgeInsets.only(bottom: 16), child: CupertinoActivityIndicator()),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: isIn ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(isIn ? CupertinoIcons.arrow_down_left : CupertinoIcons.arrow_up_right, color: isIn ? Colors.green : Colors.red, size: 40),
            ),
            const SizedBox(height: 24),
            Text("${isIn ? '+' : '-'}${amt.toStringAsFixed(6)} OCT", style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: isIn ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'confirmed') const Icon(Icons.check, size: 14, color: Colors.green) else const Icon(Icons.access_time, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(status.toUpperCase(), style: TextStyle(color: status == 'confirmed' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailRow(context, "From", displayTx['from'] ?? ""),
            _buildDetailRow(context, "To", displayTx['to'] ?? displayTx['to_'] ?? ""), 
            _buildDetailRow(context, "Hash", hash),
            if (epoch != null) _buildDetailRow(context, "Epoch", epoch.toString()),
            if (displayTx['timestamp'] != null) ...[
               Builder(builder: (_) {
                 final ts = double.tryParse(displayTx['timestamp'].toString()) ?? 0;
                 if (ts > 0) {
                   final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
                   return _buildDetailRow(context, "Time", dt.toString().split('.')[0]);
                 }
                 return const SizedBox.shrink();
               })
            ],
            if (displayTx['ou'] != null) _buildDetailRow(context, "Fee", "${displayTx['ou']} OU"),
            if (displayTx['nonce'] != null) _buildDetailRow(context, "Nonce", displayTx['nonce'].toString()),
            if (displayTx['message'] != null) _buildDetailRow(context, "Message", displayTx['message'].toString()),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

Widget _buildDetailRow(BuildContext context, String label, String value) {
  if (value.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () {
               Clipboard.setData(ClipboardData(text: value));
            },
            child: Text(value.length > 20 ? "${value.substring(0,8)}...${value.substring(value.length-8)}" : value, 
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)
            ),
          )
        ),
        const SizedBox(width: 8),
        const Icon(CupertinoIcons.doc_on_doc, size: 14, color: Colors.blueGrey)
      ],
    ),
  );
}

/// PRIVATE TAB
class PrivateTab extends StatelessWidget {
  const PrivateTab({super.key});

  @override
  Widget build(BuildContext context) {
    final walletCtrl = context.watch<WalletController>();
    // walletCtrl.encryptedBalance

    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Private'),
            backgroundColor: Color(0xCC1C1C1E),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Encrypted Balance", style: TextStyle(color: CupertinoColors.systemGrey)),
                            const SizedBox(height: 4),
                            Text("${walletCtrl.encryptedBalance.toStringAsFixed(6)} OCT", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          minSize: 36,
                          child: const Text("Transfer"),
                          onPressed: () => _showTransactionForm(context, title: "Private Transfer", buttonText: "Send Private", isPrivateTransfer: true),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Pending Claims", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  if (walletCtrl.pendingPrivateTransfers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text("No pending transfers", style: GoogleFonts.outfit(color: Colors.grey)),
                    )
                  else
                    ...walletCtrl.pendingPrivateTransfers.map((tx) => _buildClaimTile(context, tx, walletCtrl)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimTile(BuildContext context, dynamic tx, WalletController wallet) {
    final id = tx['id'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
         color: const Color(0xFF2C2C2E),
         borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.gift_fill, color: CupertinoColors.systemYellow),
          const SizedBox(width: 16),
          Expanded(child: Text("Transfer #$id", style: const TextStyle(color: Colors.white))),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Text("Claim"),
            onPressed: () async {
              final ephKey = tx['ephemeral_public_key'];
              final encAmt = tx['encrypted_amount'];
              final success = await wallet.claimTransfer(id.toString(), ephKey, encAmt);
              showCupertinoDialog(context: context, builder: (ctx) => CupertinoAlertDialog(
                title: Text(success ? "Claimed!" : "Failed"),
                actions: [CupertinoDialogAction(child: const Text("OK"), onPressed: () => Navigator.pop(ctx))],
              ));
            },
          )
        ],
      ),
    );
  }
}

/// HISTORY TAB
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final walletCtrl = context.watch<WalletController>();
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('History'),
            backgroundColor: Color(0xCC1C1C1E),
          ),
          if (walletCtrl.isLoading)
             const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
          else if (walletCtrl.history.isEmpty)
             const SliverFillRemaining(child: Center(child: Text("No transactions", style: TextStyle(color: Colors.grey))))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tx = walletCtrl.history[index];
                  return _buildTransactionRow(context, tx);
                },
                childCount: walletCtrl.history.length,
              ),
            )
        ],
      ),
    );
  }
}

// SHARED DIALOGS
void _showTransactionForm(BuildContext context, {
  required String title,
  required String buttonText,
  bool isPublic = false,
  bool isEncrypt = false,
  bool isDecrypt = false,
  bool isPrivateTransfer = false,
}) {
  final addrCtrl = TextEditingController();
  final amtCtrl = TextEditingController();
  final msgCtrl = TextEditingController();
  
  showCupertinoModalPopup(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        bool isSending = false; // logic internal var, but need to lift state up? 
        // No, StatefulWidget builder state is persistent for rebuild? 
        // Actually, internal var in build method resets. 
        // I need to use a variable outside or State.
        // StatefulBuilder preserves state if I use the setState passed to it.
        // But the variable `isSending` must be defined outside the builder?
        // No, StatefuleBuilder just calls the builder. I need to closure a variable?
        // Ah, `StatefulBuilder` maintains its own `State` which calls `builder`. 
        // But where do I store the boolean? 
        // I can just use a local variable `bool _loading = false;` inside the function `_showTransactionForm`?
        // No, the function returns immediately.
        // I'll define `_loading` inside the closure of `builder` if I can? 
        // No, `builder` runs on every rebuild.
        // Correct pattern: Move `bool _loading = false` to just above `StatefulBuilder`, but inside `builder`? No.
        // `StatefulBuilder` doesn't hold state for us, it just gives us a `setState`.
        // Wait, `StatefulBuilder` DOES NOT hold custom fields.
        // I need to wrap it in a custom Widget or use a variable *outside* the builder but inside the function scope?
        // But if function scope exits? The Dialog widget stays mounted.
        // Yes, variable in function scope is captured by the closure.
        return _TransactionFormContent(
           title: title, 
           buttonText: buttonText, 
           isPublic: isPublic, 
           isEncrypt: isEncrypt, 
           isDecrypt: isDecrypt, 
           isPrivateTransfer: isPrivateTransfer
        );
      }
    ),
  );
}

class _TransactionFormContent extends StatefulWidget {
  final String title;
  final String buttonText;
  final bool isPublic;
  final bool isEncrypt;
  final bool isDecrypt;
  final bool isPrivateTransfer;

  const _TransactionFormContent({
    required this.title, 
    required this.buttonText, 
    required this.isPublic, 
    required this.isEncrypt, 
    required this.isDecrypt, 
    required this.isPrivateTransfer
  });

  @override
  State<_TransactionFormContent> createState() => _TransactionFormContentState();
}

class _TransactionFormContentState extends State<_TransactionFormContent> {
  final addrCtrl = TextEditingController();
  final amtCtrl = TextEditingController();
  final msgCtrl = TextEditingController();
  bool isSending = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (widget.isPublic || widget.isPrivateTransfer) ...[
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: addrCtrl,
                    placeholder: "Recipient Address",
                    style: const TextStyle(color: Colors.white),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (widget.isPublic)
                  CupertinoButton(
                    child: const Icon(CupertinoIcons.qrcode_viewfinder),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context, 
                        CupertinoPageRoute(builder: (_) => const ScannerPage())
                      );
                      if (result != null) {
                        addrCtrl.text = result;
                      }
                    },
                  )
              ],
            ),
            const SizedBox(height: 16),
          ],
          CupertinoTextField(
            controller: amtCtrl,
            placeholder: "Amount (OCT)",
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
             padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
          ),
          if (widget.isPublic) ...[
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: msgCtrl,
              placeholder: "Message (Optional)",
              style: const TextStyle(color: Colors.white),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: isSending ? null : () async {
                setState(() => isSending = true);
                final wallet = context.read<WalletController>();
                final amt = double.tryParse(amtCtrl.text) ?? 0.0;
                
                RpcResponse? res;
                try {
                  if (widget.isPublic) {
                     res = await wallet.sendTransaction(addrCtrl.text, amt, msgCtrl.text);
                  } else if (widget.isEncrypt) {
                     res = await wallet.encryptMoney(amt);
                  } else if (widget.isDecrypt) {
                     res = await wallet.decryptMoney(amt);
                  } else if (widget.isPrivateTransfer) {
                     res = await wallet.makePrivateTransfer(addrCtrl.text, amt);
                  }
                } catch(e) {
                   res = RpcResponse(0, "Failed: $e", null);
                }
                
                if (mounted) {
                   setState(() => isSending = false);
                   Navigator.pop(context); // Close form
                   
                   if (res != null && res.statusCode == 200) {
                      if (widget.isPublic) {
                        Navigator.of(context).push(PageRouteBuilder(
                          opaque: false,
                          pageBuilder: (_, __, ___) => SuccessAnimation(
                            onComplete: () => Navigator.pop(context),
                          )
                        ));
                      } else {
                        showCupertinoDialog(context: context, builder: (ctx) => CupertinoAlertDialog(
                           title: const Text("Success"),
                           content: Text(res?.text ?? ""),
                           actions: [CupertinoDialogAction(child: const Text("OK"), onPressed: () => Navigator.pop(ctx))],
                        ));
                      }
                   } else {
                      showCupertinoDialog(context: context, builder: (ctx) => CupertinoAlertDialog(
                         title: const Text("Error"),
                         content: Text(res?.text ?? "Unknown error"),
                         actions: [CupertinoDialogAction(child: const Text("OK"), onPressed: () => Navigator.pop(ctx))],
                      ));
                   }
                }
              },
              child: isSending 
                  ? const CupertinoActivityIndicator(color: Colors.white) 
                  : Text(widget.buttonText),
            ),
          )
        ],
      ),
    );
  }
}

// EXPORT WALLET LOGIC
Future<void> _exportWallet(BuildContext context) async {
  final wallet = context.read<WalletController>();
  // 1. Security Check
  if (await wallet.isSecurityEnabled) {
     final bool? success = await Navigator.of(context).push(
       CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const PinScreen(isChecking: true))
     );
     // Fixed PinScreen returns true on success
     if (success != true) return;
  }
  
  // 2. Show Data
  final w = wallet.currentWallet;
  if (w == null) return;
  
  showCupertinoModalPopup(context: context, builder: (ctx) => _ExportSheet(wallet: w));
}

class _ExportSheet extends StatefulWidget {
  final Wallet wallet;
  const _ExportSheet({super.key, required this.wallet});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
             const SizedBox(height: 24),
             Text("Export Wallet", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
             const SizedBox(height: 8),
             Text("Warning: Never share your secret phrase or private key with anyone.", style: GoogleFonts.outfit(color: CupertinoColors.destructiveRed, fontSize: 13)),
             const SizedBox(height: 24),
             
             if (!_revealed)
                Center(
                  child: CupertinoButton.filled(
                    child: const Text("Reveal Secrets"),
                    onPressed: () => setState(() => _revealed = true),
                  ),
                )
             else ...[
                _buildSecretField("Secret Phrase", widget.wallet.mnemonic ?? "Not available (Imported via Key)"),
                const SizedBox(height: 16),
                _buildSecretField("Private Key", widget.wallet.privateKeyBase64),
             ],
             const SizedBox(height: 24),
             SizedBox(width: double.infinity, child: CupertinoButton(child: const Text("Close"), onPressed: () => Navigator.pop(context)))
          ],
        ),
      ),
    );
  }

  Widget _buildSecretField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
          child: SelectableText(value, style: GoogleFonts.sourceCodePro(color: Colors.white, fontSize: 13)),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            child: const Text("Copy", style: TextStyle(fontSize: 12)),
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
          ),
        )
      ],
    );
  }
}

class _EditWalletSheet extends StatefulWidget {
  final Wallet wallet;
  const _EditWalletSheet({super.key, required this.wallet});

  @override
  State<_EditWalletSheet> createState() => _EditWalletSheetState();
}

class _EditWalletSheetState extends State<_EditWalletSheet> {
  late TextEditingController _nameCtrl;
  late int _selectedColor;

  final List<int> _colors = [0xFF357AF6, 0xFF32D74B, 0xFFFF9F0A, 0xFFFF375F, 0xFFBF5AF2, 0xFFFFD60A, 0xFF64D2FF, 0xFF8E8E93, 0xFF007AFF, 0xFF5856D6, 0xFFFF2D55, 0xFFAF52DE];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.wallet.name);
    _selectedColor = widget.wallet.color;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
             const SizedBox(height: 24),
             Text("Edit Wallet", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
             const SizedBox(height: 24),
             
             Text("Wallet Name", style: const TextStyle(color: Colors.grey, fontSize: 13)),
             const SizedBox(height: 8),
             CupertinoTextField(
               controller: _nameCtrl,
               style: const TextStyle(color: Colors.white),
               decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
               padding: const EdgeInsets.all(12),
             ),
             
             const SizedBox(height: 24),
             Text("Wallet Color", style: const TextStyle(color: Colors.grey, fontSize: 13)),
             const SizedBox(height: 12),
             Wrap(
               spacing: 12, runSpacing: 12,
               children: _colors.map((c) => GestureDetector(
                 onTap: () => setState(() => _selectedColor = c),
                 child: Container(
                   width: 32, height: 32,
                   decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: _selectedColor == c ? Border.all(color: Colors.white, width: 3) : null),
                 ),
               )).toList(),
             ),
             
             const SizedBox(height: 32),
             SizedBox(width: double.infinity, child: CupertinoButton.filled(
               child: const Text("Save Changes"), 
               onPressed: () {
                 context.read<WalletController>().updateWallet(widget.wallet.address, name: _nameCtrl.text, color: _selectedColor);
                 Navigator.pop(context);
               }
             )),
             const SizedBox(height: 16),
             SizedBox(width: double.infinity, child: CupertinoButton(
               child: const Text("Delete Wallet", style: TextStyle(color: CupertinoColors.destructiveRed)), 
               onPressed: () {
                  showCupertinoDialog(context: context, builder: (ctx) => CupertinoAlertDialog(
                    title: const Text("Delete Wallet?"),
                    content: const Text("Are you sure? This action cannot be undone unless you have your secret phrase."),
                    actions: [
                      CupertinoDialogAction(child: const Text("Cancel"), onPressed: () => Navigator.pop(ctx)),
                      CupertinoDialogAction(child: const Text("Delete", style: TextStyle(color: CupertinoColors.destructiveRed)), onPressed: () {
                         context.read<WalletController>().deleteWallet(widget.wallet.address);
                         Navigator.pop(ctx); 
                         Navigator.pop(context); 
                      }),
                    ]
                  ));
               }
             )),
             const SizedBox(height: 24), // Extra bottom padding
          ],
        ),
      ),
    );
  }
}
