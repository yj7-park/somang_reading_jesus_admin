import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SliverOneUIAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final double expandedHeight;
  final bool showLogo;

  const SliverOneUIAppBar({
    super.key,
    required this.title,
    this.actions,
    this.expandedHeight = 300.0,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      actions:
          actions ??
          [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black87),
              onPressed: () => AuthService().signOut(),
              tooltip: '로그아웃',
            ),
          ],
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double top = constraints.biggest.height;
          final double minHeight =
              MediaQuery.of(context).padding.top + kToolbarHeight;
          final double maxHeight =
              expandedHeight + MediaQuery.of(context).padding.top;
          final double delta = (top - minHeight) / (maxHeight - minHeight);
          final double opacity = delta.clamp(0.0, 1.0);

          return FlexibleSpaceBar(
            centerTitle: false,
            titlePadding: EdgeInsets.zero,
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: 1.0 - opacity,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // if (showLogo) ...[
                    //   Image.asset(
                    //     'assets/icon/official_icon_transparent.png',
                    //     height: 24,
                    //   ),
                    //   const SizedBox(width: 8),
                    // ],
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            background: Container(
              color: theme.scaffoldBackgroundColor,
              padding: const EdgeInsets.only(bottom: 100),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: opacity,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      letterSpacing: -1.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
