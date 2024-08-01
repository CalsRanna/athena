import 'package:flutter/material.dart';

class FloatingButton extends StatelessWidget {
  const FloatingButton({super.key, this.onPressed});

  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      right: 32,
      child: FloatingActionButton(
        mini: true,
        onPressed: onPressed,
        shape: const CircleBorder(),
        child: const Icon(Icons.arrow_downward_outlined, size: 20),
      ),
    );
  }
}
