import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../wallet.dart';
import 'home.dart';
import 'success_animation.dart';

class WalletSetupPage extends StatefulWidget {
  const WalletSetupPage({super.key});

  @override
  State<WalletSetupPage> createState() => _WalletSetupPageState();
}

class _WalletSetupPageState extends State<WalletSetupPage> {
  final TextEditingController _importController = TextEditingController();
  bool _isImporting = false;
  bool _isLoading = false;
  Map<String, String>? _generatedData;

  @override
  Widget build(BuildContext context) {
    // If we have generated data, show the backup screen
    if (_generatedData != null) {
      return _buildBackupScreen(context);
    }

    return CupertinoPageScaffold(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1C1E), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(
                  CupertinoIcons.circle_grid_hex,
                  size: 80,
                  color: CupertinoColors.systemBlue,
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).shimmer(delay: 1000.ms, duration: 1500.ms),
                const SizedBox(height: 24),
                Text(
                  'Octra Wallet',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                ).animate().fadeIn().moveY(begin: 10, end: 0).shimmer(delay: 1200.ms, color: const Color(0x3DFFFFFF)),
                const SizedBox(height: 8),
                Text(
                  'Secure, Private, Fast.',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                const Spacer(),
                
                if (_isImporting) ...[
                  CupertinoTextField(
                    controller: _importController,
                    placeholder: 'Seed Phrase or Private Key',
                    maxLines: 3,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    style: const TextStyle(color: CupertinoColors.white),
                  ).animate().fadeIn(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          child: const Text('Cancel'),
                          onPressed: () => setState(() => _isImporting = false),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CupertinoButton.filled(
                          onPressed: _isLoading ? null : () async {
                            setState(() => _isLoading = true);
                            await Future.delayed(300.ms); 
                            final wallet = context.read<WalletController>();
                            final data = await wallet.processInput(_importController.text);
                            
                            if (data != null) {
                               await wallet.addWallet(data['address']!, data['privateKeyBase64']!, data['mnemonic']);
                               
                               if (!mounted) return;
                               // Success Animation
                               await Navigator.of(context).push(PageRouteBuilder(
                                  opaque: false, 
                                  pageBuilder: (_,__,___) => SuccessAnimation(onComplete: () => Navigator.pop(context))
                               ));
                               
                               if (!mounted) return;
                               if (Navigator.canPop(context)) {
                                 Navigator.pop(context);
                               } else {
                                 Navigator.of(context).pushReplacement(
                                   CupertinoPageRoute(builder: (_) => const HomeTabScaffold())
                                 );
                               }
                            } else {
                               setState(() => _isLoading = false);
                               showCupertinoDialog(context: context, builder: (ctx) => CupertinoAlertDialog(
                                 title: const Text("Invalid Input"),
                                 content: const Text("Could not import wallet. Check your seed or key."),
                                 actions: [CupertinoDialogAction(child: const Text("OK"), onPressed: () => Navigator.pop(ctx))],
                               ));
                            }
                          },
                          child: _isLoading ? const CupertinoActivityIndicator(color: CupertinoColors.white) : const Text('Import'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _isLoading ? null : () async {
                        setState(() => _isLoading = true);
                        await Future.delayed(600.ms); 
                        final data = await context.read<WalletController>().generateNewWalletData();
                        setState(() {
                          _isLoading = false;
                          _generatedData = data;
                        });
                      },
                      child: _isLoading ? const CupertinoActivityIndicator(color: CupertinoColors.white) : const Text('Create New Wallet'),
                    ),
                  ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      child: const Text('I have a wallet'),
                      onPressed: () => setState(() => _isImporting = true),
                    ),
                  ).animate().fadeIn(delay: 500.ms).moveY(begin: 20, end: 0),
                ],
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    "Made by ouqro.tech",
                    style: GoogleFonts.outfit(
                      color: CupertinoColors.systemGrey2, 
                      fontSize: 12, 
                      letterSpacing: 1.2
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackupScreen(BuildContext context) {
    final mnemonic = _generatedData!['mnemonic']!;
    final privKey = _generatedData!['privateKeyBase64']!;
    final address = _generatedData!['address']!;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xCC1C1C1E),
        middle: Text('Backup Wallet', style: GoogleFonts.outfit(color: CupertinoColors.white)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               _buildWarningBox(),
               const SizedBox(height: 24),
               Text("Secret Phrase", style: GoogleFonts.outfit(color: CupertinoColors.systemGrey, fontSize: 14)),
               const SizedBox(height: 8),
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: const Color(0xFF1C1C1E),
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: CupertinoColors.systemGrey.withOpacity(0.2)),
                 ),
                 child: Text(mnemonic, style: GoogleFonts.sourceCodePro(color: CupertinoColors.white, fontSize: 16, height: 1.5)),
               ),
               const SizedBox(height: 8),
               CupertinoButton(
                 padding: EdgeInsets.zero,
                 child: const Row(children: [Icon(CupertinoIcons.doc_on_doc), SizedBox(width: 8), Text("Copy Phrase")]),
                 onPressed: () {
                   Clipboard.setData(ClipboardData(text: mnemonic));
                 },
               ),
               
               const SizedBox(height: 24),
               Text("Private Key", style: GoogleFonts.outfit(color: CupertinoColors.systemGrey, fontSize: 14)),
               const SizedBox(height: 8),
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: const Color(0xFF1C1C1E),
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: CupertinoColors.systemGrey.withOpacity(0.2)),
                 ),
                 child: Text(privKey, style: GoogleFonts.sourceCodePro(color: CupertinoColors.white, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
               ),
               const SizedBox(height: 8),
               CupertinoButton(
                 padding: EdgeInsets.zero,
                 child: const Row(children: [Icon(CupertinoIcons.doc_on_doc), SizedBox(width: 8), Text("Copy Private Key")]),
                 onPressed: () {
                   Clipboard.setData(ClipboardData(text: privKey));
                 },
               ),
               
               const SizedBox(height: 40),
               SizedBox(
                 width: double.infinity,
                 child: CupertinoButton.filled(
                    onPressed: _isLoading ? null : () async {
                       setState(() => _isLoading = true);
                       await Future.delayed(500.ms);
                       await context.read<WalletController>().addWallet(address, privKey, mnemonic);
                       
                       if (!mounted) return;
                       await Navigator.of(context).push(PageRouteBuilder(
                          opaque: false, 
                          pageBuilder: (_,__,___) => SuccessAnimation(onComplete: () => Navigator.pop(context))
                       ));

                       if (!mounted) return;
                       if (Navigator.canPop(context)) {
                         Navigator.pop(context);
                       } else {
                         Navigator.of(context).pushReplacement(
                           CupertinoPageRoute(builder: (_) => const HomeTabScaffold())
                         );
                       }
                    },
                    child: _isLoading ? const CupertinoActivityIndicator(color: CupertinoColors.white) : const Text("I have saved it"),
                 ),
               ),
               Center(
                 child: CupertinoButton(
                   child: const Text("Back"),
                   onPressed: () => setState(() => _generatedData = null),
                 ),
               )
             ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.destructiveRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.destructiveRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: CupertinoColors.destructiveRed),
          const SizedBox(width: 16),
          Expanded(child: Text("Your secret phrase is the only way to recover your funds. Write it down and keep it safe.", style: GoogleFonts.outfit(color: CupertinoColors.destructiveRed)))
        ],
      ),
    );
  }
}
