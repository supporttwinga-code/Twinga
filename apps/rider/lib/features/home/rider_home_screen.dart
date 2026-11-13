
import 'package:flutter/material.dart';

class RiderHomeScreen extends StatelessWidget {
  final RiderDashboardData data;

  const RiderHomeScreen({
    super.key,
    required this.data,
  });

  static const Color navy = Color(0xFF071A4A);
  static const Color blue = Color(0xFF075CF5);
  static const Color lightBlue = Color(0xFFEAF1FF);
  static const Color background = Color(0xFFF4F7FF);
  static const Color green = Color(0xFF16B957);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _header(context)),
                  SliverToBoxAdapter(child: _statistics()),
                  SliverToBoxAdapter(child: _activeOrder()),
                  SliverToBoxAdapter(child: _quickActions(context)),
                  SliverToBoxAdapter(child: _achievement()),
                  SliverToBoxAdapter(child: _locationCard()),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),
                ],
              ),
            ),
            _bottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [navy, Color(0xFF0649C9), blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleButton(
                Icons.menu_rounded,
                onTap: data.onMenu,
              ),
              const Spacer(),
              const Column(
                children: [
                  Text(
                    'TWINGA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Good Food • Faster',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: .5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _circleButton(
                    Icons.notifications_none_rounded,
                    onTap: data.onNotifications,
                  ),
                  if (data.unreadNotifications > 0)
                    Positioned(
                      right: -2,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          data.unreadNotifications.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF60A5FF),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: blue.withOpacity(.4),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 39,
                  backgroundColor: lightBlue,
                  backgroundImage: data.profileImageUrl.isNotEmpty
                      ? NetworkImage(data.profileImageUrl)
                      : null,
                  child: data.profileImageUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 42,
                          color: blue,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.riderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (data.isVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFF50B7FF),
                            size: 19,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Delivery Partner',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 13),
                    GestureDetector(
                      onTap: data.onToggleOnline,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: data.isOnline
                              ? green.withOpacity(.18)
                              : Colors.white.withOpacity(.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: data.isOnline
                                ? green
                                : Colors.white54,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 11,
                              color: data.isOnline
                                  ? const Color(0xFF4DFF88)
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              data.isOnline ? 'ONLINE' : 'OFFLINE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statistics() {
    return Transform.translate(
      offset: const Offset(0, -17),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: navy.withOpacity(.09),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _statItem(
                Icons.account_balance_wallet_rounded,
                "Today's Earnings",
                '₹${data.todayEarnings.toStringAsFixed(0)}',
                data.earningsTrend,
              ),
            ),
            _verticalDivider(),
            Expanded(
              child: _statItem(
                Icons.assignment_turned_in_rounded,
                'Total Orders',
                data.todayOrders.toString(),
                data.ordersTrend,
              ),
            ),
            _verticalDivider(),
            Expanded(
              child: _statItem(
                Icons.route_rounded,
                "Today's Trips",
                '${data.todayDistance.toStringAsFixed(1)} km',
                data.distanceTrend,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(
    IconData icon,
    String title,
    String value,
    String trend,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: const BoxDecoration(
            color: lightBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: blue, size: 23),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF63708A),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: navy,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (trend.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            trend,
            style: const TextStyle(
              color: green,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 95,
      color: const Color(0xFFE6EBF5),
    );
  }

  Widget _activeOrder() {
    final order = data.activeOrder;

    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFDCE7FF)),
          boxShadow: [
            BoxShadow(
              color: blue.withOpacity(.10),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: order == null
            ? _noActiveOrder()
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [navy, blue],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: Color(0xFFFFD84D),
                          size: 25,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'ACTIVE ORDER',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (order.remainingTime.isNotEmpty)
                          _timerBadge(order.remainingTime),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(17),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _restaurantImage(order.restaurantImageUrl),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.restaurantName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: navy,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: blue,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          order.pickupAddress,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF596781),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Column(
                              children: [
                                Text(
                                  '₹${order.payout.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: navy,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Text(
                                  'Payout',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: background,
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: lightBlue,
                                child: Icon(
                                  Icons.home_rounded,
                                  color: blue,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CUSTOMER DESTINATION',
                                      style: TextStyle(
                                        color: blue,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      order.customerAddress,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: navy,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: order.onPrimaryAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blue,
                              foregroundColor: Colors.white,
                              elevation: 5,
                              shadowColor: blue.withOpacity(.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.navigation_rounded),
                                const SizedBox(width: 10),
                                Text(
                                  order.primaryActionLabel,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                const Icon(Icons.arrow_forward_rounded),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _noActiveOrder() {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: const BoxDecoration(
              color: lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: blue,
              size: 42,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Active Order',
            style: TextStyle(
              color: navy,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            data.isOnline
                ? 'You are online. New order requests will appear here.'
                : 'Go online when you are ready to receive orders.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timerBadge(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(width: 5),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _restaurantImage(String url) {
    return Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: blue, width: 2),
      ),
      child: ClipOval(
        child: url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imageFallback(),
              )
            : _imageFallback(),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: lightBlue,
      child: const Icon(
        Icons.storefront_rounded,
        color: blue,
        size: 34,
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 22),
      child: Row(
        children: [
          Expanded(
            child: _actionCard(
              Icons.analytics_rounded,
              'Earnings',
              data.onEarnings,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionCard(
              Icons.receipt_long_rounded,
              'History',
              data.onHistory,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionCard(
              Icons.account_balance_wallet_rounded,
              'Payouts',
              data.onPayouts,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionCard(
              Icons.headset_mic_rounded,
              'Support',
              data.onSupport,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          height: 105,
          padding: const EdgeInsets.symmetric(
            horizontal: 3,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFE5EBF7)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: blue, size: 29),
              const SizedBox(height: 10),
              FittedBox(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF7E8BA4),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _achievement() {
    if (data.achievementTitle.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(17, 0, 17, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF06133C), Color(0xFF073C9C)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(.17),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFD45C),
            size: 43,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.achievementTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                if (data.achievementSubtitle.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    data.achievementSubtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFFFD45C),
            size: 48,
          ),
        ],
      ),
    );
  }

  Widget _locationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 17),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE1E9FA)),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: lightBlue,
            child: Icon(
              Icons.location_on_rounded,
              color: blue,
              size: 29,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Location',
                  style: TextStyle(
                    color: navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 9,
                      color: data.isLocationSharing
                          ? green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        data.isLocationSharing
                            ? 'Location sharing active'
                            : 'Location sharing inactive',
                        style: const TextStyle(
                          color: Color(0xFF66738C),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: data.onViewMap,
            style: OutlinedButton.styleFrom(
              foregroundColor: blue,
              side: const BorderSide(color: blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 17),
                SizedBox(width: 5),
                Text(
                  'View Map',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Icon(Icons.chevron_right, size: 17),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavigation() {
    const labels = ['Home', 'Map', 'Stats', 'Profile'];
    const icons = [
      Icons.home_rounded,
      Icons.location_on_rounded,
      Icons.analytics_rounded,
      Icons.person_rounded,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(27),
        ),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(.09),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: List.generate(4, (index) {
          final selected = data.selectedTab == index;

          return Expanded(
            child: InkWell(
              onTap: () => data.onTabSelected(index),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[index],
                      size: 26,
                      color: selected ? blue : const Color(0xFF64718A),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: selected ? blue : const Color(0xFF64718A),
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 4,
                      width: selected ? 34 : 0,
                      decoration: BoxDecoration(
                        color: blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _circleButton(
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 43,
          height: 43,
          child: Icon(icon, color: Colors.white, size: 25),
        ),
      ),
    );
  }
}

class RiderDashboardData {
  final String riderName;
  final String profileImageUrl;
  final bool isVerified;
  final bool isOnline;

  final double todayEarnings;
  final int todayOrders;
  final double todayDistance;

  final String earningsTrend;
  final String ordersTrend;
  final String distanceTrend;

  final int unreadNotifications;
  final bool isLocationSharing;

  final String achievementTitle;
  final String achievementSubtitle;

  final int selectedTab;
  final RiderActiveOrder? activeOrder;

  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final VoidCallback onToggleOnline;
  final VoidCallback onEarnings;
  final VoidCallback onHistory;
  final VoidCallback onPayouts;
  final VoidCallback onSupport;
  final VoidCallback onViewMap;
  final ValueChanged<int> onTabSelected;

  const RiderDashboardData({
    required this.riderName,
    required this.profileImageUrl,
    required this.isVerified,
    required this.isOnline,
    required this.todayEarnings,
    required this.todayOrders,
    required this.todayDistance,
    required this.earningsTrend,
    required this.ordersTrend,
    required this.distanceTrend,
    required this.unreadNotifications,
    required this.isLocationSharing,
    required this.achievementTitle,
    required this.achievementSubtitle,
    required this.selectedTab,
    required this.activeOrder,
    required this.onMenu,
    required this.onNotifications,
    required this.onToggleOnline,
    required this.onEarnings,
    required this.onHistory,
    required this.onPayouts,
    required this.onSupport,
    required this.onViewMap,
    required this.onTabSelected,
  });
}

class RiderActiveOrder {
  final String restaurantName;
  final String restaurantImageUrl;
  final String pickupAddress;
  final String customerAddress;
  final double payout;
  final String remainingTime;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;

  const RiderActiveOrder({
    required this.restaurantName,
    required this.restaurantImageUrl,
    required this.pickupAddress,
    required this.customerAddress,
    required this.payout,
    required this.remainingTime,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
  });
}
