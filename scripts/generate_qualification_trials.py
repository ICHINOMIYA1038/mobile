#!/usr/bin/env python3
import json
import plistlib
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'apps/fp1_talk'
EXAMS = {
    'fp2': ('FP2級', 'FP2', '#155E75'),
    'fp3': ('FP3級', 'FP3', '#0F766E'),
    'itpassport': ('ITパスポート', 'IT', '#4338CA'),
    'sg': ('情報セキュリティマネジメント', 'SG', '#9A3412'),
    'fe': ('基本情報技術者', 'FE', '#1D4ED8'),
    'kanrigyo': ('管理業務主任者', 'KG', '#7C3AED'),
    'chintai': ('賃貸不動産経営管理士', 'CH', '#B45309'),
}


def create_icon(folder: Path, code: str, color: str) -> None:
    icon_dir = folder / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    svg = folder / 'icon/source.svg'
    svg.parent.mkdir(parents=True, exist_ok=True)
    svg.write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
        f'<rect width="1024" height="1024" fill="{color}"/>'
        '<path d="M178 268h668M178 756h668" stroke="#ffffff" stroke-width="30" opacity=".45"/>'
        f'<text x="512" y="625" text-anchor="middle" font-family="Arial,Helvetica,sans-serif" '
        f'font-size="340" font-weight="bold" fill="#ffffff">{code}</text></svg>\n',
        encoding='utf-8',
    )
    master = folder / 'icon/icon.png'
    subprocess.run(['rsvg-convert', '-w', '1024', '-h', '1024', '-o', str(master), str(svg)], check=True)
    content = json.loads((icon_dir / 'Contents.json').read_text())
    for image in content['images']:
        filename = image.get('filename')
        if not filename:
            continue
        size = float(image['size'].split('x')[0])
        scale = int(image['scale'][0])
        pixels = round(size * scale)
        subprocess.run(['magick', str(master), '-resize', f'{pixels}x{pixels}',
                        '-alpha', 'off', '-type', 'TrueColor', str(icon_dir / filename)], check=True)


def generate(slug: str) -> None:
    name, code, color = EXAMS[slug]
    app = f'{slug}_talk'
    bundle_id = f'jp.pairof.{slug}.talk'
    target = ROOT / 'apps' / app
    if target.exists():
        raise SystemExit(f'Already exists: {target}')
    target.mkdir()

    tracked = subprocess.check_output(
        ['git', 'ls-files', '--', 'apps/fp1_talk/ios', 'apps/fp1_talk/.gitignore'],
        cwd=ROOT, text=True,
    ).splitlines()
    for path_string in tracked:
        relative = Path(path_string).relative_to('apps/fp1_talk')
        if relative.parts[:2] == ('ios', 'fastlane'):
            continue
        if relative.name == 'Products.storekit':
            continue
        if relative.name == 'Package.resolved':
            continue
        source = ROOT / path_string
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

    project = target / 'ios/Runner.xcodeproj/project.pbxproj'
    project.write_text(
        project.read_text()
        .replace('jp.pairof.fp1.talk', bundle_id)
        .replace('DEVELOPMENT_TEAM = SZFUZ58P49;', 'DEVELOPMENT_TEAM = "";\n\t\t\t\tCODE_SIGNING_ALLOWED = NO;')
        .replace('CODE_SIGN_STYLE = Automatic;', 'CODE_SIGN_STYLE = Manual;'),
        encoding='utf-8',
    )
    scheme = target / 'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme'
    scheme.write_text(re.sub(r'^\s*StoreKitConfigurationFileReference = .*\n', '',
                             scheme.read_text(), flags=re.MULTILINE), encoding='utf-8')
    plist_path = target / 'ios/Runner/Info.plist'
    with plist_path.open('rb') as file:
        plist = plistlib.load(file)
    plist['CFBundleDisplayName'] = f'pAIrOf {name}'
    plist['CFBundleName'] = app
    plist.pop('GADApplicationIdentifier', None)
    plist.pop('SKAdNetworkItems', None)
    with plist_path.open('wb') as file:
        plistlib.dump(plist, file, sort_keys=False)
    framework_plist = target / 'ios/Flutter/AppFrameworkInfo.plist'
    with framework_plist.open('rb') as file:
        framework = plistlib.load(file)
    framework['MinimumOSVersion'] = '15.0'
    with framework_plist.open('wb') as file:
        plistlib.dump(framework, file, sort_keys=False)

    (target / 'pubspec.yaml').write_text(
        f'name: {app}\n'
        'resolution: workspace\n'
        f'description: "{name}の無料学習アプリ試作版"\n'
        'publish_to: none\n'
        'version: 0.1.0+1\n\n'
        'environment:\n  sdk: ^3.12.2\n\n'
        'dependencies:\n'
        '  flutter:\n    sdk: flutter\n'
        '  shikaku_trial:\n    path: ../../packages/shikaku_trial\n\n'
        'flutter:\n  uses-material-design: true\n', encoding='utf-8',
    )
    lib = target / 'lib'
    lib.mkdir()
    (lib / 'main.dart').write_text(
        "import 'package:flutter/material.dart';\n"
        "import 'package:shikaku_trial/shikaku_trial.dart';\n\n"
        'void main() => runApp(const QualificationApp(\n'
        f"  title: 'pAIrOf {name}',\n"
        f"  exam: '{slug}',\n"
        f'  color: Color(0xFF{color[1:]}),\n'
        '));\n', encoding='utf-8',
    )
    (target / 'README.md').write_text(
        f'# {name} 試作版\n\n'
        f'資格 ID は `{slug}`、iOS Bundle ID は `{bundle_id}`。'
        '共通画面は `packages/shikaku_trial` にあります。\n\n'
        'この試作版は、サーバーの教材を使って「学ぶ」「○×」「練習問題」「復習」を表示します。\n\n'
        '設定から利用規約・プライバシーポリシーを開けます。'
        '学習データは確認後にサーバーから削除し、端末の保存トークンも消します。\n\n'
        '課金・広告・Firebase 計測・ストア提出用の設定はありません。'
        'サーバーに教材が未登録の場合、アプリは通信エラーを表示します。\n',
        encoding='utf-8',
    )
    create_icon(target, code, color)


