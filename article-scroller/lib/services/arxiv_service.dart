import 'dart:async';
import 'dart:io';
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

    final Map<String, String> reverseMap = {
      "cs.AI": "Artificial Intelligence",
      "cs.AR": "Hardware Architecture",
      "cs.CC": "Computational Complexity",
      "cs.CE": "Computational Engineering",
      "cs.CG": "Computational Geometry",
      "cs.CL": "Computation and Language",
      "cs.CR": "Cryptography and Security",
      "cs.CV": "Computer Vision",
      "cs.CY": "Computers and Society",
      "cs.DB": "Databases",
      "cs.DC": "Distributed Computing",
      "cs.DL": "Digital Libraries",
      "cs.DM": "Discrete Mathematics",
      "cs.DS": "Data Structures and Algorithms",
      "cs.ET": "Emerging Technologies",
      "cs.FL": "Formal Languages",
      "cs.GL": "General Literature",
      "cs.GR": "Computer Graphics",
      "cs.GT": "Computer Science and Game Theory",
      "cs.HC": "Human-Computer Interaction",
      "cs.IR": "Information Retrieval",
      "cs.IT": "Information Theory",
      "cs.LG": "Machine Learning",
      "cs.LO": "Logic in Computer Science",
      "cs.MA": "Multiagent Systems",
      "cs.MM": "Multimedia",
      "cs.MS": "Mathematical Software",
      "cs.NA": "Numerical Analysis",
      "cs.NE": "Neural Computing",
      "cs.NI": "Networking and Internet",
      "cs.OH": "Other Computer Science",
      "cs.OS": "Operating Systems",
      "cs.PF": "Performance",
      "cs.PL": "Programming Languages",
      "cs.RO": "Robotics",
      "cs.SC": "Symbolic Computation",
      "cs.SD": "Sound",
      "cs.SE": "Software Engineering",
      "cs.SI": "Social and Information Networks",
      "cs.SY": "Systems and Control",
      "stat.ML": "Machine Learning (Stat)",
      "stat.AP": "Applied Statistics",
      "stat.CO": "Computation",
      "stat.ME": "Methodology",
      "stat.TH": "Statistics Theory",
      "math.HO": "History and Overview",
      "math.PR": "Probability",
      "math.ST": "Statistics Theory",
      "math.CO": "Combinatorics",
      "math.OC": "Optimization and Control",
      "q-bio.BM": "Biomolecules",
      "q-bio.CB": "Cell Biology",
      "q-bio.GN": "Genomics",
      "q-bio.MN": "Molecular Networks",
      "q-bio.NC": "Neuroscience",
      "q-bio.PE": "Populations and Evolution",
      "q-bio.QM": "Quantitative Methods",
      "q-bio.TO": "Tissues and Organs",
      "physics.gen-ph": "General Physics",
      "physics.data-an": "Data Analysis",
      "astro-ph": "Astrophysics",
      "quant-ph": "Quantum Physics",
      "eess.AS": "Audio and Speech Processing",
      "eess.IV": "Image and Video Processing",
      "eess.SP": "Signal Processing",
      "eess.SY": "Systems and Control",
      "econ.EM": "Econometrics",
      "econ.GN": "General Economics",
      "econ.TH": "Theoretical Economics",
    };

    if (catMap.containsKey(category)) {
      queryParts.add(catMap[category]!);
    } else if (category == "All" && queryText.trim().isEmpty) {
      queryParts.add("all:research");
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

          final categoryNode = entry.findElements('category').firstOrNull;
          final arxivTag = categoryNode?.getAttribute('term') ?? '';
          
          String displayCategory = category;
          if (arxivTag.isNotEmpty) {
            displayCategory = reverseMap[arxivTag] ?? arxivTag.toUpperCase();
          } else if (category == "All") {
            displayCategory = "RESEARCH";
          }

          if (title.isNotEmpty && summary.isNotEmpty) {
            Map<String, dynamic> articleData = {
              "title": title,
              "author": author,
              "content": summary,
              "source": sourceUrl,
              "category": displayCategory,
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
      } else if (response.statusCode == 429 || response.statusCode == 403) {
        throw Exception("Rate limit exceeded. Please wait a few minutes.");
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } on SocketException {
      throw Exception("No internet connection.");
    } on TimeoutException {
      throw Exception("Connection timed out.");
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
        throw Exception("Content structure not recognized.");
      } else if (response.statusCode == 429 || response.statusCode == 403) {
        throw Exception("Rate limit exceeded. Please wait a few minutes.");
      } else {
        throw Exception("Ar5iv server error: ${response.statusCode}");
      }
    } on SocketException {
      throw Exception("No internet connection.");
    } on TimeoutException {
      throw Exception("Connection timed out.");
    }
  }
}