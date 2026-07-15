import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final double radius;
  final Widget? badge; // ví dụ icon camera, chấm online...

  const UserAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 24,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: hasPhoto
          ? NetworkImage(photoUrl!)
          : AssetImage("assets/img/base.png"),
    );

    if (badge == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(right: -2, bottom: -2, child: badge!),
      ],
    );
  }
}
