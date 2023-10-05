import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:connectivity/connectivity.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class BlogListScreen extends StatefulWidget {
  @override
  _BlogListScreenState createState() => _BlogListScreenState();
}

class _BlogListScreenState extends State<BlogListScreen> {
  bool isLoading = true;

  List<BlogItem> blogItems = [];

  ConnectivityResult _connectionStatus = ConnectivityResult.none;

  @override
  void initState() {
    super.initState();
    isLoading = true;
    fetchData();

    // Initialize connectivity and listen for changes in connection status
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _connectionStatus = result;
      });

      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi) {
        // When online, initiate data loading if it's not already in progress
        if (!isLoading) {
          fetchData();
        }
      }
    });
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true; // Set loading to true when starting data fetch
    });
    final response = await http.get(
      Uri.parse('https://intent-kit-16.hasura.app/api/rest/blogs'),
      headers: {
        'x-hasura-admin-secret':
            '32qR4KmXOIpsGPQKMqEJHGJS27G5s7HdSKO3gdtQd2kv5e852SiYwWNfxkZOBuQ6',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body)['blogs'];
      setState(() {
        blogItems = data.map((item) {
          return BlogItem(
            title: item['title'],
            imageUrl: item['image_url'],
          );
        }).toList();
        isLoading = false;
      });
    } else {
      isLoading = false;
      throw Exception('Failed to load data');
    }
  }

  Future<void> saveOfflineBlog(BlogItem blogItem) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> existingBlogs =
        prefs.getStringList('offline_blogs') ?? [];

    // Check if the blog is already saved
    if (!existingBlogs.contains(jsonEncode(blogItem.toJson()))) {
      blogItem.imageUrl = 'assets/images/off.jpg';
      existingBlogs.add(jsonEncode(blogItem.toJson()));
      await prefs.setStringList('offline_blogs', existingBlogs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _connectionStatus != ConnectivityResult.none;
    if (!isOnline) {
      setState(() {
        isLoading = false;
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Padding(
              padding:
                  EdgeInsets.only(top: 0.0, left: 12.0), // Add padding here
              child: Text('-||- SUBSPACE -||-'),
            ),
            Spacer(), // This will push the search icon to the right
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                // Add your search functionality here
              },
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 8,
        toolbarHeight: 80.0,
      ),
      backgroundColor: Colors.grey[900],
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!isOnline) // Display buttons only when offline
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OfflineBlogsScreen(),
                              ),
                            ); // Navigate to the OfflineBlogsScreen
                          },
                          child: Text('Show Offline'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(16.0),
                    child: ListView.separated(
                      itemCount: blogItems.length,
                      separatorBuilder: (context, index) {
                        return SizedBox(height: 16.0);
                      },
                      itemBuilder: (context, index) {
                        final blogItem = blogItems[index];
                        return GestureDetector(
                          onTap: () {
                            if (isOnline) {
                              // Save the top 5 blogs to offline storage
                              try {
                                Future<void>.delayed(Duration.zero, () async {
                                  // Save the top 5 blogs to offline storage
                                  await saveOfflineBlog(blogItem);
                                });
                              } catch (e) {
                                // Handle any exceptions that occur during the download and save process
                                print('Error saving blog: $e');
                                // Optionally, you can display an error message to the user
                              }
                            }
                            // Navigate to the BlogDetailScreen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BlogDetailScreen(
                                  blogItem: blogItem,
                                  isOnline: isOnline,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: BlogCard(blogItem: blogItem),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class BlogItem {
  final String title;
  String imageUrl;
  final String content; // Remove 'required'

  BlogItem({
    required this.title,
    required this.imageUrl,
    this.content =
        "He is the wealthiest person in the world, with an estimated net worth of US232 billion as of September 2023, according to the Bloomberg Billionaires Index, and 253 billion according to Forbes, primarily from his ownership stakes in both Tesla and SpaceX. CEO and product architect of Tesla, Inc.", // Provide a default value
  });
  BlogItem.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        imageUrl = json['imageUrl'],
        content = json['content'];

  // Method to convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'content': content,
    };
  }
}

class BlogCard extends StatelessWidget {
  final BlogItem blogItem;

  BlogCard({required this.blogItem});

  @override
  Widget build(BuildContext context) {
    final isOnlineImage = blogItem.imageUrl.startsWith('http');
    ImageProvider<Object> backgroundImage;

    if (isOnlineImage) {
      backgroundImage = NetworkImage(blogItem.imageUrl); // Online image
    } else {
      backgroundImage =
          AssetImage(blogItem.imageUrl); // Local asset image when offline
    }
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 16.0), // Add padding around the Column
      child: Column(
        children: [
          // Image
          Container(
            width: MediaQuery.of(context).size.width, // Full screen width
            height: MediaQuery.of(context).size.width *
                0.5, // Maintain aspect ratio
            decoration: BoxDecoration(
              image: DecorationImage(
                image: backgroundImage,
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10.0), // Rounded top-left corner
                topRight: Radius.circular(10.0), // Rounded top-right corner
              ),
            ),
          ),
          SizedBox(height: 16.0),
          // Title Text
          Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Align(
              alignment: Alignment.centerLeft, // Align text to the left
              child: Text(
                blogItem.title,
                style: TextStyle(
                  fontSize: 20.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BlogDetailScreen extends StatelessWidget {
  final BlogItem blogItem;
  final bool isOnline; // Add isOnline parameter

  BlogDetailScreen({
    required this.blogItem,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Row(
          children: [
            Text('SubSpace'),
            Spacer(), // This will push the search icon to the right
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                // Add your search functionality here
              },
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: MediaQuery.of(context).size.width, // Full screen width
              height: MediaQuery.of(context).size.width *
                  0.5, // Maintain aspect ratio
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(blogItem.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 16.0),
            Padding(
              padding: EdgeInsets.only(left: 25.0, top: 16.0, right: 25.0),
              child: Text(
                blogItem.title,
                style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500]),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 25.0, top: 16.0, right: 25.0),
              child: Text(
                blogItem.content,
                style: TextStyle(fontSize: 16.0, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfflineBlogsScreen extends StatefulWidget {
  @override
  _OfflineBlogsScreenState createState() => _OfflineBlogsScreenState();
}

class _OfflineBlogsScreenState extends State<OfflineBlogsScreen> {
  List<BlogItem> offlineBlogs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadOfflineBlogs();
  }

  Future<void> loadOfflineBlogs() async {
    final prefs = await SharedPreferences.getInstance();
    final blogList = prefs.getStringList('offline_blogs');
    if (blogList != null) {
      final blogs = blogList.map((json) {
        final Map<String, dynamic> blogData = jsonDecode(json);
        return BlogItem.fromJson(blogData);
      }).toList();
      setState(() {
        offlineBlogs = blogs;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Offline Blogs'),
        backgroundColor: Colors.transparent,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : offlineBlogs.isEmpty
              ? Center(
                  child: Text('No offline blogs found.'),
                )
              : ListView.builder(
                  itemCount: offlineBlogs.length,
                  itemBuilder: (context, index) {
                    final blogItem = offlineBlogs[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BlogDetailScreen(
                              blogItem: blogItem,
                              isOnline: false, // Indicate that it's offline
                            ),
                          ),
                        );
                      },
                      child: BlogCard(blogItem: blogItem),
                    );
                  },
                ),
    );
  }
}
