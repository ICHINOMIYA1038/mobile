import 'package:in_app_review/in_app_review.dart';

/// App Store / Google Play 標準の評価依頼。
/// 独自ダイアログで星の数を聞くようなレビューゲーティングは行わない。
class ReviewPromptService {
  ReviewPromptService({InAppReview? review})
    : _review = review ?? InAppReview.instance;

  final InAppReview _review;

  Future<bool> request() async {
    try {
      if (!await _review.isAvailable()) return false;
      await _review.requestReview();
      return true;
    } catch (_) {
      // 評価依頼が出なくても学習には影響させない。
      return false;
    }
  }
}
