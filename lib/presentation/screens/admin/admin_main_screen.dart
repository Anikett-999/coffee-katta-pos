import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_drawer.dart';
import '../shared/home_screen.dart';

import 'reports/reports_dashboard_screen.dart';
import 'menu/menu_management_screen.dart';
import 'tables/table_management_screen.dart';
import '../../../core/app_theme.dart';
import '../shared/profile_screen.dart';
import '../../widgets/global/editorial_background.dart';
import '../../widgets/global/coffee_katta_brand_badge.dart';

class AdminMainScreen extends ConsumerStatefulWidget {
  const AdminMainScreen({super.key});

  @override
  ConsumerState<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends ConsumerState<AdminMainScreen> {
  int _selectedIndex = 0;
  bool _isBottomBarVisible = true;

  final List<Widget> _screens = [
    const OperationalHomeScreen(useShell: true),
    const ReportsDashboardScreen(useShell: true),
    const MenuManagementScreen(useShell: true),
    const TableManagementScreen(useShell: true),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String get _currentTabBadgeLabel {
    switch (_selectedIndex) {
      case 1:
        return 'REPORTS & ANALYTICS';
      case 2:
        return 'MENU CATALOG';
      case 3:
        return 'TABLE MANAGEMENT';
      case 0:
      default:
        return 'TABLES';
    }
  }

  IconData get _currentTabBadgeIcon {
    switch (_selectedIndex) {
      case 1:
        return Icons.analytics_rounded;
      case 2:
        return Icons.restaurant_menu_rounded;
      case 3:
        return Icons.tune_rounded;
      case 0:
      default:
        return Icons.table_restaurant_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF382012),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      tooltip: 'Menu',
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: CoffeeKattaBrandBadge(),
                  ),
                  if (MediaQuery.of(context).size.width >= 600) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_currentTabBadgeIcon, color: AppTheme.warmAmber, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            _currentTabBadgeLabel,
                            style: GoogleFonts.epilogue(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  IconButton(
                    icon: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 28),
                    tooltip: 'Profile',
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: GestureDetector(
        onTap: () {
          if (_isBottomBarVisible) {
            setState(() => _isBottomBarVisible = false);
          }
        },
        behavior: HitTestBehavior.translucent,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              if (notification.scrollDelta! > 10 && _isBottomBarVisible) {
                setState(() => _isBottomBarVisible = false);
              } else if (notification.scrollDelta! < -10 && !_isBottomBarVisible) {
                setState(() => _isBottomBarVisible = true);
              }
            }
            return false;
          },
          child: EditorialBackground(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: _isBottomBarVisible ? kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom : 0,
        child: Wrap(
          children: [
            InkWell(
              onTap: () {
                if (!_isBottomBarVisible) {
                  setState(() => _isBottomBarVisible = true);
                }
              },
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  _onItemTapped(index);
                  // Optionally keep it visible after a tap
                  setState(() => _isBottomBarVisible = true);
                },
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppTheme.maroon,
                unselectedItemColor: AppTheme.textDark.withValues(alpha: 0.45),
                selectedLabelStyle: GoogleFonts.epilogue(
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  letterSpacing: 0.2,
                ),
                unselectedLabelStyle: GoogleFonts.epilogue(
                  fontWeight: FontWeight.w600,
                  fontSize: 10.5,
                ),
                showUnselectedLabels: true,
                backgroundColor: Colors.white,
                elevation: 8,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.table_restaurant_rounded),
                    label: 'Tables',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.analytics_rounded),
                    label: 'Reports',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.restaurant_menu_rounded),
                    label: 'Menu',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.tune_rounded),
                    label: 'Manage Tables',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
