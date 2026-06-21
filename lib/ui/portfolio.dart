import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, LinearGradient, Alignment, BoxDecoration, BorderRadius;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../wallet.dart';
import '../eth/eth_wallet_store.dart';
import 'bridge.dart';

class PortfolioTab extends StatefulWidget {
  const PortfolioTab({super.key});

  @override
  State<PortfolioTab> createState() => _PortfolioTabState();
}

class _PortfolioTabState extends State<PortfolioTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<WalletController>();
      ctrl.fetchPriceData();
      ctrl.fetchAllWalletBalances();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<WalletController>();

    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle:
                Text('Portfolio', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: const Color(0xCC1C1C1E),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                final c = context.read<WalletController>();
                c.invalidatePriceCache();
                c.fetchPriceData();
                c.fetchAllWalletBalances();
              },
              child: ctrl.isPriceFetching
                  ? const CupertinoActivityIndicator()
                  : const Icon(CupertinoIcons.refresh,
                      color: CupertinoColors.systemBlue),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TotalValueCard(ctrl: ctrl),
                  const SizedBox(height: 20),
                  _PriceChartCard(ctrl: ctrl),
                  const SizedBox(height: 20),
                  _WalletBreakdownList(ctrl: ctrl),
                  const SizedBox(height: 20),
                  const _EvmPortfolioSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Total value card ─────────────────────────────────────────────────────────

