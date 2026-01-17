import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/format_helper.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class AdminProfileButton extends StatelessWidget {
  final Color? iconColor;
  final bool showLabel;
  final double? iconSize;

  const AdminProfileButton({
    super.key,
    this.iconColor,
    this.showLabel = false,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        String name = '관리자';
        String roleLabel = '관리자 계정';
        String? phone;
        String? birth;

        if (snapshot.hasData && snapshot.data!.exists) {
          final profile = UserProfile.fromFirestore(snapshot.data!);
          name = profile.name;
          phone = profile.phoneNumber;
          birth = profile.birthDate;

          switch (profile.role) {
            case 'admin':
              roleLabel = '관리자';
              break;
            case 'leader':
              roleLabel = '팀장';
              break;
            case 'member':
              roleLabel = '팀원';
              break;
            default:
              roleLabel = profile.role ?? '사용자';
          }
        }

        final defaultColor = Colors.grey[700];
        final effectiveColor = iconColor ?? defaultColor;

        return PopupMenuButton<String>(
          tooltip: '',
          offset: const Offset(0, 45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 12.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_circle,
                  color: effectiveColor,
                  size: iconSize ?? (showLabel ? 32 : 28),
                ),
                if (showLabel) ...[
                  const SizedBox(height: 4),
                  Text(
                    '프로필',
                    style: TextStyle(
                      fontSize: 12,
                      color: effectiveColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(child: Icon(Icons.person)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            roleLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (phone != null && phone.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '전화번호: ${FormatHelper.formatPhone(phone)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                          if (birth != null && birth.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '생년월일: $birth',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: const [
                  Icon(Icons.logout, color: Colors.redAccent, size: 20),
                  SizedBox(width: 12),
                  Text('로그아웃', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'logout') {
              authService.signOut();
            }
          },
        );
      },
    );
  }
}
