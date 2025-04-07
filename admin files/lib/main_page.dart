import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/individual_data_page.dart';
import 'pages/incentives_page.dart';
import 'pages/orders_page.dart';
import 'pages/analysis_page.dart';
import 'pages/additional_details_page.dart';

class MainPage extends StatefulWidget {
  final String employeeName;
  final String employeePosition;
  final String employeeId;
  
  const MainPage({
    super.key, 
    required this.employeeName,
    required this.employeePosition,
    required this.employeeId,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': 'Dashboard',
      'icon': Icons.dashboard,
    },
    {
      'title': 'Individual Data',
      'icon': Icons.person,
    },
    {
      'title': 'Incentives',
      'icon': Icons.monetization_on,
    },
    {
      'title': 'Orders',
      'icon': Icons.shopping_cart,
    },
    {
      'title': 'Analysis',
      'icon': Icons.analytics,
    },
    {
      'title': 'Additional Details',
      'icon': Icons.more_horiz,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_menuItems[_selectedIndex]['title']),
        backgroundColor: const Color(0xFF2980B9),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Notification action
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Logout action
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Side Navigation
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            extended: MediaQuery.of(context).size.width > 800, // Extended on wide screens
            minExtendedWidth: 200,
            backgroundColor: Colors.white,
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFF2980B9),
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.grey[700],
            ),
            selectedIconTheme: const IconThemeData(
              color: Color(0xFF2980B9),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF2980B9),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (MediaQuery.of(context).size.width > 800) ...[
                    Text(
                      widget.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      widget.employeePosition,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                  ],
                ],
              ),
            ),
            destinations: _menuItems
                .map((item) => NavigationRailDestination(
                      icon: Icon(item['icon']),
                      selectedIcon: Icon(item['icon']),
                      label: Text(item['title']),
                    ))
                .toList(),
          ),
          // Vertical divider
          const VerticalDivider(
            thickness: 1,
            width: 1,
          ),
          // Main content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: const [
                DashboardPage(),
                IndividualDataPage(),
                IncentivesPage(),
                OrdersPage(),
                AnalysisPage(),
                AdditionalDetailsPage(),
              ],
            ),
          ),
        ],
      ),
      // Show drawer on small screens
      drawer: MediaQuery.of(context).size.width < 800
          ? _buildDrawer()
          : null,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF2980B9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Color(0xFF2980B9),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.employeeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.employeePosition,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ..._menuItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return ListTile(
              leading: Icon(
                item['icon'],
                color: _selectedIndex == index ? const Color(0xFF2980B9) : Colors.grey[700],
              ),
              title: Text(
                item['title'],
                style: TextStyle(
                  color: _selectedIndex == index ? const Color(0xFF2980B9) : Colors.grey[700],
                  fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: _selectedIndex == index,
              onTap: () {
                _onItemTapped(index);
                Navigator.pop(context); // Close the drawer
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}