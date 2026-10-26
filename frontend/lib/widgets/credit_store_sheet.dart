import 'package:flutter/material.dart';
import '../api.dart';
import 'vip_subscription_sheet.dart';

class CreditStoreSheet extends StatefulWidget {
  final VoidCallback? onCreditsUpdated;

  const CreditStoreSheet({
    super.key,
    this.onCreditsUpdated,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onCreditsUpdated}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreditStoreSheet(onCreditsUpdated: onCreditsUpdated),
    );
  }

  @override
  State<CreditStoreSheet> createState() => _CreditStoreSheetState();
}

class _CreditStoreSheetState extends State<CreditStoreSheet> {
  bool _isLoading = true;
  bool _isPurchasing = false;
  int _currentCredits = 0;
  int _freeExports = 1;
  List<Map<String, dynamic>> _packs = [];

  final List<Map<String, dynamic>> _fallbackPacks = [
    {
      'pack_id': 'PACK_STARTER',
      'name': 'Starter Pack',
      'credits': 25,
      'price_inr': '₹189',
      'price_usd': '\$1.99',
      'popular': false,
      'badge': null,
      'description': '2-3 Standard exports (or 5 VIP exports)',
    },
    {
      'pack_id': 'PACK_POPULAR',
      'name': 'Popular Pack',
      'credits': 60,
      'price_inr': '₹379',
      'price_usd': '\$3.99',
      'popular': true,
      'badge': 'BEST VALUE 🔥',
      'description': '6 Standard exports (or 12 VIP exports)',
    },
    {
      'pack_id': 'PACK_COLLECTOR',
      'name': 'Collector Pack',
      'credits': 150,
      'price_inr': '₹759',
      'price_usd': '\$7.99',
      'popular': false,
      'badge': 'MAX SAVINGS 👑',
      'description': '15 Standard exports (or 30 VIP exports)',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchCreditInfo();
  }

  Future<void> _fetchCreditInfo() async {
    try {
      final data = await ApiService.getCreditPacks();
      if (mounted) {
        setState(() {
          _packs = List<Map<String, dynamic>>.from(data['packs'] ?? _fallbackPacks);
          _currentCredits = data['current_credits'] ?? 0;
          _freeExports = data['free_exports_remaining'] ?? 1;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _packs = _fallbackPacks;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _buyPack(Map<String, dynamic> pack) async {
    setState(() => _isPurchasing = true);
    try {
      final res = await ApiService.buyCredits(pack['pack_id']);
      if (!mounted) return;
      setState(() {
        _isPurchasing = false;
        _currentCredits = res['total_credits'] ?? (_currentCredits + (pack['credits'] as int));
      });
      widget.onCreditsUpdated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green[800],
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res['message'] ?? 'Successfully added ${pack['credits']} credits!',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[800],
            content: Text('Failed to purchase credits: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final packList = _packs.isNotEmpty ? _packs : _fallbackPacks;

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 28, left: 20, right: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF161426),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.12),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, -6),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.amber, Colors.orangeAccent]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 10)
                      ],
                    ),
                    child: const Icon(Icons.toll_rounded, color: Colors.black, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credit Wallet',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Unlock PDF & EPUB story exports',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
              // Current Balance Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.toll, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$_currentCredits',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Free trial or VIP notice
          if (_freeExports > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.withOpacity(0.25), Colors.pinkAccent.withOpacity(0.2)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.pinkAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You have 1 FREE Lifetime Export available!\nTop up credits for subsequent story exports.',
                      style: TextStyle(color: Colors.pink[100], fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36.0),
              child: CircularProgressIndicator(color: Colors.amber),
            )
          else ...[
            // Pack list
            ...packList.map((pack) {
              final isPopular = pack['popular'] == true;
              final badge = pack['badge'];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isPopular ? const Color(0xFF26203B) : const Color(0xFF1E1C2C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPopular ? Colors.amber : Colors.white12,
                    width: isPopular ? 1.8 : 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isPurchasing ? null : () => _buyPack(pack),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isPopular ? Colors.amber.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.auto_stories,
                              color: isPopular ? Colors.amber : Colors.cyanAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${pack['credits']} Credits',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (badge != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          badge.toString(),
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pack['description'] ?? '',
                                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isPopular
                                  ? const LinearGradient(colors: [Colors.amber, Colors.orangeAccent])
                                  : LinearGradient(colors: [Colors.white24, Colors.white12]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              pack['price_usd'] ?? '',
                              style: TextStyle(
                                color: isPopular ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // VIP Upsell Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.purpleAccent, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Want 50% OFF all exports?',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                        Text(
                          'Active VIP members only pay 5 credits per export instead of 10!',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      VipSubscriptionSheet.show(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.purpleAccent,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    child: const Text('View VIP'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
