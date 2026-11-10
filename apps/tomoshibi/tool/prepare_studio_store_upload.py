"""Prepare the ten framed 1.0.3 screenshots for App Store Connect."""

from pathlib import Path
import shutil
import subprocess


APP = Path(__file__).resolve().parents[1]
SOURCE = APP / 'ios/fastlane/screenshots/ja'
TARGET = APP / 'ios/fastlane/store_upload/ja'
SCREENS = ('01_projects', '02_3d', '03_map', '04_scenes', '05_playback')


def main():
    TARGET.mkdir(parents=True, exist_ok=True)
    names = [f'{name}{device}_framed' for device in ('', '_ipad') for name in SCREENS]
    for name in names:
        source = SOURCE / f'{name}.png'
        if not source.is_file():
            raise FileNotFoundError(source)

    for name in names:
        for extension in ('.png', '.jpg'):
            (TARGET / f'{name}{extension}').unlink(missing_ok=True)

    for name in names:
        source = SOURCE / f'{name}.png'
        if name.startswith('01_projects'):
            subprocess.run([
                'sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', 'best',
                str(source), '--out', str(TARGET / f'{name}.jpg'),
            ], check=True, capture_output=True)
        else:
            shutil.copy2(source, TARGET / source.name)

    expected = {
        f'{name}.jpg' if name.startswith('01_projects') else f'{name}.png'
        for name in names
    }
    actual = {item.name for item in TARGET.iterdir() if item.is_file()}
    if actual != expected:
        raise RuntimeError(f'Unexpected upload files: {sorted(actual ^ expected)}')
    print('Prepared 10 screenshots (2 JPEG, 8 PNG)')


if __name__ == '__main__':
    main()
