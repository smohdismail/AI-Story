import 'package:flutter/material.dart';
import '../api.dart';

class VipSubscriptionSheet extends StatefulWidget {
  final Map<String, dynamic>? currentQuota;
  final VoidCallback? onUpgraded;

  const VipSubscriptionSheet({
    super.key,
    this.currentQuota,
    this.onUpgraded,
  });

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? currentQuota,
    VoidCallback? onUpgraded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VipSubscriptionSheet(
        currentQuota: currentQuota,
        onUpgraded: onUpgraded,
      ),
    );
  }

  @override
  State<VipSubscriptionSheet> createState() => _VipSubscriptionSheetState();
}

class _VipSubscriptionSheetState extends State<VipSubscriptionSheet> {
  String _selectedPlanId = 'VIP_MONTHLY';
  bool _isLoading = false;
  Map<String, dynamic>? _plansData;

  final List<Map<String, dynamic>> _fallbackPlans = [
    {
      'plan_id': 'VIP_WEEKLY',
      'name': 'Weekly Pass',
      'price_inr': '₹189',
      'price_usd': '\$1.99',
      'period': '/ week',
      'badge': null,
      'is_popular': false,
    },
    {
      'plan_id': 'VIP_MONTHLY',
      'name': 'Monthly VIP',
      'price_inr': '₹665',
      'price_usd': '\$6.99',
      'period': '/ month',
      'badge': 'MOST POPULAR ⭐',
      'is_popular': true,
    },
    {
      'plan_id': 'VIP_YEARLY',
      'name': 'Annual VIP',
      'price_inr': '₹4,279',
      'price_usd': '\$44.99',
      'period': '/ year',
      'badge': 'SAVE 45% 👑',
      'is_popular': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    try {
      final data = await ApiService.getSubscriptionPlans();
      if (mounted) {
        setState(() => _plansData = data);
      }
    } catch (_) {}
  }

  Future<void> _subscribe() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.upgradeSubscription(_selectedPlanId);
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.stars, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res['message'] ?? 'VIP Access Activated! Enjoy unlimited romance.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF831843),
          duration: const Duration(seconds: 4),
        ),
      );

      if (widget.onUpgraded != null) {
        widget.onUpgraded!();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subscription failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quota = widget.currentQuota;
    final remaining = quota?['daily_chats_remaining'] ?? 0;
    final isExhausted = remaining <= 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF140D1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x66FF2D55),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // Top Header with Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2D55), Color(0xFFFF9500)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.diamond, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'VIP PASS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Emotional Hero Title
                const Text(
                  'Unlock Her Heart\nWithout Limits 💖',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Break through the 20-message wall. Enjoy intimate spoken whispers, secret diaries, and 24/7 unfiltered connection.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),

                // Quota Exhausted Callout
                if (isExhausted) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_clock, color: Colors.amber, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Daily 20 free messages used up! Resets at midnight UTC, or upgrade to VIP now to keep chatting instantly.",
                            style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Plan Cards
                const Text(
                  'SELECT YOUR PLAN',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                ..._fallbackPlans.map((plan) {
                  final planId = plan['plan_id'] as String;
                  final isSelected = _selectedPlanId == planId;
                  final isPopular = plan['is_popular'] == true;
                  final badge = plan['badge'] as String?;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedPlanId = planId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  const Color(0xFF831843).withValues(alpha: 0.8),
                                  const Color(0xFF4C1D95).withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.04),
                                  Colors.white.withValues(alpha: 0.02),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF2D55)
                              : Colors.white.withValues(alpha: 0.1),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF2D55).withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isSelected ? const Color(0xFFFF2D55) : Colors.white38,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      plan['name'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (badge != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPopular ? const Color(0xFFFF2D55) : Colors.amber,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          badge,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isPopular
                                      ? 'Full unlimited romance & voice'
                                      : (planId == 'VIP_WEEKLY' ? 'Short trial pass' : 'Best long-term value'),
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${plan['price_inr']} / ${plan['price_usd']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                plan['period'],
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // VIP Perks Checklist
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VIP MEMBERSHIP INCLUDES:',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildPerkRow(Icons.all_inclusive, 'Unlimited 24/7 Chats (Zero daily limits)'),
                      _buildPerkRow(Icons.record_voice_over, 'Direct Whisper Voice Autoplay (edge-tts)'),
                      _buildPerkRow(Icons.auto_stories, 'Unlimited Story & AI Chapter Generation'),
                      _buildPerkRow(Icons.lock_open, 'Uncensored Secret Diary & Candid Photos'),
                      _buildPerkRow(Icons.bolt, 'Priority Ultra-Fast AI Processing'),
                      _buildPerkRow(Icons.verified, 'Golden VIP Status Profile Badge'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _subscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2D55), Color(0xFFFF5E3A), Color(0xFFC026D3)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66FF2D55),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.flash_on, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ACTIVATE VIP • ${_getSelectedPriceDisplay()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Cancel anytime. 100% satisfaction guaranteed.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSelectedPriceDisplay() {
    final p = _fallbackPlans.firstWhere(
      (e) => e['plan_id'] == _selectedPlanId,
      orElse: () => _fallbackPlans[1],
    );
    return '${p['price_inr']} (${p['price_usd']})';
  }

  Widget _buildPerkRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.pinkAccent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