def validate(slugs=None) -> None:
    forbidden = ('fp1', 'FP1', 'GADApplicationIdentifier', 'SKAdNetworkItems',
                 'Products.storekit', 'firebase', 'purchases', 'RevenueCat',
                 'google_mobile_ads')
    for slug in (slugs or EXAMS):
        target = ROOT / 'apps' / f'{slug}_talk'
        if not target.exists():
            raise SystemExit(f'Missing: {target}')
        for path in target.rglob('*'):
            if path.is_file() and path.suffix in {'.dart', '.yaml', '.plist', '.pbxproj', '.md', '.xml', '.json', '.swift'}:
                content = path.read_text(errors='replace')
                for marker in forbidden:
                    if marker in content:
                        raise SystemExit(f'Unexpected {marker}: {path}')
        with (target / 'ios/Runner/Info.plist').open('rb') as file:
            plist = plistlib.load(file)
        if plist['CFBundleDisplayName'] != f'pAIrOf {EXAMS[slug][0]}':
            raise SystemExit(f'Wrong display name: {slug}')
        if plist.get('CFBundleDevelopmentRegion') != 'ja_JP' or plist.get('CFBundleLocalizations') != ['ja']:
            raise SystemExit(f'Wrong localization: {slug}')
        with (target / 'ios/Flutter/AppFrameworkInfo.plist').open('rb') as file:
            framework = plistlib.load(file)
        if framework.get('MinimumOSVersion') != '15.0':
            raise SystemExit(f'Wrong framework deployment target: {slug}')
        project = (target / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
        if f'PRODUCT_BUNDLE_IDENTIFIER = jp.pairof.{slug}.talk;' not in project:
            raise SystemExit(f'Wrong bundle ID: {slug}')
        if 'DEVELOPMENT_TEAM = SZFUZ58P49' in project or 'CODE_SIGN_STYLE = Automatic' in project:
            raise SystemExit(f'Signing is enabled: {slug}')
        if (target / 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png').stat().st_size == 0:
            raise SystemExit(f'Missing icon: {slug}')


if __name__ == '__main__':
    import sys
    if sys.argv[1:] == ['--check']:
        validate()
    elif len(sys.argv) == 3 and sys.argv[1] == '--create' and sys.argv[2] in EXAMS:
        generate(sys.argv[2])
        validate([sys.argv[2]])
    elif not sys.argv[1:]:
        for exam in EXAMS:
            generate(exam)
        validate()
    else:
        raise SystemExit('Usage: generate_qualification_trials.py [--check | --create <exam>]')
