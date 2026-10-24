import 'package:flutter/material.dart';

import '../../l10n/labels.dart';

/// Shows a spinner while a deferred library downloads (web), then the screen.
/// On iOS/Android deferred loading resolves immediately.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({
    super.key,
    required this.loader,
    required this.builder,
  });

  final Future<void> Function() loader;
  final WidgetBuilder builder;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late final Future<void> _loaded = widget.loader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loaded,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(AppLocalizations.of(context).loadFailed));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return widget.builder(context);
      },
    );
  }
}
