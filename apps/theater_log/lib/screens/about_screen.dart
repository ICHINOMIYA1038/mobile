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
  static final _terms = Uri.parse('https://gikyokutosyokan.com/support/tos');

  @override
  Widget build(BuildContext context) {
    final catalog = AppScope.of(context).catalog;
    final at = catalog.generatedAt.toUtc().add(const Duration(hours: 9));
    Widget link(String label, Uri url) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => launchUrl(url, mode: LaunchMode.externalApplication),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('このアプリについて')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'ゲキポンは、観た舞台を記録するアプリです。記録は半券になってたまり、行った劇場にはスタンプを押せます。戯曲図書館が運営しています。'
            '劇場スタンプは、このアプリの楽しみ方で、各劇場とは関係ありません。',
            style: TextStyle(fontSize: 15, height: 1.75, color: Palette.ink),
          ),
          const SizedBox(height: 12),
          Text('作品数: ${catalog.plays.length}\nデータの更新: ${at.year}年${at.month}月${at.day}日', style: const TextStyle(fontSize: 13, height: 1.7, color: Palette.inkSoft)),
          const SizedBox(height: 12),
          link('戯曲図書館のサイト', _site),
          link('お問い合わせ', _contact),
          link('利用規約', _terms),
          link('プライバシーポリシー', _privacy),
          const SizedBox(height: 12),
          const Text('不適切な感想は、感想の「…」から通報できます。通報は運営が確かめ、24 時間以内に対応します。', style: TextStyle(fontSize: 12, height: 1.7, color: Palette.inkSoft)),
        ],
      ),
    );
  }
}
