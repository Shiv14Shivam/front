import 'package:flutter/material.dart';

class RoleCard extends StatefulWidget {
  final String title;

  final IconData icon;
  final Color baseColor;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.title,

    required this.icon,
    required this.baseColor,
    required this.onTap,
  });

  @override
  State<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<RoleCard> {
  bool isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        transform: Matrix4.translationValues(0, isPressed ? -6 : 0, 0),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPressed ? widget.baseColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isPressed ? 0.20 : 0.10),
              blurRadius: isPressed ? 28 : 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: isPressed
                    ? widget.baseColor
                    : widget.baseColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 48,
                color: isPressed ? Colors.white : widget.baseColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
