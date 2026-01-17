import 'package:flutter/material.dart';
import 'admin_profile_button.dart';

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
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final double actualExpandedHeight = isMobile ? expandedHeight : 150.0;

    // Default actions: Profile button on mobile, none on desktop
    final List<Widget>? defaultActions = isMobile
        ? [const AdminProfileButton()]
        : null;

    return SliverAppBar(
      expandedHeight: actualExpandedHeight,
      toolbarHeight: isMobile ? kToolbarHeight : actualExpandedHeight,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      actions: actions ?? defaultActions,
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double top = constraints.biggest.height;
          final double minHeight =
              MediaQuery.of(context).padding.top + kToolbarHeight;
          final double maxHeight =
              actualExpandedHeight + MediaQuery.of(context).padding.top;
          final double delta = (maxHeight - minHeight) > 0
              ? (top - minHeight) / (maxHeight - minHeight)
              : 1.0;

          // Large title (background) opacity: fades out from delta 1.0 to 0.5 (Mobile only)
          final double largeTitleOpacity = isMobile
              ? ((delta - 0.5) / 0.5).clamp(0.0, 1.0)
              : 1.0;

          // Small title (collapsed) opacity: fades in from delta 0.5 to 0.0 (Mobile only)
          final double smallTitleOpacity = isMobile
              ? ((0.5 - delta) / 0.5).clamp(0.0, 1.0)
              : 0.0;

          return FlexibleSpaceBar(
            centerTitle: false,
            titlePadding: EdgeInsets.zero,
            title: Opacity(
              opacity: smallTitleOpacity,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
              padding: EdgeInsets.only(bottom: isMobile ? 100 : 36),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: largeTitleOpacity,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 48 : 36,
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
