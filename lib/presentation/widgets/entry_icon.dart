import 'dart:math';

import 'package:flutter/material.dart';

part 'icons.dart';

class EntryDecorator extends StatelessWidget {
  final String identifier;
  const EntryDecorator({super.key, required this.identifier});
  IconData get icon {
    // use the string to generate a integer that's always unique to the string
    // using the int, let that be the seed for random
    // generate a random number using that seed, with fullIconsList's length as the end boundary
    // return the randomly chosen icon
    final hash = identifier.codeUnits.fold<int>(0, (p, c) => 0x1fffffff & (p * 31 + c));
    if (fullIconsList.isEmpty) return Icons.help_outline;
    final index = Random(hash).nextInt(fullIconsList.length);
    return fullIconsList.elementAt(index);
  }

  static Color color(String factor) {
    final hash = factor.codeUnits.fold<int>(0, (p, c) => 0x1fffffff & (p * 31 + c));
    final rand = Random(hash);
    return Color.fromARGB(
      255,
      50 + rand.nextInt(156), // color range is <50, 206> to avoid too dark or too light colors
      50 + rand.nextInt(156),
      50 + rand.nextInt(156),
    );
  }

  static String obfuscatedUserId(String s) {
    // obfuscate the device name by returning a hex code of a random icon based on the string
    if (s.isEmpty) return 'Anonymous';
    final hash = s.codeUnits.fold<int>(0, (p, c) => 0x1fffffff & (p * 31 + c));
    if (fullIconsList.isEmpty) return 'HelpOutline';
    final index = Random(hash).nextInt(fullIconsList.length);
    return fullIconsList.elementAt(index).codePoint.toRadixString(16);
  }

  @override
  Widget build(BuildContext context) => Icon(icon);
}
