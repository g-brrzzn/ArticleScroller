import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/arxiv_service.dart';
import '../services/database_service.dart';
import '../main.dart'; 

class TopScreen extends StatefulWidget {
  const TopScreen({super.key});

  @override
  State<TopScreen> createState() => _TopScreenState();
}

class _TopScreenState extends State<TopScreen> {
  List<Map<String, dynamic>> topArticles = [];
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();

  String selectedCategory = 'All';
  String selectedTimeframe = 'month';

  List<String> activeCategories = ['All', 'Artificial Intelligence', 'Computer Science', 'Neuroscience', 'Longevity and Cell Biology'];

  final List<String> allAvailableCategories = [
    'Artificial Intelligence', 'Computer Science', 'Software Engineering',
    'Cryptography and Security', 'General Physics', 'Astrophysics', 'Mathematics',
    'Quantitative Biology', 'Neuroscience', 'Genetics and Genomics',
    'Longevity and Cell Biology', 'Economics', 'Computer Graphics', 
    'Robotics', 'Quantitative Finance', 'Quantum Physics', 
    'Systems and Control', 'Data Structures and Algorithms'
  ];
  
  final Map<String, String> timeframes = {
    'Week': 'week', 'Month': 'month', 'Year': 'year',
    '3 Years': '3years', '5 Years': '5years', 'All Time': 'all'
  };

  @override
  void initState() {
    super.initState();
    fetchTopArticles();
  }

  Future<void> fetchTopArticles() async {
    setState(() => isLoading = true);
    final String queryText = searchController.text.trim();
    
    try {
      final results = await ArxivService.fetchTopArticles(
        selectedCategory,
        selectedTimeframe,
        queryText
      );
      setState(() {
        topArticles = results;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> toggleLike(int index) async {
    final article = topArticles[index];
    final int articleId = article['id'];
    final int currentStatus = article['is_saved'];

    setState(() {
      topArticles[index]['is_saved'] = currentStatus == 1 ? 0 : 1;
    });

    try {
      await DatabaseService.instance.toggleSave(articleId, currentStatus);
    } catch (e) {
      setState(() {
        topArticles[index]['is_saved'] = currentStatus;
      });
    }
  }

  void shareArticle(Map<dynamic, dynamic> article) {
    final String text = 
      'Confira este artigo no Article Scroller:\n\n'
      '${article['title']}\n'
      'Autor: ${article['author']}\n\n'
      'Leia mais em: ${article['source']}';
    
    Share.share(text);
  }

  String formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'Unknown date';
    try {
      final DateTime date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) { 
      return 'Invalid date'; 
    }
  }

  void showCategoryManager() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Your Topics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: allAvailableCategories.map((cat) => CheckboxListTile(
                title: Text(cat, style: const TextStyle(color: Colors.white70)),
                value: activeCategories.contains(cat),
                activeColor: Colors.deepPurpleAccent,
                onChanged: (val) {
                  setDialogState(() {
                    val == true ? activeCategories.add(cat) : activeCategories.remove(cat);
                  });
                },
              )).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () { 
                Navigator.pop(context); 
                setState(() {}); 
                fetchTopArticles(); 
              },
              child: const Text('Ok', style: TextStyle(color: Colors.deepPurpleAccent)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.black, elevation: 0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => fetchTopArticles(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ...activeCategories.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: selectedCategory == cat,
                    onSelected: (val) { if (val) { setState(() => selectedCategory = cat); fetchTopArticles(); } },
                  ),
                )),
                ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Topics'), onPressed: showCategoryManager),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: timeframes.entries.map((e) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(e.key, style: const TextStyle(fontSize: 12)),
                  selected: selectedTimeframe == e.value,
                  onSelected: (val) { if (val) { setState(() => selectedTimeframe = e.value); fetchTopArticles(); } },
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: topArticles.length,
                    itemBuilder: (context, index) => buildArticleCard(context, index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildArticleCard(BuildContext context, int index) {
    final article = topArticles[index];
    final bool isLiked = article['is_saved'] == 1;

    String version = "v1";
    if (article['source'] != null && article['source'].toString().contains('v')) {
      version = "v${article['source'].toString().split('v').last}";
    }

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    article['category'].toString().toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Rank #${index + 1}',
                    style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                const Spacer(),
                Text(formatDate(article['published_date']), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Text(article['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, height: 1.3)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.deepPurpleAccent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    article['author'], 
                    style: TextStyle(color: Colors.deepPurple[200], fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  version,
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white70),
                  onPressed: () => shareArticle(article),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => toggleLike(index),
                  icon: Icon(isLiked ? Icons.bookmark : Icons.bookmark_border, color: isLiked ? Colors.deepPurpleAccent : Colors.white70),
                  label: Text(isLiked ? 'Saved' : 'Save', style: TextStyle(color: isLiked ? Colors.deepPurpleAccent : Colors.white70)),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderScreen(article: article))),
                  child: const Text('Read'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}