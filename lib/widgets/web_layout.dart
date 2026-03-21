import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class WebLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const WebLayout({super.key, required this.child, this.maxWidth = 1200});

  @override
  Widget build(BuildContext context) {
    // On mobile — no centering or max-width needed, render full screen
    if (Responsive.isMobile(context)) {
      return child;
    }

    // On tablet/desktop — center and cap the width
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
