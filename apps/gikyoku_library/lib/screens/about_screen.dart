import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scope.dart';
import '../theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const AboutScreen(), settings: const RouteSettings(name: 'about')),
  );

  static final _site = Uri.parse('https://gikyokutosyokan.com/');
  static final _privacy = Uri.parse('https://gikyokutosyokan.com/support/privacy-policy');
  static final _contact = Uri.parse('https://gikyokutosyokan.com/support/contact');

  @override
  Widget build(BuildContext context) {
    final catalog = AppScope.of(context).catalog;
    final at = catalog.generatedAt.toUtc().add(const Duration(hours: 9));
    Widget link(String label, Uri url) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => launchUrl(url, mode: LaunchMode.inAppBrowserView),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('このアプリについて')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            '戯曲図書館のアプリです。上演する台本を人数と時間で探し、候補を比べられます。'
            '作品の情報はサイトと同じもので、人数や時間が不明の作品もあります。上演の前に、台本と権利者の情報を確かめてください。',
            style: TextStyle(fontSize: 15, height: 1.75, color: Palette.ink),
          ),
          const SizedBox(height: 12),
          Text('作品数: ${catalog.plays.length}\nデータの更新: ${at.year}年${at.month}月${at.day}日', style: const TextStyle(fontSize: 13, height: 1.7, color: Palette.inkSoft)),
          const SizedBox(height: 12),
          link('戯曲図書館のサイト', _site),
          link('お問い合わせ', _contact),
          link('プライバシーポリシー', _privacy),
        ],
      ),
    );
  }
}
