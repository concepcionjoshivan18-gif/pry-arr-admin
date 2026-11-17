import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/app_user.dart';
import '../../core/utils/validators.dart';
import '../components/app_back_button.dart';
import '../../core/components/pagination_controls.dart';
import '../../core/utils/image_helper.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/components/responsive_page_header.dart';
import '../../core/components/responsive_action_button.dart';
import '../../core/components/top_notification.dart';
import '../../core/components/skeleton_loader.dart';
import '../components/admin_scaffold.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _tabIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildHardwareBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header with title and add button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: ResponsivePageHeader(
                    icon: Icons.badge_rounded,
                    title: 'Account Management',
                    actions: [
                      ResponsiveActionButton(
                        icon: Icons.person_add_rounded,
                        label: 'ADD STAFF',
                        onPressed: () => _showAddStaffDialog(context),
                        backgroundColor: hwOrange,
                        foregroundColor: Colors.white,
                        tooltip: 'Add Staff Member',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: p.text),
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      hintStyle: TextStyle(color: p.faint),
                      prefixIcon: Icon(Icons.search_rounded, color: p.faint),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: p.faint),
                        onPressed: () => setState(() => _searchCtrl.clear()),
                      )
                          : null,
                      filled: true,
                      fillColor: p.fill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: p.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: p.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: hwOrange, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // Active / Archived Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tabIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _tabIndex == 0 ? hwOrange : p.fill,
                              borderRadius: BorderRadius.circular(16),
                              border: _tabIndex == 0 ? null : Border.all(color: p.line),
                            ),
                            child: Text('Active Accounts', style: TextStyle(color: _tabIndex == 0 ? Colors.white : p.text, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tabIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _tabIndex == 1 ? hwOrange : p.fill,
                              borderRadius: BorderRadius.circular(16),
                              border: _tabIndex == 1 ? null : Border.all(color: p.line),
                            ),
                            child: Text('Archived Accounts', style: TextStyle(color: _tabIndex == 1 ? Colors.white : p.text, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<AppUser>>(
                    stream: firestoreService.streamAllAccounts(),
                    builder: (context, snapshot) {
                      if (_isLoading || snapshot.connectionState == ConnectionState.waiting) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: 4,
                          itemBuilder: (_, __) => const SkeletonCard(),
                        );
                      }
                      final allUsers = snapshot.data ?? [];
                      final statusFiltered = allUsers.where((u) => _tabIndex == 1 ? u.status == 'Archived' : u.status != 'Archived').toList();

                      final query = _searchCtrl.text.toLowerCase();
                      final filtered = statusFiltered.where((u) {
                        return u.fullName.toLowerCase().contains(query) ||
                            u.email.toLowerCase().contains(query);
                      }).toList();

                      final staff = filtered.where((u) => u.role == 'staff').toList();
                      final customers = filtered.where((u) => u.role == 'customer').toList();

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(context, 'Staff Accounts (${staff.length})', const Color(0xFF4FA3FF)),
                            _PaginatedAccountTable(
                              users: staff,
                              firestoreService: firestoreService,
                              onEdit: (u) => _showEditDialog(context, u),
                              onDelete: (u) => _confirmDeleteAccount(context, firestoreService, u),
                            ),
                            const SizedBox(height: 48),
                            _buildSectionHeader(context, 'Customer Accounts (${customers.length})', const Color(0xFF4CD787)),
                            _PaginatedAccountTable(
                              users: customers,
                              firestoreService: firestoreService,
                              onEdit: (u) => _showEditDialog(context, u),
                              onDelete: (u) => _confirmDeleteAccount(context, firestoreService, u),
                            ),
                          ],
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
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.text)),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, FirestoreService fs, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text('Are you sure you want to delete ${user.fullName}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: hwRust, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await fs.deleteUserAccount(user.uid);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const _AccountFormDialog());
  }

  void _showEditDialog(BuildContext context, AppUser user) {
    showDialog(context: context, builder: (ctx) => _AccountFormDialog(user: user));
  }
}

class _PaginatedAccountTable extends StatefulWidget {
  final List<AppUser> users;
  final FirestoreService firestoreService;
  final void Function(AppUser) onEdit;
  final void Function(AppUser) onDelete;

  const _PaginatedAccountTable({
    required this.users,
    required this.firestoreService,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PaginatedAccountTable> createState() => _PaginatedAccountTableState();
}

class _PaginatedAccountTableState extends State<_PaginatedAccountTable> {
  int _currentPage = 1;
  static const int _itemsPerPage = 5;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    if (widget.users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('No accounts found.', style: TextStyle(color: p.faint))),
      );
    }

