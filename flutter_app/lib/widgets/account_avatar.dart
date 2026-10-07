import 'package:flutter/material.dart';

class AccountAvatarPreset {
  const AccountAvatarPreset({
    required this.key,
    required this.label,
    required this.backgroundColors,
    required this.foregroundColor,
    required this.symbol,
  });

  final String key;
  final String label;
  final List<Color> backgroundColors;
  final Color foregroundColor;
  final String symbol;
}

const accountAvatarPresets = <AccountAvatarPreset>[
  AccountAvatarPreset(
    key: 'sunrise',
    label: '晨曦',
    backgroundColors: [Color(0xFFFFD8C2), Color(0xFFFFA6A6)],
    foregroundColor: Color(0xFF6E2F53),
    symbol: '晨',
  ),
  AccountAvatarPreset(
    key: 'violet',
    label: '薰衣草',
    backgroundColors: [Color(0xFFDCCBFF), Color(0xFFA9B8FF)],
    foregroundColor: Color(0xFF3E3566),
    symbol: '薰',
  ),
  AccountAvatarPreset(
    key: 'mint',
    label: '薄荷',
    backgroundColors: [Color(0xFFD0F4EA), Color(0xFF94DCC4)],
    foregroundColor: Color(0xFF18534B),
    symbol: '薄',
  ),
  AccountAvatarPreset(
    key: 'amber',
    label: '琥珀',
    backgroundColors: [Color(0xFFFFEDC2), Color(0xFFFBC06A)],
    foregroundColor: Color(0xFF714D16),
    symbol: '珀',
  ),
  AccountAvatarPreset(
    key: 'ocean',
    label: '海盐',
    backgroundColors: [Color(0xFFCBE7FF), Color(0xFF7EBEFF)],
    foregroundColor: Color(0xFF204B76),
    symbol: '海',
  ),
  AccountAvatarPreset(
    key: 'rose',
    label: '玫瑰',
    backgroundColors: [Color(0xFFFFD4DF), Color(0xFFF39AB4)],
    foregroundColor: Color(0xFF6C2942),
    symbol: '玫',
  ),
];

AccountAvatarPreset resolveAccountAvatarPreset(String? key) {
  return accountAvatarPresets.firstWhere(
    (preset) => preset.key == key,
    orElse: () => accountAvatarPresets.first,
  );
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.name,
    this.avatarKey,
    this.radius = 28,
  });

  final String name;
  final String? avatarKey;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final preset = resolveAccountAvatarPreset(avatarKey);
    final displayText = _displayText(name, preset.symbol);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: preset.backgroundColors,
        ),
        boxShadow: [
          BoxShadow(
            color: preset.backgroundColors.last.withValues(alpha: 0.32),
            blurRadius: radius * 0.6,
            offset: Offset(0, radius * 0.2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        displayText,
        style: TextStyle(
          color: preset.foregroundColor,
          fontSize: radius * 0.78,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _displayText(String name, String fallback) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized.characters.first;
  }
}
