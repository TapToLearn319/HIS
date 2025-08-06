import 'package:flutter/material.dart';

import '../../sidebar_menu.dart';
import '../login.dart';
import 'game/presenter_game_page.dart';
import 'home/presenter_home_page.dart';
import 'quiz/presenter_quiz_page.dart';
import 'setting/presenter_setting_page.dart';
import 'tools/presenter_tools_page.dart';

class PresenterMainPage extends StatefulWidget {
  const PresenterMainPage({super.key});

  @override
  State<PresenterMainPage> createState() => _PresenterMainPageState();
}

class _PresenterMainPageState extends State<PresenterMainPage> {
  String selectedCategory = 'All';

  final List<String> categories = [
    'All',
    'Attention',
    'Discussion',
    'Presentation',
    'Drawing lots',
    'Tools',
  ];

  final List<Map<String, String>> items = [
    {
      'name': 'Timer',
      'category': 'Attention',
      'desc': 'Manage time effectively',
    },
    {
      'name': 'Debate',
      'category': 'Discussion',
      'desc': 'Engage in thoughtful discussions',
    },
    {
      'name': 'Board',
      'category': 'Presentation',
      'desc': 'Present visually with a digital board',
    },
    {
      'name': 'Random Pick',
      'category': 'Drawing lots',
      'desc': 'Pick random students',
    },
    {'name': 'Music', 'category': 'Tools', 'desc': 'Play background music'},
    {
      'name': 'Reward',
      'category': 'Attention',
      'desc': 'Motivate with instant rewards',
    },
  ];

  List<Map<String, String>> get filteredItems =>
      selectedCategory == 'All'
          ? items
          : items
              .where((item) => item['category'] == selectedCategory)
              .toList();

  Color getCategoryColor(String category) {
    switch (category) {
      case 'Attention':
        return Colors.indigo;
      case 'Discussion':
        return Colors.orange;
      case 'Presentation':
        return Colors.redAccent;
      case 'Drawing lots':
        return Colors.teal;
      case 'Tools':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      selectedIndex: 1,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Class : 3B\nMathematics',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        decoration: TextDecoration.none,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    categories.map((category) {
                      final isSelected = selectedCategory == category;
                      return GestureDetector(
                        onTap: () {
                          setState(() => selectedCategory = category);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 20,
                                color: isSelected ? Colors.black : Colors.grey,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            if (isSelected)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                height: 2,
                                width: 30,
                                color: Colors.black,
                              ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                selectedCategory,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2E3A59),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Text(
                'Select the recipe you want. or explanation by related categories',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.all(12),
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3 / 4.5,
                children:
                    filteredItems.map((item) {
                      final color = getCategoryColor(item['category']!);
                      return Card(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: color, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.topRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    item['category']!,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Center(
                                child: Icon(
                                  Icons.apps,
                                  size: 36,
                                  color: Colors.black12,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                item['name']!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                item['desc']!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
