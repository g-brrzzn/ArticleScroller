import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'screens/top_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
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

// 📖 Reader Mode (Leitura Limpa)
class ReaderScreen extends StatefulWidget {
  final Map<dynamic, dynamic> article;
  const ReaderScreen({super.key, required this.article});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  String _content = "";
  bool _isFullMode = false;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _content = widget.article['content'];
  }

  Future<void> _loadFullArticle() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(
          'http://localhost:8000/api/articles/full-text?source_url=${widget.article['source']}'));
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _content = data['content'] ?? "Erro ao extrair texto.";
          _isFullMode = true;
          _isLoading = false;
        });
        // Scroll para o topo para começar a leitura
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(_isFullMode ? "Artigo Completo" : "Resumo"),
        actions: [
          if (_isFullMode)
            IconButton(
              icon: const Icon(Icons.article_outlined),
              onPressed: () => setState(() {
                _content = widget.article['content'];
                _isFullMode = false;
              }),
            )
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(color: Colors.deepPurpleAccent),
          Expanded(
            child: Markdown(
              controller: _scrollController,
              data: _content,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Colors.white, fontSize: 18, height: 1.6),
                h1: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 24, fontWeight: FontWeight.bold),
                h2: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                code: const TextStyle(backgroundColor: Colors.white10, color: Colors.greenAccent),
              ),
            ),
          ),
          if (!_isFullMode && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.auto_stories, color: Colors.white),
                label: const Text("ATIVAR MODO DE LEITURA COMPLETA"),
                onPressed: _loadFullArticle,
              ),
            ),
        ],
      ),
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
  List<dynamic> _savedArticles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSaved();
  }

  Future<void> _fetchSaved() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/api/saved'));
      if (response.statusCode == 200) {
        setState(() {
          _savedArticles = json.decode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
      // 🟢 Adicionamos o RefreshIndicator para sincronizar os salvos
      body: RefreshIndicator(
        onRefresh: _fetchSaved,
        color: Colors.deepPurpleAccent,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _savedArticles.isEmpty
                ? ListView( // ListView necessário para o RefreshIndicator funcionar em tela vazia
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('Nenhum artigo salvo.', style: TextStyle(color: Colors.white54))),
                    ],
                  )
                : ListView.builder(
                    itemCount: _savedArticles.length,
                    itemBuilder: (context, index) {
                      final article = _savedArticles[index];
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

// 📱 TELA DO FEED
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<dynamic> _articles = [];
  int _offset = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchArticles();
  }

  Future<void> _fetchArticles() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('http://localhost:8000/api/feed?limit=5&offset=$_offset');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _articles.addAll(json.decode(utf8.decode(response.bodyBytes)));
          _offset += 5;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(int index) async {
    final article = _articles[index];
    final int articleId = article['id'];
    final bool isCurrentlySaved = article['is_saved'] == 1;

    setState(() => _articles[index]['is_saved'] = isCurrentlySaved ? 0 : 1);

    await http.post(Uri.parse('http://localhost:8000/api/articles/$articleId/toggle-save'));
  }

  @override
  Widget build(BuildContext context) {
    if (_articles.isEmpty && _isLoading) return const Center(child: CircularProgressIndicator());
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _articles.length,
      onPageChanged: (i) => i >= _articles.length - 2 ? _fetchArticles() : null,
      itemBuilder: (context, index) => _buildArticlePage(index),
    );
  }

  Widget _buildArticlePage(int index) {
    final article = _articles[index];
    final bool isLiked = article['is_saved'] == 1;

    return GestureDetector(
      onDoubleTap: () => _toggleLike(index),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.only(left: 24, right: 80, top: 60, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(article['author'], style: const TextStyle(color: Colors.deepPurpleAccent)),
                const SizedBox(height: 20),
                Expanded(
                  child: Text(
                    article['content'],
                    maxLines: 12,
                    overflow: TextOverflow.ellipsis, // Corta o texto para instigar a leitura completa
                    style: const TextStyle(fontSize: 17, height: 1.5, color: Colors.white70),
                  ),
                ),
                // 🟢 BOTÃO PARA ABRIR LEITURA COMPLETA
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ReaderScreen(article: article)),
                    );
                  },
                  child: const Text("Continuar lendo..."),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.white),
                  onPressed: () => _toggleLike(index),
                ),
                const Text("Salvar", style: TextStyle(fontSize: 12)),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  onPressed: () {
                    // 🟢 Agora funciona de verdade!
                    Share.share(
                      'Olha este artigo no Article Scroller: ${article['title']}\n\n'
                      'Leia aqui: ${article['source']}'
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}