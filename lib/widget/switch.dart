import 'package:flutter/material.dart';

class ASwitch extends StatelessWidget {
  final void Function(bool)? onChanged;
  final bool value;
  const ASwitch({super.key, required this.onChanged, required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: ShapeDecoration(
        color: value ? Color(0xFFA7BA88) : Color(0xFFC2C9D1),
        shape: StadiumBorder(),
      ),
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(2),
      width: 36,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        height: 16,
        width: 16,
      ),
    );
  }
}
