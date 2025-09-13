import 'package:flutter/material.dart';
import 'package:swan_sync/z-firestore-example/presentation/widgets/entry_icon.dart';

class UserLabel extends StatelessWidget {
  final String userId;

  const UserLabel({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: EntryDecorator.color(userId),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            topRight: Radius.circular(8),
          ),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              WidgetSpan(child: const Icon(Icons.person, size: 16, color: Colors.white)),
              TextSpan(
                text: EntryDecorator.obfuscatedUserId(userId.isEmpty ? '' : userId),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
