import 'package:flutter/material.dart';

class FloatingButton extends StatelessWidget {
  const FloatingButton({super.key, this.onPressed});

  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 32,
      bottom: 80,
      child: FloatingActionButton(
        mini: true,
        shape: const CircleBorder(),
        onPressed: onPressed,
        child: const Icon(Icons.arrow_downward_outlined, size: 20),
      ),
    );
  }
}
