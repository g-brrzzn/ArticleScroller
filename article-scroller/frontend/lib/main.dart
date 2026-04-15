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



// 🎛️ CONTROLADOR DE ABAS
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const FeedScreen(),    // Índice 0: Feed
    const TopScreen(),     // Índice 1: Descobrir
    const SavedScreen()    // Índice 2: Biblioteca
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex, 
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.swipe_up_rounded), label: 'Feed'),       // Índice 0
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Descobrir'),           // Índice 1
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Biblioteca'),         // Índice 2
        ],
      ),
    );
  }
}

// 📚 TELA DE SALVOS
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
        title: const Text('Biblioteca', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      Center(child: Text('Nenhum artigo salvo.', style: TextStyle(color: Colors.white54))),
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

  @override
  void initState() {
    super.initState();
    contentText = widget.article['content'];
  }

  Future<void> loadFullArticle() async {
    setState(() => isLoading = true);
    try {
      final String? fullContent = await ArxivService.fetchFullText(widget.article['source']);
      
      setState(() {
        contentText = fullContent ?? "Error loading full text.";
        isFullMode = true;
        isLoading = false;
      });
      
      if (scrollController.hasClients) {
        scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(isFullMode ? "Artigo Completo" : "Resumo"),
        actions: [
          if (isFullMode)
            IconButton(
              icon: const Icon(Icons.article_outlined),
              onPressed: () => setState(() {
                contentText = widget.article['content'];
                isFullMode = false;
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
                code: const TextStyle(backgroundColor: Colors.white10, color: Colors.greenAccent),
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
                label: const Text("ATIVAR MODO DE LEITURA COMPLETA"),
                onPressed: loadFullArticle,
              ),
            ),
        ],
      ),
    );
  }
}

// 📱 TELA DO FEED
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> _articles = [];
  bool _isLoading = false;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }


  Future<void> _fetchFeed() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final newArticles = await ArxivService.fetchTopArticles('Todas', 'month', '');

      newArticles.shuffle();

      setState(() {
        _articles.addAll(newArticles);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _toggleLike(int index) async {
    final article = _articles[index];
    final int currentStatus = article['is_saved'] ?? 0;


    setState(() {
      _articles[index]['is_saved'] = currentStatus == 1 ? 0 : 1;
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
        _articles[index]['is_saved'] = currentStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_articles.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }

    if (_articles.isEmpty) {
      return const Center(child: Text("Nenhum artigo encontrado.", style: TextStyle(color: Colors.white54)));
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (index) {
        if (index == _articles.length - 1) {
          _fetchFeed(); 
        }
      },
      itemCount: _articles.length,
      itemBuilder: (context, index) {
        final article = _articles[index];
        final bool isLiked = (article['is_saved'] == 1);

        return Stack(
          children: [

            Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Color(0xFF1A1A2E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.deepPurpleAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: Text(article['category'].toString().toUpperCase(), style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(height: 20),
                    Text(article['title'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
                    const SizedBox(height: 16),
                    Text("👤 ${article['author']}", style: const TextStyle(fontSize: 16, color: Colors.white70)),
                    const SizedBox(height: 30),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(article['content'], style: const TextStyle(fontSize: 18, color: Colors.white60, height: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      iconSize: 40,
                      icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.redAccent : Colors.white),
                      onPressed: () => _toggleLike(index),
                    ),
                    const SizedBox(height: 20),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.menu_book, color: Colors.white),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderScreen(article: article))),
                    ),
                    const SizedBox(height: 20),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      onPressed: () {
                        Share.share('Olha este artigo no Article Scroller: ${article['title']}\n\nLeia aqui: ${article['source']}');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}