    final totalPages = (widget.users.length / _itemsPerPage).ceil();
    if (_currentPage > totalPages) {
      _currentPage = totalPages > 0 ? totalPages : 1;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final pagedUsers = widget.users.skip(startIndex).take(_itemsPerPage).toList();

    return Column(
      children: [
        _glass(
          radius: 20,
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: p.line,
                dataTableTheme: DataTableThemeData(dataTextStyle: TextStyle(color: p.text)),
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(p.fill),
                headingTextStyle: TextStyle(color: p.faint, fontWeight: FontWeight.w800, fontSize: 12),
                columns: const [
                  DataColumn(label: Text('NAME')),
                  DataColumn(label: Text('EMAIL')),
                  DataColumn(label: Text('ROLE / INFO')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: pagedUsers
                    .map((s) => DataRow(cells: [
                  DataCell(Row(
                    children: [
                      if (s.profilePhoto != null && s.profilePhoto!.isNotEmpty && getAvatarImageProvider(s.profilePhoto) != null)
                        CircleAvatar(radius: 14, backgroundImage: getAvatarImageProvider(s.profilePhoto))
                      else
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: hwSteel,
                          child: Text(
                            s.firstName.isNotEmpty ? s.firstName[0] : 'U',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.fullName,
                            style: TextStyle(fontWeight: FontWeight.bold, color: p.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  )),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(s.email, style: TextStyle(color: p.sub), maxLines: 1, overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      s.role == 'staff' ? (s.assignedRole ?? 'General') : '${s.loyaltyPoints} Pts',
                      style: TextStyle(color: p.sub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: s.status == 'Active'
                          ? const Color(0xFF4CD787).withValues(alpha: 0.16)
                          : hwRust.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: s.status == 'Active' ? const Color(0xFF4CD787) : const Color(0xFFFF8A70),
                      ),
                    ),
                  )),
                  DataCell(Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          s.status == 'Active' ? Icons.block : Icons.check_circle,
                          size: 18,
                          color: s.status == 'Active' ? hwRust : const Color(0xFF4CD787),
                        ),
                        onPressed: () => widget.firestoreService
                            .updateUserStatus(s.uid, s.status == 'Active' ? 'Inactive' : 'Active'),
                      ),
                      IconButton(
                        icon: Icon(
                          s.status == 'Archived' ? Icons.unarchive_rounded : Icons.archive_rounded,
                          size: 18,
                          color: hwYellow,
                        ),
                        tooltip: s.status == 'Archived' ? 'Restore Account' : 'Archive Account',
                        onPressed: () => widget.firestoreService
                            .updateUserStatus(s.uid, s.status == 'Archived' ? 'Active' : 'Archived'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18, color: hwYellow),
                        onPressed: () => widget.onEdit(s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: hwRust),
                        tooltip: 'Delete Account',
                        onPressed: () => widget.onDelete(s),
                      ),
                    ],
                  )),
                ]))
                    .toList(),
              ),
            ),
          ),
        ),
        Theme(
          data: Theme.of(context).copyWith(
            iconTheme: IconThemeData(color: p.faint),
            textTheme: Theme.of(context).textTheme.apply(bodyColor: p.faint),
          ),
          child: PaginationControls(
            currentPage: _currentPage,
            totalPages: totalPages,
            onPageChanged: (newPage) {
              setState(() {
                _currentPage = newPage;
              });
            },
          ),
        ),
      ],
    );
  }
}

class _AccountFormDialog extends StatefulWidget {
  final AppUser? user;
  const _AccountFormDialog({this.user});

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _emergencyCtrl;
  final _passCtrl = TextEditingController();
  late TextEditingController _salaryCtrl;
  late TextEditingController _rfidUidCtrl;
  late String _assignedRole;
  String _gender = 'Male';
  bool _obscurePass = true;
  StreamSubscription<DocumentSnapshot>? _scanSubscription;

