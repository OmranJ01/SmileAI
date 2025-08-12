import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/app_state.dart';
import '../../models/articles.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  _DiscoverScreenState createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasMarkedAsRead = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchCategory = '';
  bool _searchByCategoryOnly = false; // <-- Toggle state

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markArticleNotificationsAsRead();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _markArticleNotificationsAsRead() async {
    if (_hasMarkedAsRead) return;
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      await appState.markArticleNotificationsAsRead();
      _hasMarkedAsRead = true;
    } catch (e) {
      print('❌ Error marking article notifications as read: $e');
    }
  }

  Future<void> _handleRefresh() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      await appState.fetchArticles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh articles'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
   Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    final filteredArticles = _searchCategory.isEmpty
        ? appState.articles
        : appState.articles.where((article) =>
            _searchByCategoryOnly
                ? article.category.toLowerCase().contains(_searchCategory.toLowerCase())
                : (
                    article.category.toLowerCase().contains(_searchCategory.toLowerCase()) ||
                    article.title.toLowerCase().contains(_searchCategory.toLowerCase())
                  )
          ).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Health',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          // Search bar at the top
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: _searchByCategoryOnly
                  ? 'Search by category'
                  : 'Search by category or name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              prefixIcon: Icon(Icons.search),
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                _searchCategory = value.trim();
              });
            },
          ),
          // Toggle switch below the search bar
          Row(
            children: [
              Switch(
                value: _searchByCategoryOnly,
                onChanged: (val) {
                  setState(() {
                    _searchByCategoryOnly = val;
                  });
                },
              ),
              Text('Category only'),
            ],
          ),
          SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'For you'),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: ListView(
                    physics: AlwaysScrollableScrollPhysics(),
                    children: [
                      if (appState.isLoading)
                        Center(child: CircularProgressIndicator())
                      else if (filteredArticles.isEmpty)
                        Center(child: Text('No articles found for this category'))
                      else
                        ...filteredArticles.map((article) =>
                          ArticleListItem(
                            title: article.title,
                            subtitle: article.category,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ArticleDetailScreen(article: article),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}