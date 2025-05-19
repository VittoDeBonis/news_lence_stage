import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:news_lens/presentation/screens/onboarding/pre_settings/pre_settings_provider.dart';

class UserAvatar extends StatelessWidget {
  final double size;
  final bool showBorder;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.size = 40,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PreSettingsProvider>(
      builder: (context, provider, _) {
        Widget avatarContent;
        
        if (provider.hasProfileImage()) {
          avatarContent = ClipOval(
            child: Image.file(
              provider.getCurrentImage()!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        } else {
          avatarContent = Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
            child: Icon(
              Icons.person,
              size: size * 0.6,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        if (showBorder) {
          avatarContent = Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: avatarContent,
          );
        }

        if (onTap != null) {
          return GestureDetector(
            onTap: onTap,
            child: avatarContent,
          );
        }

        return avatarContent;
      },
    );
  }
}

// Widget per mostrare nickname e avatar insieme
class UserInfoWidget extends StatelessWidget {
  final bool showAvatar;
  final double avatarSize;
  final TextStyle? nicknameStyle;

  const UserInfoWidget({
    super.key,
    this.showAvatar = true,
    this.avatarSize = 40,
    this.nicknameStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PreSettingsProvider>(
      builder: (context, provider, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAvatar) ...[
              UserAvatar(size: avatarSize),
              const SizedBox(width: 12),
            ],
            Text(
              provider.nickname.isNotEmpty 
                  ? provider.nickname 
                  : provider.getUserNameFromEmail(),
              style: nicknameStyle ?? Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        );
      },
    );
  }
}