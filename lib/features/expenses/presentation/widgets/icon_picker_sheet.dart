import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IconPickerSheet extends StatelessWidget {
  final Color color;
  final IconData? selected;

  const IconPickerSheet({super.key, required this.color, this.selected});

  static const _icons = <IconData>[
    // Food & Dining
    Icons.restaurant_rounded,
    Icons.fastfood_rounded,
    Icons.local_cafe_rounded,
    Icons.local_bar_rounded,
    Icons.bakery_dining_rounded,
    Icons.ramen_dining_rounded,
    Icons.lunch_dining_rounded,
    Icons.set_meal_rounded,
    Icons.cake_rounded,
    Icons.local_pizza_rounded,
    // Transport
    Icons.directions_car_rounded,
    Icons.directions_bus_rounded,
    Icons.local_taxi_rounded,
    Icons.flight_rounded,
    Icons.train_rounded,
    Icons.two_wheeler_rounded,
    Icons.local_gas_station_rounded,
    Icons.electric_car_rounded,
    Icons.directions_bike_rounded,
    // Shopping
    Icons.shopping_bag_rounded,
    Icons.shopping_cart_rounded,
    Icons.storefront_rounded,
    Icons.local_mall_rounded,
    Icons.checkroom_rounded,
    Icons.redeem_rounded,
    Icons.sell_rounded,
    Icons.inventory_2_rounded,
    // Health
    Icons.medical_services_rounded,
    Icons.local_pharmacy_rounded,
    Icons.fitness_center_rounded,
    Icons.spa_rounded,
    Icons.self_improvement_rounded,
    Icons.monitor_heart_rounded,
    Icons.psychology_rounded,
    // Housing
    Icons.home_rounded,
    Icons.apartment_rounded,
    Icons.bed_rounded,
    Icons.cleaning_services_rounded,
    Icons.plumbing_rounded,
    Icons.electrical_services_rounded,
    Icons.yard_rounded,
    Icons.chair_rounded,
    // Entertainment
    Icons.movie_rounded,
    Icons.sports_esports_rounded,
    Icons.music_note_rounded,
    Icons.theater_comedy_rounded,
    Icons.sports_soccer_rounded,
    Icons.book_rounded,
    Icons.headphones_rounded,
    Icons.videocam_rounded,
    Icons.palette_rounded,
    Icons.sports_basketball_rounded,
    // Education
    Icons.school_rounded,
    Icons.menu_book_rounded,
    Icons.science_rounded,
    Icons.computer_rounded,
    Icons.calculate_rounded,
    Icons.library_books_rounded,
    // Finance
    Icons.credit_card_rounded,
    Icons.account_balance_rounded,
    Icons.savings_rounded,
    Icons.payments_rounded,
    Icons.currency_exchange_rounded,
    Icons.receipt_long_rounded,
    Icons.trending_up_rounded,
    Icons.attach_money_rounded,
    // Work / Income
    Icons.work_rounded,
    Icons.laptop_rounded,
    Icons.business_center_rounded,
    Icons.store_rounded,
    Icons.engineering_rounded,
    Icons.handyman_rounded,
    Icons.design_services_rounded,
    // People / Social
    Icons.people_rounded,
    Icons.person_rounded,
    Icons.child_care_rounded,
    Icons.pets_rounded,
    Icons.volunteer_activism_rounded,
    Icons.favorite_rounded,
    Icons.celebration_rounded,
    Icons.card_giftcard_rounded,
    // Travel
    Icons.travel_explore_rounded,
    Icons.luggage_rounded,
    Icons.beach_access_rounded,
    Icons.hiking_rounded,
    Icons.hotel_rounded,
    Icons.map_rounded,
    // Misc
    Icons.category_rounded,
    Icons.label_rounded,
    Icons.star_rounded,
    Icons.bolt_rounded,
    Icons.eco_rounded,
    Icons.water_drop_rounded,
    Icons.wb_sunny_rounded,
    Icons.nights_stay_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Text('Elige un ícono', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottom),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: _icons.length,
              itemBuilder: (_, i) {
                final icon = _icons[i];
                final isSelected = icon.codePoint == selected?.codePoint;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, icon);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: color, width: 2)
                          : null,
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
