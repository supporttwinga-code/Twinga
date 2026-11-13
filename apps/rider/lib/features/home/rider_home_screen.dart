
import 'package:flutter/material.dart';

class RiderHomeScreen extends StatelessWidget {
  final RiderDashboardData data;

  const RiderHomeScreen({
    super.key,
    required this.data,
  });

  static const Color navy = Color(0xFF071735);
  static const Color blue = Color(0xFF1765F5);
  static const Color blueDark = Color(0xFF1045B5);
  static const Color lightBlue = Color(0xFFEDF3FF);
  static const Color background = Color(0xFFF5F7FC);
  static const Color green = Color(0xFF13B96B);
  static const Color textGrey = Color(0xFF77839A);
  static const Color borderColor = Color(0xFFE8EDF5);

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
                  SliverToBoxAdapter(child: _header()),
                  SliverToBoxAdapter(child: _statistics()),
                  SliverToBoxAdapter(child: _sectionHeading(
                    'Your Current Delivery',
                    'Manage your active order',
                  )),
                  SliverToBoxAdapter(child: _activeOrder()),
                  SliverToBoxAdapter(child: _sectionHeading(
                    'Quick Access',
                    'Everything you need in one place',
                  )),
                  SliverToBoxAdapter(child: _quickActions()),
                  SliverToBoxAdapter(child: _achievement()),
                  SliverToBoxAdapter(child: _locationCard()),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 25),
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

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF061638),
            Color(0xFF0B3B91),
            Color(0xFF1765F5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(34),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _headerButton(
                Icons.menu_rounded,
                data.onMenu,
              ),
              const Spacer(),
              const Column(
                children: [
                  Text(
                    'TWINGA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'DELIVERY PARTNER',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _headerButton(
                    Icons.notifications_none_rounded,
                    data.onNotifications,
                  ),
                  if (data.unreadNotifications > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4757),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          data.unreadNotifications > 99
                              ? '99+'
                              : data.unreadNotifications.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 27),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8DB9FF),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.18),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 37,
                  backgroundColor: Colors.white,
                  backgroundImage: data.profileImageUrl.isNotEmpty
                      ? NetworkImage(data.profileImageUrl)
                      : null,
                  child: data.profileImageUrl.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          color: blue,
                          size: 40,
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
                            Icons.verified_rounded,
                            color: Color(0xFF71C7FF),
                            size: 19,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Welcome to your delivery dashboard',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 13),
                    _onlineToggle(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _onlineToggle() {
    return GestureDetector(
      onTap: data.onToggleOnline,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: data.isOnline
              ? green.withOpacity(.20)
              : Colors.white.withOpacity(.13),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: data.isOnline ? green : Colors.white38,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: data.isOnline
                    ? const Color(0xFF55FF9B)
                    : Colors.white70,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              data.isOnline ? 'YOU ARE ONLINE' : 'YOU ARE OFFLINE',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(width: 7),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerButton(
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white.withOpacity(.13),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 43,
          height: 43,
          child: Icon(
            icon,
            color: Colors.white,
            size: 23,
          ),
        ),
      ),
    );
  }

  Widget _statistics() {
    return Transform.translate(
      offset: const Offset(0, -19),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: navy.withOpacity(.07),
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
            _statDivider(),
            Expanded(
              child: _statItem(
                Icons.receipt_long_rounded,
                "Today's Orders",
                data.todayOrders.toString(),
                data.ordersTrend,
              ),
            ),
            _statDivider(),
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
          width: 43,
          height: 43,
          decoration: const BoxDecoration(
            color: lightBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: blue,
            size: 22,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
            color: textGrey,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: navy,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (trend.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            trend,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: green,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 88,
      color: borderColor,
    );
  }

  Widget _sectionHeading(
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(19, 0, 19, 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeOrder() {
    final order = data.activeOrder;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 23),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: navy.withOpacity(.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: order == null
            ? _noActiveOrder()
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 15,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [navy, blueDark, blue],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: Color(0xFFFFD65A),
                          size: 23,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'ACTIVE DELIVERY',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                        if (order.remainingTime.isNotEmpty)
                          _timerBadge(order.remainingTime),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _restaurantImage(
                              order.restaurantImageUrl,
                            ),
                            const SizedBox(width: 12),
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.storefront_rounded,
                                        color: blue,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          order.pickupAddress,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: textGrey,
                                            fontSize: 11,
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
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${order.payout.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: navy,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Text(
                                  'PAYOUT',
                                  style: TextStyle(
                                    color: textGrey,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .7,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 17),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: background,
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  color: lightBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.home_rounded,
                                  color: blue,
                                  size: 22,
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
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .6,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      order.customerAddress,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: navy,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          height: 53,
                          child: ElevatedButton(
                            onPressed: order.onPrimaryAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blue,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: blue.withOpacity(.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.navigation_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 9),
                                Text(
                                  order.primaryActionLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
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
      ),
    );
  }

  Widget _noActiveOrder() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 27,
      ),
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: const BoxDecoration(
              color: lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: blue,
              size: 43,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Active Order',
            style: TextStyle(
              color: navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            data.isOnline
                ? 'You are online. New order requests will appear here.'
                : 'Go online when you are ready to receive delivery requests.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textGrey,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: data.isOnline
                  ? green.withOpacity(.09)
                  : const Color(0xFFF0F2F6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: data.isOnline ? green : textGrey,
                ),
                const SizedBox(width: 6),
                Text(
                  data.isOnline ? 'WAITING FOR REQUESTS' : 'CURRENTLY OFFLINE',
                  style: TextStyle(
                    color: data.isOnline ? green : textGrey,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timerBadge(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _restaurantImage(String url) {
    return Container(
      width: 69,
      height: 69,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: blue.withOpacity(.7),
          width: 2,
        ),
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
        size: 30,
      ),
    );
  }

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Row(
        children: [
          Expanded(
            child: _actionCard(
              Icons.analytics_rounded,
              'Earnings',
              data.onEarnings,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _actionCard(
              Icons.receipt_long_rounded,
              'History',
              data.onHistory,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _actionCard(
              Icons.account_balance_wallet_rounded,
              'Payouts',
              data.onPayouts,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _actionCard(
              Icons.support_agent_rounded,
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 103,
          padding: const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: navy.withOpacity(.025),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: const BoxDecoration(
                  color: lightBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: blue,
                  size: 21,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF071735),
            Color(0xFF123E91),
            Color(0xFF1765F5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: blue.withOpacity(.14),
            blurRadius: 17,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 53,
            height: 53,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFFD65A),
              size: 31,
            ),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (data.achievementSubtitle.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    data.achievementSubtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFFFD65A),
            size: 39,
          ),
        ],
      ),
    );
  }

  Widget _locationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(.04),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: const BoxDecoration(
              color: lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: blue,
              size: 26,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Location',
                  style: TextStyle(
                    color: navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: data.isLocationSharing ? green : textGrey,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        data.isLocationSharing
                            ? 'Location sharing active'
                            : 'Location sharing inactive',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textGrey,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          OutlinedButton(
            onPressed: data.onViewMap,
            style: OutlinedButton.styleFrom(
              foregroundColor: blue,
              side: const BorderSide(color: blue),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 15),
                SizedBox(width: 4),
                Text(
                  'Map',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
          top: Radius.circular(25),
        ),
        border: const Border(
          top: BorderSide(color: borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(.07),
            blurRadius: 17,
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
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? lightBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        icons[index],
                        size: 22,
                        color: selected ? blue : textGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: selected ? blue : textGrey,
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w600,
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
