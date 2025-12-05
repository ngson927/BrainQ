import 'package:brainq_app/providers/admin_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final Set<int> _selectedUsers = {};

  String? _selectedRole;
  String? _selectedStatus;
  DateTime? _joinedAfter;
  DateTime? _joinedBefore;


  bool _selectMode = false;

  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchUsers(reset: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _currentPage++;
      _fetchUsers();
    }
  }

  Map<String, String> _buildQueryParams() {
    final Map<String, String> queryParams = {};
    if (_searchQuery.isNotEmpty) queryParams['search'] = _searchQuery;
    if (_selectedRole != null) queryParams['role'] = _selectedRole!;
    if (_selectedStatus != null) queryParams['status'] = _selectedStatus!;
    if (_joinedAfter != null) queryParams['joined_after'] = _joinedAfter!.toIso8601String();
    if (_joinedBefore != null) queryParams['joined_before'] = _joinedBefore!.toIso8601String();
    queryParams['page'] = '$_currentPage';
    queryParams['page_size'] = '$_pageSize';
    return queryParams;
  }

  Future<void> _fetchUsers({bool reset = false}) async {
    if (reset) {
      _currentPage = 1;
      _hasMore = true;
    }
    _isLoadingMore = true;
    final provider = context.read<AdminProvider>();
    await provider.fetchUsers(queryParams: _buildQueryParams());
    if (provider.users.length < _currentPage * _pageSize) _hasMore = false;
    _isLoadingMore = false;
  }

  Future<void> _refresh() async {
    _currentPage = 1;
    _hasMore = true;
    await _fetchUsers(reset: true);
  }

  void _toggleSelection(int userId) {
    setState(() {
      if (_selectedUsers.contains(userId)) {
        _selectedUsers.remove(userId);
      } else {
        _selectedUsers.add(userId);
      }
    });
  }

  Future<void> _bulkAction(String action) async {
    if (_selectedUsers.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Confirm Bulk Action"),
            content: Text("Are you sure you want to $action these users?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final provider = context.read<AdminProvider>();
    await provider.bulkUserAction(_selectedUsers.toList(), action);
    _selectedUsers.clear();
    await _fetchUsers(reset: true);
  }

  Future<void> _updateUserRole(int userId) async {
    final provider = context.read<AdminProvider>();
    final newRole = await showDialog<String>(
      context: context,
      builder: (_) {
        String? selectedRole;
        return AlertDialog(
          title: const Text("Change User Role"),
          content: DropdownButtonFormField<String>(
            items: const [
              DropdownMenuItem(value: "user", child: Text("User")),
              DropdownMenuItem(value: "admin", child: Text("Admin")),
            ],
            onChanged: (val) => selectedRole = val,
            decoration: const InputDecoration(labelText: "Select Role"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(context, selectedRole), child: const Text("Save")),
          ],
        );
      },
    );

    if (newRole != null && newRole.isNotEmpty) {
      await provider.changeUserRole(userId, newRole);
      await _fetchUsers(reset: true);
    }
  }

  Future<void> _showUserDetails(int userId) async {
    final provider = context.read<AdminProvider>();
    final user = await provider.getUserDetail(userId);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(user['username'] ?? 'User Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Email: ${user['email'] ?? '-'}"),
            Text("First Name: ${user['first_name'] ?? '-'}"),
            Text("Last Name: ${user['last_name'] ?? '-'}"),
            Text("Role: ${user['role'] ?? '-'}"),
            Text("Status: ${user['is_active'] == true ? 'Active' : 'Inactive'}"),
            Text("Suspended: ${user['is_suspended'] == true ? 'Yes' : 'No'}"),
            if (user['date_joined'] != null)
              Text("Joined: ${DateFormat.yMd().add_jm().format(DateTime.parse(user['date_joined']))}"),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            String? tempRole = _selectedRole;
            String? tempStatus = _selectedStatus;
            DateTime? tempJoinedAfter = _joinedAfter;
            DateTime? tempJoinedBefore = _joinedBefore;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Filter Users",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: tempRole,
                      decoration: const InputDecoration(labelText: "Role"),
                      items: const [
                        DropdownMenuItem(value: "user", child: Text("User")),
                        DropdownMenuItem(value: "admin", child: Text("Admin")),
                      ],
                      onChanged: (v) => tempRole = v,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: tempStatus,
                      decoration: const InputDecoration(labelText: "Status"),
                      items: const [
                        DropdownMenuItem(value: "active", child: Text("Active")),
                        DropdownMenuItem(value: "suspended", child: Text("Suspended")),
                      ],
                      onChanged: (v) => tempStatus = v,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tempJoinedAfter ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) tempJoinedAfter = picked;
                      },
                      child: Text(tempJoinedAfter != null
                          ? "Joined After: ${DateFormat.yMd().format(tempJoinedAfter)}"
                          : "Joined After"),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tempJoinedBefore ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) tempJoinedBefore = picked;
                      },
                      child: Text(tempJoinedBefore != null
                          ? "Joined Before: ${DateFormat.yMd().format(tempJoinedBefore)}"
                          : "Joined Before"),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedRole = null;
                                _selectedStatus = null;
                                _joinedAfter = null;
                                _joinedBefore = null;
                              });
                              context.read<AdminProvider>().fetchUsers();
                              Navigator.pop(context);
                            },
                            child: const Text("Reset"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedRole = tempRole;
                                _selectedStatus = tempStatus;
                                _joinedAfter = tempJoinedAfter;
                                _joinedBefore = tempJoinedBefore;
                              });
                              Navigator.pop(context);
                              _fetchUsers(reset: true);
                            },
                            child: const Text("Apply"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

@override
Widget build(BuildContext context) {
  return Consumer<AdminProvider>(builder: (context, admin, _) {
    final users = admin.users;
    final loading = admin.loadingUsers && users.isEmpty;

    return Column(
      children: [
        // Top bar: search, filters, select
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Search box
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  onSubmitted: (_) => _fetchUsers(reset: true),
                  decoration: InputDecoration(
                    hintText: "Search users",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery = "";
                              _fetchUsers(reset: true);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Filters button
              OutlinedButton.icon(
                onPressed: _openFilterSheet,
                icon: const Icon(Icons.filter_list),
                label: const Text("Filters"),
              ),
              const SizedBox(width: 8),
              // Bulk select
              _selectMode
                  ? Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _selectedUsers.addAll(users.map((u) => u['id'] as int))),
                          child: const Text("Select All"),
                        ),
                        if (_selectedUsers.isNotEmpty)
                          PopupMenuButton<String>(
                            onSelected: _bulkAction,
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: "suspend", child: Text("Suspend")),
                              PopupMenuItem(value: "activate", child: Text("Activate")),
                              PopupMenuItem(value: "delete", child: Text("Delete")),
                            ],
                            icon: const Icon(Icons.more_vert),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: "Cancel Selection",
                          onPressed: () => setState(() {
                            _selectMode = false;
                            _selectedUsers.clear();
                          }),
                        ),
                      ],
                    )
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.select_all),
                      label: const Text("Select"),
                      onPressed: () => setState(() => _selectMode = true),
                    ),
            ],
          ),
        ),

        // User list
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: users.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == users.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final user = users[index];
                      final userId = user['id'];
                      if (userId == null) return const SizedBox.shrink();

                      final isSelected = _selectedUsers.contains(userId);

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: isSelected ? Colors.blue.withValues(alpha:0.1) : null,
                        child: ListTile(
                          onTap: () => _selectMode ? _toggleSelection(userId) : _showUserDetails(userId),
                          onLongPress: () => _toggleSelection(userId),
                          leading: _selectMode
                              ? Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(userId))
                              : CircleAvatar(child: Text(user['username']?[0].toUpperCase() ?? '?')),
                          title: Text(user['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(user['email'] ?? '', style: const TextStyle(fontSize: 12)),
                              Chip(
                                label: Text(
                                  (user['is_active'] == true && user['is_suspended'] != true)
                                      ? "Active"
                                      : "Suspended",
                                ),
                                backgroundColor: (user['is_active'] == true && user['is_suspended'] != true)
                                    ? Colors.green.withValues(alpha:0.2)
                                    : Colors.red.withValues(alpha:0.2),
                                labelStyle: TextStyle(
                                  color: (user['is_active'] == true && user['is_suspended'] != true)
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),

                          trailing: !_selectMode
                              ? PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    switch (action) {
                                      case "suspend":
                                        await admin.suspendUser(userId);
                                        break;
                                      case "activate":
                                        await admin.activateUser(userId);
                                        break;
                                      case "delete":
                                        final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                title: const Text("Confirm Delete"),
                                                content: Text("Are you sure you want to delete ${user['username']}?"),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
                                                ],
                                              ),
                                            ) ?? false;
                                        if (confirmed) await admin.deleteUser(userId);
                                        break;
                                      case "role":
                                        await _updateUserRole(userId);
                                        break;
                                    }
                                    if (mounted) await _fetchUsers(reset: true);
                                  },
                                  itemBuilder: (_) {
                                    final isActive = user['is_active'] == true;
                                    return [
                                      if (isActive) const PopupMenuItem(value: "suspend", child: Text("Suspend")),
                                      if (!isActive) const PopupMenuItem(value: "activate", child: Text("Activate")),
                                      const PopupMenuItem(value: "role", child: Text("Change Role")),
                                      const PopupMenuItem(value: "delete", child: Text("Delete")),
                                    ];
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  });
}
}

extension StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
