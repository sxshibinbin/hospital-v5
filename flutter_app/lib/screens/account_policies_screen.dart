import 'package:flutter/material.dart';

import '../widgets/policy_webview_dialog.dart';

class AccountPoliciesScreen extends StatelessWidget {
  const AccountPoliciesScreen({super.key});

  Future<void> _openPolicy(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    return showPolicyWebViewDialog(context, title: title, url: url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FD),
      appBar: AppBar(title: const Text('协议与隐私'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('用户协议'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openPolicy(
                    context,
                    title: '用户协议',
                    url: userAgreementUrl,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('隐私政策'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openPolicy(
                    context,
                    title: '隐私政策',
                    url: privacyPolicyUrl,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