  // Registration state na nakikita ng ESP32 OLED (system/registration)
  String? _regSession; // id ng kasalukuyang registration session
  bool _saved = false; // true kapag matagumpay na na-save ang card

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.user?.firstName);
    _lastNameCtrl = TextEditingController(text: widget.user?.lastName);
    _emailCtrl = TextEditingController(text: widget.user?.email);
    _phoneCtrl = TextEditingController(text: widget.user?.phone);
    _addressCtrl = TextEditingController(text: widget.user?.address);
    _gender = ['Male', 'Female'].contains(widget.user?.gender) ? widget.user!.gender! : 'Male';
    _emergencyCtrl = TextEditingController(text: widget.user?.emergencyContact);
    _salaryCtrl = TextEditingController(text: widget.user?.basicSalary?.toString() ?? '0');
    _rfidUidCtrl = TextEditingController(text: widget.user?.rfidUid);
    _assignedRole = widget.user?.assignedRole ?? 'Staff';

    if ((widget.user?.rfidUid == null || widget.user!.rfidUid!.isEmpty) && widget.user?.uid != null) {
      _loadAssignedCardFromCardsCollection(widget.user!.uid);
    }
  }

  void _loadAssignedCardFromCardsCollection(String staffId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('cards')
          .where('staffId', isEqualTo: staffId)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty && mounted) {
        final cardUid = querySnapshot.docs.first.id;
        // huwag patungan kung may na-tap na bago habang naglo-load
        if (_rfidUidCtrl.text.isEmpty) {
          setState(() {
            _rfidUidCtrl.text = cardUid;
          });
        }
      }
    } catch (_) {}
  }

  // Isinusulat ang estado ng registration para sa OLED ng ESP32.
  // state: 'registering' | 'registered' | 'idle'
  // Binabasa ang pangalan agad (bago ang unang await) kaya ligtas ding tawagin sa dispose().
  Future<void> _setRegistration(String state, {String uid = ''}) async {
    final name = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
    try {
      await FirebaseFirestore.instance.collection('system').doc('registration').set({
        'state': state,
        'session': _regSession ?? '',
        'name': name,
        'uid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    // Kung isinara ang form nang hindi na-save, ibalik sa idle ang OLED
    if (_regSession != null && !_saved) {
      _setRegistration('idle');
    }
    _scanSubscription?.cancel();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyCtrl.dispose();
    _passCtrl.dispose();
    _salaryCtrl.dispose();
    _rfidUidCtrl.dispose();
    super.dispose();
  }

  void _showTapToScanDialog(BuildContext context) {
    final ValueNotifier<String?> detectedUid = ValueNotifier<String?>(null);
    BuildContext? dialogCtx; // context ng scan dialog mismo
    bool dialogClosed = false;
    bool gotBaseline = false;
    Timestamp? baseline;

    void closeScanDialog() {
      if (!dialogClosed && dialogCtx != null && dialogCtx!.mounted) {
        Navigator.of(dialogCtx!).pop();
      }
    }

    // Simula ng registration session: lalabas ang "REGISTERING" sa OLED
    _regSession = DateTime.now().millisecondsSinceEpoch.toString();
    _setRegistration('registering');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogCtx = ctx;
        return AlertDialog(
          backgroundColor: Pal.of(context).surface,
          title: Row(
            children: const [
              Icon(Icons.nfc_rounded, color: hwOrange, size: 24),
              SizedBox(width: 10),
              Text('Tap RFID Card', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: ValueListenableBuilder<String?>(
            valueListenable: detectedUid,
            builder: (context, uid, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (uid == null) ...[
                    const CircularProgressIndicator(color: hwOrange),
                    const SizedBox(height: 20),
                    const Text(
                      'Please tap the RFID card on the reader hardware...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ] else ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 60),
                    const SizedBox(height: 16),
                    const Text('Card Scanned Successfully!',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(
                      uid,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5),
                    ),
                  ],
                ],
              );
            },
          ),
          actions: [
            ValueListenableBuilder<String?>(
              valueListenable: detectedUid,
              builder: (context, uid, child) {
                return TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(uid != null ? 'Done' : 'Cancel',
                      style: TextStyle(color: uid != null ? hwOrange : Colors.white54)),
                );
              },
            ),
          ],
        );
      },
    ).then((_) {
      dialogClosed = true;
      _scanSubscription?.cancel();
      // Kung walang na-detect na card, bumalik sa idle ang OLED.
      // Kung may na-detect, mananatiling "REGISTERING" hanggang ma-save.
      if (detectedUid.value == null) {
        _setRegistration('idle');
      }
      detectedUid.dispose();
    });

    _scanSubscription = FirebaseFirestore.instance
        .collection('system')
        .doc('last_scan')
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      final ts = data?['scannedAt'] as Timestamp?;

      // Unang snapshot = lumang laman lang, gawing baseline (hindi pa ito bagong tap)
      if (!gotBaseline) {
        baseline = ts;
        gotBaseline = true;
        return;
      }
      if (data == null || ts == null || ts == baseline) return;
      baseline = ts;

      final scannedUid = (data['uid'] ?? '').toString().trim().toUpperCase();
      if (scannedUid.isEmpty) return;
      _scanSubscription?.cancel();

      // Naka-assign na ba sa ibang tao?
      try {
        final card = await FirebaseFirestore.instance
            .collection('cards')
            .doc(scannedUid)
            .get();
        final owner = card.data()?['staffId'];
        if (card.exists && owner != widget.user?.uid) {
          closeScanDialog();
          if (mounted) {
            showTopError(context, 'Card $scannedUid is already assigned to another account');
          }
          return;
        }
      } catch (_) {
        // kung hindi mabasa ang cards, ituloy pa rin; sasalo ang assignCard sa Save
      }

      if (dialogClosed) return;
      detectedUid.value = scannedUid;
      if (mounted) setState(() => _rfidUidCtrl.text = scannedUid);
      Future.delayed(const Duration(milliseconds: 1200), closeScanDialog);
    });
  }

  InputDecoration _fieldDecoration(BuildContext context, String label) {
    final p = Pal.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: p.faint),
      filled: true,
      fillColor: p.fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: hwOrange, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final isEdit = widget.user != null;
    final p = Pal.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: (Breakpoints.width(context) * 0.92).clamp(280.0, 520.0),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.glassBorder, width: 1.2),
              boxShadow: [
                BoxShadow(color: p.shadow, blurRadius: 30, offset: const Offset(0, 16)),
              ],
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_rounded, color: hwOrange, size: 22),
                        const SizedBox(width: 10),
                        Text(isEdit ? 'Account Details' : 'Register New Staff Member',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: p.text, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameCtrl,
                            textCapitalization: TextCapitalization.words,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZÀ-ÖØ-öø-ÿ\s'\-]"))],
                            style: TextStyle(color: p.text),
                            decoration: _fieldDecoration(context, 'First Name'),
                            validator: Validators.validateFirstName,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameCtrl,
                            textCapitalization: TextCapitalization.words,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZÀ-ÖØ-öø-ÿ\s'\-]"))],
                            style: TextStyle(color: p.text),
                            decoration: _fieldDecoration(context, 'Last Name'),
                            validator: Validators.validateLastName,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      style: TextStyle(color: p.text),
                      decoration: _fieldDecoration(context, 'Email Address'),
                      enabled: !isEdit,
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    if (!isEdit) ...[
                      TextFormField(
                        controller: _passCtrl,
                        style: TextStyle(color: p.text),
                        decoration: _fieldDecoration(context, 'Temporary Password').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility,
                                color: p.faint),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        obscureText: _obscurePass,
                        validator: Validators.validatePassword,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _phoneCtrl,
                      style: TextStyle(color: p.text),
                      decoration: _fieldDecoration(context, 'Contact Number (09...)'),
                      validator: Validators.validatePhone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(11),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressCtrl,
                      style: TextStyle(color: p.text),
                      decoration: _fieldDecoration(context, 'Home Address'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _gender,
                            dropdownColor: p.surface,
                            style: TextStyle(color: p.text),
                            decoration: _fieldDecoration(context, 'Gender'),
                            items: ['Male', 'Female']
                                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _emergencyCtrl,
                            style: TextStyle(color: p.text),
                            decoration: _fieldDecoration(context, 'Emergency Contact (09...)'),
                            validator: Validators.validateEmergencyContact,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(11),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isEdit && widget.user?.role == 'customer') ...[
                      const SizedBox(height: 24),
                      Divider(color: p.line),
                      const Text('Customer Account Info',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('Loyalty Points: ${widget.user?.loyaltyPoints}',
                          style: TextStyle(color: p.sub)),
                    ] else ...[
                      const SizedBox(height: 24),
                      Divider(color: p.line),
                      Text('Employment Details',
                          style: TextStyle(fontWeight: FontWeight.bold, color: p.text)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _salaryCtrl,
                        style: TextStyle(color: p.text),
                        decoration: _fieldDecoration(context, 'Hourly Rate / Salary (\u20b1)'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _assignedRole,
                        dropdownColor: p.surface,
                        style: TextStyle(color: p.text),
                        decoration: _fieldDecoration(context, 'Department'),
                        items: ['Staff', 'Driver']
                            .map((r) => DropdownMenuItem<String>(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (String? v) {
                          if (v != null) {
                            setState(() {
                              _assignedRole = v;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rfidUidCtrl,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                                LengthLimitingTextInputFormatter(16),
                              ],
                              style: TextStyle(color: p.text),
                              decoration: _fieldDecoration(context, 'RFID UID (e.g. 992E91E6)'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showTapToScanDialog(context),
                            icon: const Icon(Icons.nfc_rounded, size: 18),
                            label: const Text('Tap Card'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hwOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: TextStyle(color: p.faint)),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              if (_formKey.currentState!.validate()) {
                                try {
                                  Map<String, dynamic> data = {
                                    'firstName': formatCapitalized(_firstNameCtrl.text),
                                    'lastName': formatCapitalized(_lastNameCtrl.text),
                                    'phone': _phoneCtrl.text.trim(),
                                    'address': _addressCtrl.text.trim(),
                                    'gender': _gender,
                                    'emergencyContact': _emergencyCtrl.text.trim(),
                                  };

                                  // Para sa OLED: nagbago ba ang card na ito?
                                  bool rfidChanged = false;
                                  String savedRfid = '';

                                  if (isEdit) {
                                    if (widget.user!.role == 'staff' || widget.user!.role == 'driver' || widget.user!.isDriver) {
                                      data['basicSalary'] = double.tryParse(_salaryCtrl.text) ?? 0.0;
                                      data['assignedRole'] = _assignedRole;
                                      final newRfid = _rfidUidCtrl.text.trim().toUpperCase();
                                      data['rfidUid'] = newRfid;

                                      // Hanapin ang lahat ng card na nakaassign sa user na ito
                                      final cardsCol = FirebaseFirestore.instance.collection('cards');
                                      final owned = await cardsCol
                                          .where('staffId', isEqualTo: widget.user!.uid)
                                          .get();

                                      // Burahin ang lahat maliban sa bago
                                      for (final d in owned.docs) {
                                        if (d.id.toUpperCase() != newRfid) {
                                          await d.reference.delete();
                                        }
                                      }

                                      // I-assign ang bago kung wala pa
                                      final alreadyOwned =
                                      owned.docs.any((d) => d.id.toUpperCase() == newRfid);
                                      if (newRfid.isNotEmpty && !alreadyOwned) {
                                        await firestore.assignCard(newRfid, widget.user!.uid);
                                        rfidChanged = true;
                                        savedRfid = newRfid;
                                      }
                                    }
                                    await firestore.updateUserProfile(widget.user!.uid, data);
                                  } else {
                                    final rfid = _rfidUidCtrl.text.trim().toUpperCase();
                                    await authService.createStaffAccount(
                                      email: _emailCtrl.text.trim(),
                                      password: _passCtrl.text.trim(),
                                      firstName: formatCapitalized(_firstNameCtrl.text),
                                      lastName: formatCapitalized(_lastNameCtrl.text),
                                      assignedRole: _assignedRole,
                                      basicSalary: double.tryParse(_salaryCtrl.text) ?? 0.0,
                                      phone: _phoneCtrl.text.trim(),
                                      address: _addressCtrl.text.trim(),
                                      gender: _gender,
                                      emergencyContact: _emergencyCtrl.text.trim(),
                                      rfidUid: rfid,
                                    );
                                    if (rfid.isNotEmpty) {
                                      rfidChanged = true;
                                      savedRfid = rfid;
                                    }
                                  }

                                  // Tagumpay ang save: ipakita ang "REGISTERED" sa OLED
                                  if (rfidChanged) {
                                    _saved = true;
                                    _regSession ??= DateTime.now().millisecondsSinceEpoch.toString();
                                    _setRegistration('registered', uid: savedRfid);
                                  }

                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    showTopSuccess(
                                      context,
                                      isEdit ? 'Record updated!' : 'Staff account created!',
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    showTopError(context, 'Error: $e');
                                  }
                                }
                              }
                            },
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [hwOrange, hwRust]),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                      color: hwOrange.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6)),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Text(
                                  isEdit ? 'Save Changes' : 'Create Account',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildHardwareBackground() => const SizedBox.shrink();

Widget _glass({
  required Widget child,
  double radius = 24,
  EdgeInsetsGeometry? padding,
}) {
  return Builder(
    builder: (context) {
      final p = Pal.of(context);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: p.glassFill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: p.glassBorder, width: 1.2),
              boxShadow: [
                BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            child: child,
          ),
        ),
      );
    },
  );
}