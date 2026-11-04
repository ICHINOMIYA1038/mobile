import 'package:flutter_test/flutter_test.dart';
import 'package:fp1_talk/widgets/calculator.dart';

/// 電卓はサイトの Calculator.svelte と同じ動き: 押した順に計算する（× を先にしない）・丸めない（12桁まで）
void main() {
  CalculatorController keys(String seq) {
    final c = CalculatorController();
    for (final k in seq.split(' ')) {
      c.press(k);
    }
    return c;
  }

  test('押した順に計算する（2 + 3 × 4 は 20）', () {
    expect(keys('2 + 3 × 4 =').display, '20');
  });

  test('丸めずに12桁まで出す（年金額の計算）', () {
    final c = keys('8 4 7 3 0 0 × 4 5 2 ÷ 4 8 0 =');
    expect(c.display, '797,874.166667');
    expect(c.memo, '382,979,600 ÷ 480 =');
  });

  test('小数・00・桁区切り・符号・1文字消す・C', () {
    expect(keys('1 00 0 . 5').display, '1,000.5');
    expect(keys('0 . 1 + 0 . 2 =').display, '0.3');
    expect(keys('5 ±').display, '-5');
    expect(keys('1 2 3 ⌫').display, '12');
    final c = keys('9 × 9');
    c.press('C');
    expect(c.display, '0');
    expect(c.memo, '');
  });

  test('0 で割るとエラー、次の数字で戻る', () {
    final c = keys('1 ÷ 0 =');
    expect(c.display, 'エラー');
    c.press('7');
    expect(c.display, '7');
  });
}