class _TotalValueCard extends StatelessWidget {
  final WalletController ctrl;
  const _TotalValueCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final usd = ctrl.totalPortfolioUsd;
    final oct = ctrl.totalPortfolioOct;
    final change = ctrl.priceChange24h;
    final up = change >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0A84FF).withValues(alpha: 0.25), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0A84FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Value',
              style: GoogleFonts.outfit(
                  color: CupertinoColors.systemGrey, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            ctrl.octPrice == 0.0 ? '—' : '\$${_fmtUsd(usd)}',
            style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmtOct(oct)} OCT',
            style: GoogleFonts.outfit(
                color: CupertinoColors.systemGrey, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: up
                      ? CupertinoColors.activeGreen.withValues(alpha: 0.15)
                      : CupertinoColors.destructiveRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      up ? CupertinoIcons.arrow_up_right : CupertinoIcons.arrow_down_right,
                      color: up
                          ? CupertinoColors.activeGreen
                          : CupertinoColors.destructiveRed,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${change.abs().toStringAsFixed(2)}%',
                      style: GoogleFonts.outfit(
                        color: up
                            ? CupertinoColors.activeGreen
                            : CupertinoColors.destructiveRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '24h • \$${ctrl.octPrice == 0.0 ? '—' : _fmtPrice(ctrl.octPrice)} per OCT',
                style: GoogleFonts.outfit(
                    color: CupertinoColors.systemGrey, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 7-day price chart ────────────────────────────────────────────────────────

class _PriceChartCard extends StatefulWidget {
  final WalletController ctrl;
  const _PriceChartCard({required this.ctrl});

  @override
  State<_PriceChartCard> createState() => _PriceChartCardState();
}

class _PriceChartCardState extends State<_PriceChartCard> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final history = widget.ctrl.priceHistory;
    final loading = widget.ctrl.isPriceFetching;
    final hasData = history.length >= 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('OCT / USD — 7 Days',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              if (_touchedIndex != null && _touchedIndex! < history.length)
                Text(
                  '\$${_fmtPrice(history[_touchedIndex!][1])}',
                  style: GoogleFonts.outfit(
                      color: const Color(0xFF0A84FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: loading && !hasData
                ? const Center(child: CupertinoActivityIndicator())
                : !hasData
                    ? Center(
                        child: Text('No price data',
                            style: GoogleFonts.outfit(
                                color: CupertinoColors.systemGrey)))
                    : _buildChart(history),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<List<double>> history) {
    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i][1]));
    }
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.15;

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (history.length / 7).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= history.length) return const SizedBox();
                final ts = DateTime.fromMillisecondsSinceEpoch(
                    history[idx][0].toInt());
                return Text(
                  '${ts.month}/${ts.day}',
                  style: GoogleFonts.outfit(
                      color: CupertinoColors.systemGrey, fontSize: 10),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            setState(() {
              _touchedIndex =
                  response?.lineBarSpots?.firstOrNull?.spotIndex;
            });
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF2C2C2E),
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '\$${_fmtPrice(s.y)}',
                      GoogleFonts.outfit(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: const Color(0xFF0A84FF),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0A84FF).withValues(alpha: 0.3),
                  const Color(0xFF0A84FF).withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Per-wallet breakdown ──────────────────────────────────────────────────────

class _WalletBreakdownList extends StatelessWidget {
  final WalletController ctrl;
  const _WalletBreakdownList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    if (ctrl.wallets.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wallets',
            style: GoogleFonts.outfit(
                color: CupertinoColors.systemGrey, fontSize: 14)),
        const SizedBox(height: 12),
        ...ctrl.wallets.map((w) {
          final oct = ctrl.walletPublicBalances[w.address] ??
              (ctrl.currentWallet?.address == w.address
                  ? ctrl.publicBalance
                  : null);
          final usd =
              (oct != null && ctrl.octPrice > 0) ? oct * ctrl.octPrice : null;
          final isActive = ctrl.currentWallet?.address == w.address;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(14),
              border: isActive
                  ? Border.all(
                      color: const Color(0xFF0A84FF).withValues(alpha: 0.4))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(w.color).withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      w.name.isNotEmpty ? w.name[0].toUpperCase() : 'W',
                      style: GoogleFonts.outfit(
                          color: Color(w.color),
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.name,
                          style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
                      Text(
                        '${w.address.substring(0, 8)}…${w.address.substring(w.address.length - 6)}',
                        style: const TextStyle(
                            color: CupertinoColors.systemGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      usd != null ? '\$${_fmtUsd(usd)}' : '—',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      oct != null ? '${_fmtOct(oct)} OCT' : '…',
                      style: GoogleFonts.outfit(
                          color: CupertinoColors.systemGrey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── EVM Portfolio section ────────────────────────────────────────────────────

class _EvmPortfolioSection extends StatelessWidget {
  const _EvmPortfolioSection();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EthWalletStore>();
    final acc = store.account;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('EVM Wallet',
                style: GoogleFonts.outfit(color: CupertinoColors.systemGrey, fontSize: 14)),
            const Spacer(),
            if (acc != null)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await store.refreshBalances();
                },
                child: store.isRefreshingBalances
                    ? const CupertinoActivityIndicator(radius: 8)
                    : const Icon(CupertinoIcons.refresh, size: 16, color: CupertinoColors.systemBlue),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => const BridgeScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0A84FF).withValues(alpha: acc != null ? 0.3 : 0.1)),
            ),
            child: acc == null
                ? Row(
                    children: [
                      const Icon(CupertinoIcons.link_circle_fill, color: Color(0xFF0A84FF), size: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No EVM wallet', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                            Text('Tap to set up for bridging', style: GoogleFonts.outfit(color: CupertinoColors.systemGrey, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_right, color: Color(0xFF48484A), size: 16),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.link_circle_fill, color: Color(0xFF0A84FF), size: 32),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ethereum', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                                Text(
                                  '${acc.address.substring(0, 8)}…${acc.address.substring(acc.address.length - 6)}',
                                  style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          const Icon(CupertinoIcons.chevron_right, color: Color(0xFF48484A), size: 16),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ETH', style: GoogleFonts.outfit(color: CupertinoColors.systemGrey, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(
                                    store.isRefreshingBalances ? '…' : (store.ethBalanceWei.toDouble() / 1e18).toStringAsFixed(5),
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('wOCT', style: GoogleFonts.outfit(color: CupertinoColors.systemGrey, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(
                                    store.isRefreshingBalances ? '…' : (store.woctBalanceRaw.toDouble() / 1e6).toStringAsFixed(4),
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Formatters ───────────────────────────────────────────────────────────────

String _fmtUsd(double v) {
  if (v >= 1000) {
    return v.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},');
  }
  return v.toStringAsFixed(2);
}

String _fmtPrice(double v) {
  if (v >= 1) return v.toStringAsFixed(4);
  if (v >= 0.001) return v.toStringAsFixed(6);
  return v.toStringAsFixed(8);
}

String _fmtOct(double v) {
  return v.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
}
