class Category {
  const Category(this.id, this.name);
  final int id;
  final String name;

  factory Category.fromJson(Map<String, dynamic> j) => Category(j['id'] as int, j['name'] as String);
}

class Award {
  const Award(this.name, this.year, this.type);
  final String name;
  final int year;
  final String type;

  factory Award.fromJson(Map<String, dynamic> j) => Award(j['name'] as String, j['year'] as int, j['type'] as String);
}

class Play {
  const Play({
    required this.id,
    required this.title,
    required this.author,
    this.man,
    this.woman,
    this.others,
    this.total,
    this.minutes,
    this.synopsis,
    this.aiDescription,
    this.readUrl,
    this.buyUrl,
    this.categoryIds = const [],
    this.awards = const [],
    this.groups = const [],
  });

  final int id;
  final String title;
  final String author;
  final int? man;
  final int? woman;
  final int? others;
  final int? total;
  final int? minutes;
  final String? synopsis;
  final String? aiDescription;
  final String? readUrl;
  final String? buyUrl;
  final List<int> categoryIds;
  final List<Award> awards;
  final List<String> groups;

  /// 元データの 0 や -1 は「不明」を表す
  static int? _positive(Object? v) => v is int && v > 0 ? v : null;

  factory Play.fromJson(Map<String, dynamic> j) => Play(
    id: j['id'] as int,
    title: j['title'] as String,
    author: j['author'] as String,
    man: j['man'] is int && (j['man'] as int) >= 0 ? j['man'] as int : null,
    woman: j['woman'] is int && (j['woman'] as int) >= 0 ? j['woman'] as int : null,
    others: j['others'] is int && (j['others'] as int) >= 0 ? j['others'] as int : null,
    total: _positive(j['total']),
    minutes: _positive(j['minutes']),
    synopsis: j['synopsis'] as String?,
    aiDescription: j['aiDescription'] as String?,
    readUrl: j['readUrl'] as String?,
    buyUrl: j['buyUrl'] as String?,
    categoryIds: (j['categoryIds'] as List).cast<int>(),
    awards: (j['awards'] as List).map((a) => Award.fromJson(a as Map<String, dynamic>)).toList(),
    groups: (j['groups'] as List).cast<String>(),
  );

  /// 登場人数。合計が無ければ男女などの内訳から出す。すべて 0 は不明として扱う
  int? get cast {
    if (total != null) return total;
    final sum = (man ?? 0) + (woman ?? 0) + (others ?? 0);
    return sum > 0 ? sum : null;
  }

  bool get hasBreakdown => (man ?? 0) + (woman ?? 0) + (others ?? 0) > 0;

  String get castLabel {
    final c = cast;
    if (c == null) return '人数不明';
    if (!hasBreakdown) return '$c人';
    final parts = [if ((man ?? 0) > 0) '男$man', if ((woman ?? 0) > 0) '女$woman', if ((others ?? 0) > 0) '他$others'];
    return '$c人（${parts.join('・')}）';
  }

  String get minutesLabel => minutes == null ? '時間不明' : '$minutes分';

  Uri get siteUrl => Uri.parse('https://gikyokutosyokan.com/posts/$id');
}

class Venue {
  const Venue(this.id, this.name, this.prefecture);
  final int id;
  final String name;
  final String prefecture;

  factory Venue.fromJson(Map<String, dynamic> j) => Venue(j['id'] as int, j['name'] as String, j['prefecture'] as String);
}

class Catalog {
  const Catalog({required this.generatedAt, required this.categories, required this.plays, this.venues = const []});
  static const supportedSchema = 1;

  final DateTime generatedAt;
  final List<Category> categories;
  final List<Play> plays;
  final List<Venue> venues;

  factory Catalog.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != supportedSchema) throw const FormatException('unsupported catalog schema');
    return Catalog(
      generatedAt: DateTime.parse(j['generatedAt'] as String),
      categories: (j['categories'] as List).map((c) => Category.fromJson(c as Map<String, dynamic>)).toList(),
      plays: (j['plays'] as List).map((p) => Play.fromJson(p as Map<String, dynamic>)).toList(),
      venues: ((j['venues'] as List?) ?? const []).map((v) => Venue.fromJson(v as Map<String, dynamic>)).toList(),
    );
  }
}
