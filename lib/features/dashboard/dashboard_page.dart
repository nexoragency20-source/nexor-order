import 'package:flutter/material.dart';

import 'dashboard_home_page.dart';

import '../orders/orders_page.dart';
import '../products/products_page.dart';
import '../suppliers/suppliers_page.dart';
import '../purchases/purchases_page.dart';
import '../finance/finance_page.dart';
import '../returns/returns_page.dart';
import '../customers/customers_page.dart';
import '../conversations/conversations_page.dart';
import '../ai/ai_assistant_page.dart';
import '../settings/settings_page.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;
  final String storeName;
  final String userName;

  const DashboardPage({
    super.key,
    required this.onToggleTheme,
    required this.onLogout,
    required this.storeName,
    required this.userName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  late String _currentStoreName;
  late String _currentUserName;

  @override
  void initState() {
    super.initState();
    _currentStoreName = widget.storeName;
    _currentUserName = widget.userName;
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storeName != widget.storeName) {
      _currentStoreName = widget.storeName;
    }
    if (oldWidget.userName != widget.userName) {
      _currentUserName = widget.userName;
    }
  }

  void _selectSection(int index) {
    if (index < 0 || index > 10) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            isDark: isDark,
            selectedIndex: _selectedIndex,
            onItemSelected: _selectSection,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  isDark: isDark,
                  onToggleTheme: widget.onToggleTheme,
                  onLogout: widget.onLogout,
                  userName: _currentUserName,
                  storeName: _currentStoreName,
                ),
                Expanded(
                  child: _buildSelectedPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 1:
        return const OrdersPage();
      case 2:
        return const ConversationsPage();
      case 3:
        return const CustomersPage();
      case 4:
        return const ProductsPage();
      case 5:
        return const SuppliersPage();
      case 6:
        return const PurchasesPage();
      case 7:
        return const FinancePage();
      case 8:
        return const ReturnsPage();
      case 9:
        return const AiAssistantPage();
      case 10:
        return SettingsPage(
          storeName: _currentStoreName,
          userName: _currentUserName,
          onToggleTheme: widget.onToggleTheme,
          onStoreNameChanged: (value) {
            if (!mounted) return;
            setState(() => _currentStoreName = value);
          },
        );
      case 0:
      default:
        return DashboardHomePage(
          storeName: _currentStoreName,
          onViewAllOrders: () => _selectSection(1),
        );
    }
  }
}

class _Sidebar extends StatelessWidget {
  final bool isDark;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _Sidebar({
    required this.isDark,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: isDark
          ? const Color(0xFF101218)
          : Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6C63FF),
                      Color(0xFF9B94FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEXOR',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'ORDERS',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  title: 'لوحة التحكم',
                  active: selectedIndex == 0,
                  onTap: () => onItemSelected(0),
                ),
                _NavItem(
                  icon: Icons.shopping_bag_rounded,
                  title: 'الطلبات',
                  active: selectedIndex == 1,
                  onTap: () => onItemSelected(1),
                ),
                _NavItem(
                  icon: Icons.chat_bubble_rounded,
                  title: 'المحادثات',
                  active: selectedIndex == 2,
                  onTap: () => onItemSelected(2),
                ),
                _NavItem(
                  icon: Icons.people_alt_rounded,
                  title: 'العملاء',
                  active: selectedIndex == 3,
                  onTap: () => onItemSelected(3),
                ),
                _NavItem(
                  icon: Icons.inventory_2_rounded,
                  title: 'المنتجات',
                  active: selectedIndex == 4,
                  onTap: () => onItemSelected(4),
                ),
                _NavItem(
                  icon: Icons.business_rounded,
                  title: 'الموردون',
                  active: selectedIndex == 5,
                  onTap: () => onItemSelected(5),
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  title: 'المشتريات',
                  active: selectedIndex == 6,
                  onTap: () => onItemSelected(6),
                ),
                _NavItem(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'الصندوق',
                  active: selectedIndex == 7,
                  onTap: () => onItemSelected(7),
                ),
                _NavItem(
                  icon: Icons.assignment_return_rounded,
                  title: 'المرتجعات',
                  active: selectedIndex == 8,
                  onTap: () => onItemSelected(8),
                ),
                _NavItem(
                  icon: Icons.auto_awesome_rounded,
                  title: 'مساعد AI',
                  active: selectedIndex == 9,
                  onTap: () => onItemSelected(9),
                ),
              ],
            ),
          ),

          _NavItem(
            icon: Icons.settings_rounded,
            title: 'الإعدادات',
            active: selectedIndex == 10,
            onTap: () => onItemSelected(10),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF171A23)
                  : const Color(0xFFF4F3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: Color(0xFF6C63FF),
                ),
                SizedBox(height: 10),
                Text(
                  'AI Engine',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'تحليل الطلبات يعمل بشكل تلقائي',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF6C63FF).withValues(alpha: .13)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: active
              ? const Color(0xFF8B84FF)
              : Colors.grey,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;
  final String userName;
  final String storeName;

  const _TopBar({
    required this.isDark,
    required this.onToggleTheme,
    required this.onLogout,
    required this.userName,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: .12),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF151820)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث عن طلب، عميل أو منتج...',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          IconButton(
            onPressed: onToggleTheme,
            icon: Icon(
              isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),

          const SizedBox(width: 4),

          Tooltip(
            message: '$userName • $storeName',
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF9388FF), Color(0xFF5448C9)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .18), width: 1.2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF786BFA).withValues(alpha: .24), blurRadius: 13, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
