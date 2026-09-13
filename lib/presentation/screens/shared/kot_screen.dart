import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:coffee_katta_pos/services/kot_service.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';
import 'package:coffee_katta_pos/core/app_theme.dart';
import '../../widgets/global/profile_menu.dart';
import 'package:coffee_katta_pos/presentation/providers/active_branch_provider.dart';
import '../../widgets/global/editorial_background.dart';
import '../../widgets/global/coffee_katta_brand_badge.dart';

final kotServiceProvider = Provider<KOTService>((ref) {
  final branchId = ref.watch(activeBranchIdProvider);
  if (branchId == null) throw Exception('No active branch selected');
  return KOTService(branchId: branchId);
});

final liveKOTsProvider = StreamProvider<List<KOTModel>>((ref) {
  return ref.watch(kotServiceProvider).watchLiveKOTs();
});

class KOTScreen extends ConsumerWidget {
  const KOTScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveKOTs = ref.watch(liveKOTsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF382012),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                  ] else ...[
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                        tooltip: 'Menu',
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  const Expanded(
                    child: CoffeeKattaBrandBadge(),
                  ),
                  if (MediaQuery.of(context).size.width >= 600) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.soup_kitchen_rounded, color: AppTheme.warmAmber, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'KITCHEN KOTs',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const ProfileMenu(isDarkHeader: true),
                ],
              ),
            ),
          ),
        ),
      ),
      body: EditorialBackground(
        child: liveKOTs.when(
          data: (kots) {
            if (kots.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu, size: 80, color: AppTheme.maroon),
                    SizedBox(height: 16),
                    Text('Kitchen is Quiet', 
                      style: TextStyle(fontSize: 22, color: AppTheme.maroon, fontWeight: FontWeight.bold)),
                    Text('No active KOTs to display', 
                      style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 450,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                mainAxisExtent: 480,
              ),
              itemCount: kots.length,
              itemBuilder: (context, index) {
                return _KOTCard(kot: kots[index]);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.maroon)),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _KOTCard extends ConsumerStatefulWidget {
  final KOTModel kot;
  const _KOTCard({required this.kot});

  @override
  ConsumerState<_KOTCard> createState() => _KOTCardState();
}

class _KOTCardState extends ConsumerState<_KOTCard> {
  late Timer _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.kot.createdAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.kot.createdAt);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Color _getTimerColor() {
    if (_elapsed.inMinutes < 5) return Colors.green;
    if (_elapsed.inMinutes < 10) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 0) return "0m";
    if (d.inHours > 0) {
      return "${d.inHours}h ${d.inMinutes % 60}m";
    }
    return "${d.inMinutes}m";
  }

  @override
  Widget build(BuildContext context) {
    final isFullyServed = widget.kot.items.every((i) => i.status == 'served');
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.maroon.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.espressoBrown, Color(0xFF2E1A09)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.kot.tableName.toUpperCase(), 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      Text('KOT #${widget.kot.kotNumber}', 
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, letterSpacing: 1.1)),
                    ],
                  ),
                ),
                const SizedBox(width: 16), // Increased space between table name and timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getTimerColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _getTimerColor().withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: _getTimerColor()),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_elapsed), 
                        style: TextStyle(color: _getTimerColor(), fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: widget.kot.items.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final item = widget.kot.items[idx];
                final isServed = item.status == 'served';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isServed ? Colors.grey.shade100 : AppTheme.maroon.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${item.qty}x', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: isServed ? Colors.grey : AppTheme.maroon,
                        )),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: isServed ? TextDecoration.lineThrough : null,
                            color: isServed ? Colors.grey : Colors.black87,
                          )),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isServed ? Colors.grey.shade100 : AppTheme.maroon.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(item.category.toUpperCase(), 
                            style: TextStyle(
                              color: isServed ? Colors.grey : AppTheme.maroon.withOpacity(0.6), 
                              fontSize: 9, 
                              fontWeight: FontWeight.w900, 
                              letterSpacing: 0.5
                            )),
                        ),
                      ],
                    ),
                    subtitle: item.note.isNotEmpty 
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(item.note, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                        )
                      : null,
                    trailing: isServed 
                      ? const Icon(Icons.check_circle, color: AppTheme.successGreen)
                      : TextButton(
                          onPressed: () {
                            ref.read(kotServiceProvider).updateItemStatus(
                              kotId: widget.kot.kotId,
                              itemUniqueId: item.uniqueId,
                              status: 'served',
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.successGreen,
                            backgroundColor: AppTheme.successGreen.withOpacity(0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('SERVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                  ),
                );
              },
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(widget.kot.userName, 
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
                if (isFullyServed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('COMPLETED', 
                      style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.w900, fontSize: 10)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
