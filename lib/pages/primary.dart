import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../view_type.dart';

//Intro screen with logo animation
class PrimaryPage extends StatefulWidget {
  final Function(ViewType) onSelectView;
  const PrimaryPage({super.key, required this.onSelectView});

  @override
  State<PrimaryPage> createState() => _PrimaryPageState();
}

class _PrimaryPageState extends State<PrimaryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showShadow = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for 2 seconds
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Smooth bounce scale
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    // Smooth fade-in
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Show shadow and navigate after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _showShadow = true;
      });
      widget.onSelectView(ViewType.landing);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow, // instant background fill
      body: Center(
        child: FadeTransition(
          // apply fade animation to the logo
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            // apply scale animation to the logo
            child: Container(
              decoration: _showShadow
                  ? BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    )
                  : null,
              //Display logo from assets
              child: SvgPicture.asset(
                "assets/log.svg",
                width: 160,
                height: 160,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
