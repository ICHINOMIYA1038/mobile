"""全アプリの計測が正しく入っているかを確かめる（CI と手元で使う）。

    python3 scripts/check_insights.py

確かめること:
  1. lib/main.dart で AppInsights.initialize を呼び、MaterialApp に AppInsights.navigatorObservers を渡している
  2. MaterialPageRoute / CupertinoPageRoute に RouteSettings の name を付けている
     （名前の無い画面は screen_view として記録されず、GA4 上で存在しないことになる）
計測を入れないと決めたアプリは scripts/insights-exempt.txt に書く（理由も添える）。
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
exempt = {l.split("#")[0].strip() for l in (ROOT / "scripts/insights-exempt.txt").read_text(encoding="utf-8").splitlines()} - {""}
ROUTE = re.compile(r"\b(MaterialPageRoute|CupertinoPageRoute)\s*(<[^>]*>)?\s*\(")
problems = []
for app in sorted(p for p in (ROOT / "apps").iterdir() if (p / "pubspec.yaml").exists()):
    if app.name in exempt:
        continue
    main = app / "lib/main.dart"
    src = main.read_text(encoding="utf-8") if main.exists() else ""
    if "AppInsights.initialize" not in src:
        problems.append(f"{app.name}: lib/main.dart で AppInsights.initialize を呼んでいない")
    if "AppInsights.navigatorObservers" not in "".join(f.read_text(encoding="utf-8") for f in (app / "lib").rglob("*.dart")):
        problems.append(f"{app.name}: MaterialApp に AppInsights.navigatorObservers を渡していない")
    for f in (app / "lib").rglob("*.dart"):
        text = f.read_text(encoding="utf-8")
        for m in ROUTE.finditer(text):
            # 呼び出しの括弧の中に settings: があるかを見る
            depth, i = 1, m.end()
            while depth and i < len(text):
                depth += {"(": 1, ")": -1}.get(text[i], 0)
                i += 1
            if "settings:" not in text[m.end():i]:
                line = text.count("\n", 0, m.start()) + 1
                problems.append(f"{f.relative_to(ROOT)}:{line}: {m.group(1)} に RouteSettings(name: ...) が無い")
if problems:
    print("計測のチェックで見つかった問題:\n" + "\n".join("  " + p for p in problems))
    sys.exit(1)
print("計測のチェック: 問題なし")
