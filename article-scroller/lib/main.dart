import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'screens/top_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/database_service.dart';
import 'services/arxiv_service.dart';
import 'package:translator/translator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ArticleScrollerApp());
}

class ArticleScrollerApp extends StatelessWidget {
  const ArticleScrollerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Article Scroller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18, height: 1.6, color: Colors.white),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  
  final List<Widget> screens = [
    const FeedScreen(),
    const TopScreen(),
    const SavedScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex, 
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.white54,
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.swipe_up_rounded), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Library'),
        ],
      ),
    );
  }
}

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Map<String, dynamic>> savedArticles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSaved();
  }

  Future<void> fetchSaved() async {
    setState(() => isLoading = true);
    try {
      final results = await DatabaseService.instance.getSavedArticles();
      setState(() {
        savedArticles = results;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: fetchSaved,
        color: Colors.deepPurpleAccent,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : savedArticles.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('No saved articles.', style: TextStyle(color: Colors.white54))),
                    ],
                  )
                : ListView.builder(
                    itemCount: savedArticles.length,
                    itemBuilder: (context, index) {
                      final article = savedArticles[index];
                      return ListTile(
                        leading: const Icon(Icons.article_outlined, color: Colors.deepPurpleAccent),
                        title: Text(article['title'], maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(article['author'], style: const TextStyle(color: Colors.white54)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ReaderScreen(article: article)),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}

class ReaderScreen extends StatefulWidget {
  final Map<dynamic, dynamic> article;
  const ReaderScreen({super.key, required this.article});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  String contentText = "";
  bool isFullMode = false;
  bool isLoading = false;
  final ScrollController scrollController = ScrollController();

  final GoogleTranslator translator = GoogleTranslator();
  bool isTranslating = false;
  bool isTranslated = false;
  String originalAbstract = "";
  String translatedAbstract = "";
  String originalFullText = "";
  String translatedFullText = "";

  bool isSimplifying = false;
  bool isSimplified = false;
  String simplifiedAbstract = "";
  String simplifiedFullText = "";

  @override
  void initState() {
    super.initState();
    originalAbstract = widget.article['content'];
    contentText = originalAbstract;
  }

  Future<void> loadFullArticle() async {
    setState(() => isLoading = true);
    try {
      final String? fullContent = await ArxivService.fetchFullText(widget.article['source']);
      
      setState(() {
        originalFullText = fullContent ?? "Error loading full text.";
        contentText = originalFullText;
        isFullMode = true;
        isTranslated = false;
        isSimplified = false;
        isLoading = false;
      });
      
      if (scrollController.hasClients) {
        scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> toggleTranslation() async {
    if (isSimplified) {
       setState(() { 
         isSimplified = false; 
         contentText = isFullMode ? originalFullText : originalAbstract; 
       });
    }

    if (isTranslated) {
      setState(() {
        contentText = isFullMode ? originalFullText : originalAbstract;
        isTranslated = false;
      });
      return;
    }

    setState(() => isTranslating = true);

    try {
      String targetLang = Platform.localeName.split('_')[0]; 
      
      if (targetLang == 'en') {
        setState(() => isTranslating = false);
        return; 
      }

      if (isFullMode) {
        if (translatedFullText.isEmpty) {
          var translation = await translator.translate(originalFullText, to: targetLang);
          translatedFullText = translation.text;
        }
        setState(() { contentText = translatedFullText; isTranslated = true; });
      } else {
        if (translatedAbstract.isEmpty) {
          var translation = await translator.translate(originalAbstract, to: targetLang);
          translatedAbstract = translation.text;
        }
        setState(() { contentText = translatedAbstract; isTranslated = true; });
      }
    } catch (e) {
    } finally {
      setState(() => isTranslating = false);
    }
  }

  Future<void> _showAiConfigDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentKey = prefs.getString('gemini_api_key') ?? '';
    final currentModel = prefs.getString('gemini_model_name') ?? 'gemini-2.5-flash';
    
    final TextEditingController keyController = TextEditingController(text: currentKey);
    final TextEditingController modelController = TextEditingController(text: currentModel);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("AI Configuration", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "API Key",
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: keyController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Paste your API Key here...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Model Version",
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: modelController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
            onPressed: () async {
              final newKey = keyController.text.trim();
              final newModel = modelController.text.trim();
              if (newKey.isNotEmpty && newModel.isNotEmpty) {
                await prefs.setString('gemini_api_key', newKey);
                await prefs.setString('gemini_model_name', newModel);
                if (context.mounted) Navigator.pop(context, {'key': newKey, 'model': newModel});
              }
            },
            child: const Text("Save & Summarize"),
          )
        ],
      ),
    ).then((result) {
      if (result != null && result is Map<String, String>) {
        _runAiSummarization(result['key']!, result['model']!);
      }
    });
  }

  Future<void> toggleSimplify() async {
    if (isTranslated) {
      setState(() { 
        isTranslated = false; 
        contentText = isFullMode ? originalFullText : originalAbstract; 
      });
    }

    if (isSimplified) {
      setState(() {
        contentText = isFullMode ? originalFullText : originalAbstract;
        isSimplified = false;
      });
      return;
    }

    await _showAiConfigDialog();
  }

  Future<void> _runAiSummarization(String apiKey, String modelName) async {
    setState(() => isSimplifying = true);

    try {
      String targetLang = Platform.localeName.split('_')[0]; 
      String textToAnalyze = isFullMode ? originalFullText : originalAbstract;
      
      String prompt = """
        Read the academic text below and create a clear, fluid, and structured summary.
        Instead of using bullet points, write cohesive paragraphs that form a logical narrative.
        
        Structure the summary using the following three Markdown headers:
        ### Context & Problem
        (Explain the background and the specific challenge being addressed in 1-2 short paragraphs).
        
        ### The Approach
        (Describe the proposed solution or methodology clearly in 1 paragraph).
        
        ### Key Findings
        (Summarize the main results and their overall impact in 1 paragraph).
        
        STRICT RULES:
        1. DO NOT use bullet points or numbered lists. Use standard paragraphs.
        2. DO NOT use conversational filler, greetings, or introductory phrases. Start directly with the first header.
        3. DO NOT address the reader directly (avoid words like "you", "imagine").
        4. Keep the text engaging but objective and professional.
        
        CRITICAL: Your final response MUST be written in the ISO 639-1 language code '$targetLang'.
        
        Academic text:
        $textToAnalyze
      """;

      final model = GenerativeModel(model: modelName, apiKey: apiKey);
      final response = await model.generateContent([Content.text(prompt)]);

      if (response.text != null) {
        if (isFullMode) {
          simplifiedFullText = response.text!;
          setState(() { contentText = simplifiedFullText; isSimplified = true; });
        } else {
          simplifiedAbstract = response.text!;
          setState(() { contentText = simplifiedAbstract; isSimplified = true; });
        }
      }
    } catch (e) {
      print("GEMINI_ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("AI Error: ${e.toString()}"), 
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => isSimplifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(isFullMode ? "Full Article" : "Abstract", style: const TextStyle(fontSize: 18)),
        actions: [
          if (isTranslating)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
          else
            IconButton(
              icon: Icon(isTranslated ? Icons.translate : Icons.g_translate),
              color: isTranslated ? Colors.blueAccent : Colors.white,
              tooltip: "Translate",
              onPressed: toggleTranslation,
            ),
            
          if (isSimplifying)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent))))
          else
            IconButton(
              icon: Icon(isSimplified ? Icons.auto_awesome : Icons.auto_awesome_outlined),
              color: isSimplified ? Colors.deepPurpleAccent : Colors.white,
              tooltip: "Explain with AI",
              onPressed: toggleSimplify,
            ),

          if (isFullMode)
            IconButton(
              icon: const Icon(Icons.article_outlined),
              tooltip: "Back to Abstract",
              onPressed: () => setState(() {
                contentText = originalAbstract;
                isFullMode = false;
                isTranslated = false;
                isSimplified = false;
              }),
            )
        ],
      ),
      body: Column(
        children: [
          if (isLoading) const LinearProgressIndicator(color: Colors.deepPurpleAccent),
          Expanded(
            child: Markdown(
              controller: scrollController,
              data: contentText,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Colors.white, fontSize: 18, height: 1.6),
                h1: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 24, fontWeight: FontWeight.bold),
                h2: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                h3: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                code: const TextStyle(backgroundColor: Colors.white10, color: Colors.greenAccent),
                listBullet: const TextStyle(color: Colors.deepPurpleAccent),
              ),
            ),
          ),
          if (!isFullMode && !isLoading)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.auto_stories, color: Colors.white),
                label: const Text("READ FULL ARTICLE"),
                onPressed: loadFullArticle,
              ),
            ),
        ],
      ),
    );
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> articles = [];
  bool isLoading = false;
  final ScrollController scrollController = ScrollController();
  
  final List<String> allCategories = [
    'Artificial Intelligence', 'Computer Science', 'Software Engineering',
    'Cryptography and Security', 'General Physics', 'Astrophysics', 'Mathematics',
    'Quantitative Biology', 'Neuroscience', 'Genetics and Genomics',
    'Longevity and Cell Biology', 'Economics', 'Computer Graphics', 
    'Robotics', 'Quantitative Finance', 'Quantum Physics', 
    'Systems and Control', 'Data Structures and Algorithms'
  ];

  @override
  void initState() {
    super.initState();
    fetchFeed();
    scrollController.addListener(onScroll);
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void onScroll() {
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
      fetchFeed();
    }
  }

  void showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> fetchFeed() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      allCategories.shuffle();
      final selectedCategories = allCategories.take(3).toList();
      
      List<Map<String, dynamic>> newArticles = [];
      
      for (int i = 0; i < selectedCategories.length; i++) {
        String category = selectedCategories[i];
        final results = await ArxivService.fetchTopArticles(category, 'week', '');
        newArticles.addAll(results);
        
        if (i < selectedCategories.length - 1) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      newArticles.shuffle();

      setState(() {
        articles.addAll(newArticles);
        isLoading = false;
      });
    } catch (e) {
      showErrorMessage(e.toString().replaceAll("Exception: ", ""));
      setState(() => isLoading = false);
    }
  }

  Future<void> toggleLike(int index) async {
    final article = articles[index];
    final int currentStatus = article['is_saved'] ?? 0;

    setState(() {
      articles[index]['is_saved'] = currentStatus == 1 ? 0 : 1;
    });

    try {
      if (article['id'] == null) {
        await DatabaseService.instance.insertArticle(article);
        final dbData = await DatabaseService.instance.getArticleBySource(article['source']);
        if (dbData != null) {
          article['id'] = dbData['id'];
        }
      }
      
      if (article['id'] != null) {
        await DatabaseService.instance.toggleSave(article['id'], currentStatus);
      }
    } catch (e) {
      setState(() {
        articles[index]['is_saved'] = currentStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }

    if (articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("No articles found.", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => articles.clear());
                fetchFeed();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
            )
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          articles.clear();
        });
        await fetchFeed();
      },
      color: Colors.deepPurpleAccent,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16.0),
        itemCount: articles.length + 1,
        itemBuilder: (context, index) {
          if (index == articles.length) {
            return isLoading 
                ? const Padding(
                    padding: EdgeInsets.all(16.0), 
                    child: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
                  ) 
                : const SizedBox.shrink();
          }

          final article = articles[index];
          final bool isLiked = (article['is_saved'] == 1);
          
          String version = "v1";
          if (article['source'] != null && article['source'].toString().contains('v')) {
            version = "v${article['source'].toString().split('v').last}";
          }

          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
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
                          color: Colors.deepPurpleAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department, color: Colors.deepPurpleAccent, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              article['category'].toString().toUpperCase(),
                              style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        version,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article['title'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "By ${article['author']}",
                    style: TextStyle(fontSize: 14, color: Colors.deepPurple[200]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article['content'],
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            iconSize: 24,
                            icon: Icon(isLiked ? Icons.bookmark : Icons.bookmark_border, color: isLiked ? Colors.deepPurpleAccent : Colors.white54),
                            onPressed: () => toggleLike(index),
                          ),
                          IconButton(
                            iconSize: 24,
                            icon: const Icon(Icons.share_outlined, color: Colors.white54),
                            onPressed: () {
                              Share.share('Check out this trending article: ${article['title']}\n\nRead here: ${article['source']}');
                            },
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderScreen(article: article))),
                        child: const Text('Read Abstract'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}