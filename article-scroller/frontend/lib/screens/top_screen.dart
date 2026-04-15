import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart'; // 🟢 Import do pacote de share
import '../main.dart'; 

class TopScreen extends StatefulWidget {
  const TopScreen({super.key});

  @override
  State<TopScreen> createState() => _TopScreenState();
}

class _TopScreenState extends State<TopScreen> {
  List<dynamic> _topArticles = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'Todas';
  String _selectedTimeframe = 'month';

  List<String> _activeCategories = ['Todas', 'Inteligência Artificial', 'Ciência da Computação'];

  final List<String> _allAvailableCategories = [
    'Inteligência Artificial', 'Ciência da Computação', 'Engenharia de Software',
    'Criptografia e Segurança', 'Física Geral', 'Astrofísica', 'Matemática',
    'Biologia Quantitativa', 'Neurociência', 'Genética e Genômica',
    'Longevidade e Biologia Celular', 'Economia'
  ];
  
  final Map<String, String> _timeframes = {
    'Semana': 'week', 'Mês': 'month', 'Ano': 'year',
    '3 Anos': '3years', '5 Anos': '5years', 'Sempre': 'all'
  };

  @override
  void initState() {
    super.initState();
    _fetchTopArticles();
  }

  Future<void> _fetchTopArticles() async {
    setState(() => _isLoading = true);
    final String queryText = _searchController.text.trim();
    try {
      final url = Uri.parse(
          'http://localhost:8000/api/top?category=$_selectedCategory&timeframe=$_selectedTimeframe&q=$queryText');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _topArticles = json.decode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 🟢 Lógica de Salvar (Conversa com o Backend)
  Future<void> _toggleLike(int index) async {
    final article = _topArticles[index];
    final int articleId = article['id'];
    final bool isCurrentlySaved = article['is_saved'] == 1;

    setState(() {
      _topArticles[index]['is_saved'] = isCurrentlySaved ? 0 : 1;
    });

    try {
      await http.post(Uri.parse('http://localhost:8000/api/articles/$articleId/toggle-save'));
    } catch (e) {
      setState(() {
        _topArticles[index]['is_saved'] = isCurrentlySaved ? 1 : 0;
      });
    }
  }

  // 🟢 Lógica de Compartilhar
  void _shareArticle(Map<dynamic, dynamic> article) {
    final String text = 
      'Confira este artigo no Article Scroller:\n\n'
      '${article['title']}\n'
      'Autor: ${article['author']}\n\n'
      'Leia mais em: ${article['source']}';
    
    Share.share(text);
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'Data desconhecida';
    try {
      final DateTime date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) { return 'Data inválida'; }
  }

  void _showCategoryManager() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Seus Tópicos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _allAvailableCategories.map((cat) => CheckboxListTile(
                title: Text(cat, style: const TextStyle(color: Colors.white70)),
                value: _activeCategories.contains(cat),
                activeColor: Colors.deepPurpleAccent,
                onChanged: (val) {
                  setDialogState(() {
                    val == true ? _activeCategories.add(cat) : _activeCategories.remove(cat);
                  });
                },
              )).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); setState(() {}); _fetchTopArticles(); },
              child: const Text('Concluído', style: TextStyle(color: Colors.deepPurpleAccent)),
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
      appBar: AppBar(title: const Text('Descobrir', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.black, elevation: 0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Pesquisar...',
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _fetchTopArticles(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ..._activeCategories.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (val) { if (val) { setState(() => _selectedCategory = cat); _fetchTopArticles(); } },
                  ),
                )),
                ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Tópicos'), onPressed: _showCategoryManager),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _timeframes.entries.map((e) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(e.key, style: const TextStyle(fontSize: 12)),
                  selected: _selectedTimeframe == e.value,
                  onSelected: (val) { if (val) { setState(() => _selectedTimeframe = e.value); _fetchTopArticles(); } },
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _topArticles.length,
                    itemBuilder: (context, index) => _buildArticleCard(context, index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, int index) {
    final article = _topArticles[index];
    final bool isLiked = article['is_saved'] == 1;

    // Extrai a versão da URL de forma segura para não dar crash se for nula
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
                // 🟢 TAG DE TÓPICO/CATEGORIA
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
                // 🟢 TAG DE RANKING
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
                // 📅 DATA
                Text(_formatDate(article['published_date']), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            
            // 📝 TÍTULO
            Text(article['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, height: 1.3)),
            const SizedBox(height: 8),
            
            // 👤 AUTOR E VERSÃO
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
            
            // 🛠️ BOTÕES DE AÇÃO COMPLETOS (Compartilhar, Salvar, Ler)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white70),
                  onPressed: () => _shareArticle(article),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _toggleLike(index),
                  icon: Icon(isLiked ? Icons.bookmark : Icons.bookmark_border, color: isLiked ? Colors.deepPurpleAccent : Colors.white70),
                  label: Text(isLiked ? 'Salvo' : 'Salvar', style: TextStyle(color: isLiked ? Colors.deepPurpleAccent : Colors.white70)),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReaderScreen(article: article))),
                  child: const Text('Ler'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}