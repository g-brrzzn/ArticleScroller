import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:html/parser.dart' as html_parser;
import 'database_service.dart';

class ArxivService {
  static Future<List<Map<String, dynamic>>> fetchTopArticles(
    String category,
    String timeframe,
    String queryText,
  ) async {
    List<String> queryParts = [];

    if (queryText.trim().isNotEmpty) {
      queryParts.add('all:"${queryText.trim()}"');
    }

    final Map<String, String> catMap = {
      "Artificial Intelligence": "cat:cs.AI",
      "Computer Science": "(cat:cs.CC OR cat:cs.CR OR cat:cs.DC OR cat:cs.SE OR cat:cs.PL)",
      "Software Engineering": "cat:cs.SE",
      "Cryptography and Security": "cat:cs.CR",
      "General Physics": "cat:physics.gen-ph",
      "Astrophysics": "cat:astro-ph",
      "Mathematics": "cat:math.HO",
      "Economics": "cat:econ.GN",
      "Quantitative Biology": "cat:q-bio",
      "Neuroscience": "cat:q-bio.NC",
      "Genetics and Genomics": "cat:q-bio.GN",
      "Longevity and Cell Biology": "(cat:q-bio.CB OR cat:q-bio.MN)",
      "Computer Graphics": "cat:cs.GR",
      "Robotics": "cat:cs.RO",
      "Quantitative Finance": "cat:q-fin.GN",
      "Quantum Physics": "cat:quant-ph",
      "Systems and Control": "cat:eess.SY",
      "Data Structures and Algorithms": "cat:cs.DS"
    };

    if (catMap.containsKey(category)) {
      queryParts.add(catMap[category]!);
    } else if (category == "All" && queryText.trim().isEmpty) {
      queryParts.add("cat:cs.AI");
    }

    DateTime now = DateTime.now();
    DateTime? startDate;

    if (timeframe == 'week') startDate = now.subtract(const Duration(days: 7));
    else if (timeframe == 'month') startDate = now.subtract(const Duration(days: 30));
    else if (timeframe == 'year') startDate = now.subtract(const Duration(days: 365));
    else if (timeframe == '3years') startDate = now.subtract(const Duration(days: 3 * 365));
    else if (timeframe == '5years') startDate = now.subtract(const Duration(days: 5 * 365));

    if (startDate != null) {
      String startStr = "${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}0000";
      String endStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}2359";
      queryParts.add("submittedDate:[$startStr TO $endStr]");
    }

    String searchQuery = queryParts.isNotEmpty ? queryParts.join(" AND ") : "all:research";
    String safeQuery = Uri.encodeComponent(searchQuery);

    final url = Uri.parse(
        "https://export.arxiv.org/api/query?search_query=$safeQuery&sortBy=relevance&sortOrder=descending&max_results=30");

    List<Map<String, dynamic>> liveArticles = [];

    try {
      final response = await http.get(
        url,
        headers: {"User-Agent": "ArticleScrollerApp/1.0"},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final entries = document.findAllElements('entry');

        for (var entry in entries) {
          final title = entry.findElements('title').firstOrNull?.innerText.replaceAll('\n', ' ').trim() ?? '';
          final summary = entry.findElements('summary').firstOrNull?.innerText.replaceAll('\n', ' ').trim() ?? '';
          final author = entry.findElements('author').firstOrNull?.findElements('name').firstOrNull?.innerText ?? 'Unknown';
          final sourceUrl = entry.findElements('id').firstOrNull?.innerText ?? '';
          final publishedDate = entry.findElements('published').firstOrNull?.innerText ?? '';

          if (title.isNotEmpty && summary.isNotEmpty) {
            Map<String, dynamic> articleData = {
              "title": title,
              "author": author,
              "content": summary,
              "source": sourceUrl,
              "category": category,
              "published_date": publishedDate,
              "is_saved": 0
            };

            await DatabaseService.instance.insertArticle(articleData);

            final dbData = await DatabaseService.instance.getArticleBySource(sourceUrl);
            if (dbData != null) {
              articleData['id'] = dbData['id'];
              articleData['is_saved'] = dbData['is_saved'];
            }

            liveArticles.add(articleData);
          }
        }
      }
    } catch (e) {
      // Intentionally suppressed for UI flow
    }

    return liveArticles;
  }

  static Future<String?> fetchFullText(String sourceUrl) async {
    final fullUrl = sourceUrl.replaceFirst("arxiv.org", "ar5iv.org");

    try {
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {"User-Agent": "ArticleScrollerApp/1.0"},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        var document = html_parser.parse(response.body);

        document.querySelectorAll('script, style, nav, footer, header').forEach((element) => element.remove());

        var contentNode = document.querySelector('article') ?? document.querySelector('main') ?? document.querySelector('body');

        if (contentNode != null) {
          return contentNode.text.trim();
        }
        return "Content structure not recognized.";
      } else {
        return "Ar5iv returned status ${response.statusCode}";
      }
    } catch (e) {
      return null;
    }
  }
}