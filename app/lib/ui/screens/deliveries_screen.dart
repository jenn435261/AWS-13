import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// Deliveries (conditional tab): operational buckets for users with a
/// distributor capability or an active mission (spec §22). Swipeable tabs.
class DeliveriesScreen extends StatelessWidget {
  const DeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    const buckets = ['Assigned', 'Available', 'In transit', 'Awaiting handoff', 'Completed'];
    return DefaultTabController(
      length: buckets.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.t('nav_deliveries')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final b in buckets) Tab(text: b)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final b in buckets)
              Center(
                child: Text(b,
                    style: TextStyle(fontFamily: 'Roboto', 
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.outline)),
              ),
          ],
        ),
      ),
    );
  }
}
