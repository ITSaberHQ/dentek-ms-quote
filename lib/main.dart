import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'package:universal_io/io.dart' as io;
import 'package:url_launcher/url_launcher.dart';

const String _masterServicesAgreementAssetPath = 'agreement_extracted.txt';
const String _masterServicesAgreementFallbackText =
    'The full Master Services Agreement text could not be loaded from local assets. '
    'Use the official agreement link below.';
const String _masterServicesAgreementUrl =
    'https://mydentek.com/master-services-agreement.html';

void main() {
  runApp(const DentekQuoteApp());
}

enum ServiceCategory { supportBundle, onboarding, alaCarte }

class QuoteService {
  QuoteService({
    required this.name,
    required this.description,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    this.isSelected = false,
  });

  final String name;
  final String description;
  final ServiceCategory category;
  int quantity;
  double unitPrice;
  bool isSelected;

  double get lineTotal => quantity * unitPrice;

  QuoteService clone() {
    return QuoteService(
      name: name,
      description: description,
      category: category,
      quantity: quantity,
      unitPrice: unitPrice,
      isSelected: isSelected,
    );
  }
}

class QuoteDraftServiceSnapshot {
  QuoteDraftServiceSnapshot({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.isSelected,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final bool isSelected;

  factory QuoteDraftServiceSnapshot.fromService(QuoteService service) {
    return QuoteDraftServiceSnapshot(
      name: service.name,
      quantity: service.quantity,
      unitPrice: service.unitPrice,
      isSelected: service.isSelected,
    );
  }

  factory QuoteDraftServiceSnapshot.fromJson(Map<String, dynamic> json) {
    return QuoteDraftServiceSnapshot(
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'isSelected': isSelected,
    };
  }
}

class QuoteDraft {
  QuoteDraft({
    required this.id,
    required this.name,
    required this.quoteTitle,
    required this.clientName,
    required this.selectedTaxState,
    required this.manualTaxRate,
    required this.showBundleAsBundleTotal,
    required this.services,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String quoteTitle;
  final String clientName;
  final String selectedTaxState;
  final double manualTaxRate;
  final bool showBundleAsBundleTotal;
  final List<QuoteDraftServiceSnapshot> services;
  final DateTime updatedAt;

  factory QuoteDraft.fromJson(Map<String, dynamic> json) {
    final rawServices = json['services'];
    final parsedServices = <QuoteDraftServiceSnapshot>[];
    if (rawServices is List) {
      for (final item in rawServices) {
        if (item is Map<String, dynamic>) {
          parsedServices.add(QuoteDraftServiceSnapshot.fromJson(item));
        }
      }
    }

    return QuoteDraft(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Untitled Draft',
      quoteTitle: json['quoteTitle'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      selectedTaxState:
          json['selectedTaxState'] as String? ??
          _QuoteHomePageState._defaultTaxState,
      manualTaxRate:
          (json['manualTaxRate'] as num?)?.toDouble() ??
          _QuoteHomePageState._defaultTaxRate,
      showBundleAsBundleTotal:
          json['showBundleAsBundleTotal'] as bool? ?? false,
      services: parsedServices,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quoteTitle': quoteTitle,
      'clientName': clientName,
      'selectedTaxState': selectedTaxState,
      'manualTaxRate': manualTaxRate,
      'showBundleAsBundleTotal': showBundleAsBundleTotal,
      'services': services.map((service) => service.toJson()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  QuoteDraft copyWith({String? id, String? name, DateTime? updatedAt}) {
    return QuoteDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      quoteTitle: quoteTitle,
      clientName: clientName,
      selectedTaxState: selectedTaxState,
      manualTaxRate: manualTaxRate,
      showBundleAsBundleTotal: showBundleAsBundleTotal,
      services: services,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DentekQuoteApp extends StatelessWidget {
  const DentekQuoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    const dentekBlue = Color(0xFF084C8D);
    const dentekTeal = Color(0xFF0FA3B1);

    return MaterialApp(
      title: 'Dentek Quote Builder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: dentekBlue,
          primary: dentekBlue,
          secondary: dentekTeal,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F8FC),
        useMaterial3: true,
      ),
      home: const QuoteHomePage(),
    );
  }
}

class QuoteHomePage extends StatefulWidget {
  const QuoteHomePage({super.key});

  @override
  State<QuoteHomePage> createState() => _QuoteHomePageState();
}

class _QuoteHomePageState extends State<QuoteHomePage>
    with SingleTickerProviderStateMixin {
  static const List<double> _onboardingOptions = [0, 600, 1200];
  static const String _defaultQuoteTitle = 'Dentek Services Proposal';
  static const String _defaultTaxState = 'No Tax';
  static const double _defaultTaxRate = 0.0825;
  static const String _quoteDraftsKey = 'quote_drafts_v1';
  static const int _maxSavedDrafts = 20;
  static const Map<String, double> _defaultServicePrices = {
    'Remote Support Server/Cloud': 0,
    'Remote Support Workstation': 0,
    'Anti-Virus': 0,
    'Onboarding': 0,
    'Remote Access': 0,
    'Advanced Threat Protection': 0,
    'Endpoint Detection': 0,
    'Server Backup': 0,
    'Workstation Backup': 0,
    'O365 Bus Standard': 0,
    'O365 Bus Premium': 0,
    'O365 Bus Basic': 0,
    'Exchange Online P1': 0,
    'Exchange Online P2': 0,
  };
  static const Map<String, double> _stateTaxRates = {
    'No Tax': 0,
    'AL': 0.04,
    'AK': 0,
    'AZ': 0.056,
    'AR': 0.065,
    'CA': 0.0725,
    'CO': 0.029,
    'CT': 0.0635,
    'DE': 0,
    'FL': 0.06,
    'GA': 0.04,
    'HI': 0.04,
    'ID': 0.06,
    'IL': 0.0625,
    'IN': 0.07,
    'IA': 0.06,
    'KS': 0.065,
    'KY': 0.06,
    'LA': 0.0445,
    'ME': 0.055,
    'MD': 0.06,
    'MA': 0.0625,
    'MI': 0.06,
    'MN': 0.06875,
    'MS': 0.07,
    'MO': 0.04225,
    'MT': 0,
    'NE': 0.055,
    'NV': 0.0685,
    'NH': 0,
    'NJ': 0.06625,
    'NM': 0.05125,
    'NY': 0.04,
    'NC': 0.0475,
    'ND': 0.05,
    'OH': 0.0575,
    'OK': 0.045,
    'OR': 0,
    'PA': 0.06,
    'RI': 0.07,
    'SC': 0.06,
    'SD': 0.045,
    'TN': 0.07,
    'TX': 0.0625,
    'UT': 0.061,
    'VT': 0.06,
    'VA': 0.053,
    'WA': 0.065,
    'WV': 0.06,
    'WI': 0.05,
    'WY': 0.04,
    'DC': 0.06,
  };

  static List<QuoteService> _createDefaultServices() {
    return [
      QuoteService(
        name: 'Remote Support Server/Cloud',
        description: 'Managed remote support for server and cloud systems.',
        category: ServiceCategory.supportBundle,
        quantity: 1,
        unitPrice: _defaultServicePrices['Remote Support Server/Cloud'] ?? 0,
        isSelected: true,
      ),
      QuoteService(
        name: 'Remote Support Workstation',
        description: 'Managed remote support for workstation devices.',
        category: ServiceCategory.supportBundle,
        quantity: 1,
        unitPrice: _defaultServicePrices['Remote Support Workstation'] ?? 0,
        isSelected: true,
      ),
      QuoteService(
        name: 'Anti-Virus',
        description: 'Core anti-virus protection service.',
        category: ServiceCategory.supportBundle,
        quantity: 1,
        unitPrice: _defaultServicePrices['Anti-Virus'] ?? 0,
        isSelected: true,
      ),
      QuoteService(
        name: 'Onboarding',
        description: 'Initial onboarding setup and implementation package.',
        category: ServiceCategory.onboarding,
        quantity: 1,
        unitPrice: _defaultServicePrices['Onboarding'] ?? 0,
        isSelected: true,
      ),
      QuoteService(
        name: 'Remote Access',
        description: 'Secure remote access service.',
        category: ServiceCategory.alaCarte,
        quantity: 1,
        unitPrice: _defaultServicePrices['Remote Access'] ?? 0,
      ),
      QuoteService(
        name: 'Advanced Threat Protection',
        description: 'Advanced threat protection add-on.',
        category: ServiceCategory.alaCarte,
        quantity: 1,
        unitPrice: _defaultServicePrices['Advanced Threat Protection'] ?? 0,
      ),
      QuoteService(
        name: 'Endpoint Detection',
        description: 'Endpoint detection service add-on.',
        category: ServiceCategory.alaCarte,
        quantity: 1,
        unitPrice: _defaultServicePrices['Endpoint Detection'] ?? 0,
      ),
      QuoteService(
        name: 'Server Backup',
        description: 'Server backup service add-on.',
        category: ServiceCategory.alaCarte,
        quantity: 1,
        unitPrice: _defaultServicePrices['Server Backup'] ?? 0,
      ),
      QuoteService(
        name: 'Workstation Backup',
        description: 'Workstation backup service add-on.',
        category: ServiceCategory.alaCarte,
        quantity: 1,
        unitPrice: _defaultServicePrices['Workstation Backup'] ?? 0,
      ),
      QuoteService(
        name: 'O365 Bus Standard',
        description: 'Microsoft 365 Business Standard license.',
        category: ServiceCategory.alaCarte,
        quantity: 1,
        unitPrice: _defaultServicePrices['O365 Bus Standard'] ?? 0,
      ),
      QuoteService(
        name: 'O365 Bus Premium',
        description: 'Microsoft 365 Business Premium license.',
        category: ServiceCategory.alaCarte,
        quantity: 1,
        unitPrice: _defaultServicePrices['O365 Bus Premium'] ?? 0,
      ),
      QuoteService(
        name: 'O365 Bus Basic',
        description: 'Microsoft 365 Business Basic license.',
        category: ServiceCategory.alaCarte,
        quantity: 1,
        unitPrice: _defaultServicePrices['O365 Bus Basic'] ?? 0,
      ),
      QuoteService(
        name: 'Exchange Online P1',
        description: 'Exchange Online Plan 1 license.',
        category: ServiceCategory.alaCarte,
        quantity: 1,
        unitPrice: _defaultServicePrices['Exchange Online P1'] ?? 0,
      ),
      QuoteService(
        name: 'Exchange Online P2',
        description: 'Exchange Online Plan 2 license.',
        category: ServiceCategory.alaCarte,
        quantity: 1,
        unitPrice: _defaultServicePrices['Exchange Online P2'] ?? 0,
      ),
    ];
  }

  late List<QuoteService> _services;

  final NumberFormat _currency = NumberFormat.currency(symbol: '\$');
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  late final TabController _tabController;
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _quoteNameController = TextEditingController(
    text: _defaultQuoteTitle,
  );

  DateTime? _signedDate;
  Uint8List? _signatureBytes;
  String? _lastInternalPdfPath;
  String _selectedTaxState = _defaultTaxState;
  double _manualTaxRate = _defaultTaxRate;
  bool _salesViewUnlocked = false;
  bool _showBundleAsBundleTotal = false;
  bool _showSalesHeaderDetails = true;
  String? _activeDraftId;
  List<QuoteDraft> _savedDrafts = [];
  String _masterServicesAgreementText = _masterServicesAgreementFallbackText;

  final TextEditingController _salesPinController = TextEditingController();
  final TextEditingController _taxRateController = TextEditingController(
    text: '8.25',
  );

  List<QuoteService> get _selectedServices =>
      _services.where((service) => service.isSelected).toList();

  bool _isOneTimeService(QuoteService service) {
    return service.category == ServiceCategory.onboarding;
  }

  double get _monthlyRecurringSubtotal => _selectedServices
      .where((service) => !_isOneTimeService(service))
      .fold<double>(0, (sum, item) => sum + item.lineTotal);

  double get _oneTimeSubtotal => _selectedServices
      .where(_isOneTimeService)
      .fold<double>(0, (sum, item) => sum + item.lineTotal);

  double get _selectedTaxRate {
    if (_selectedTaxState == _defaultTaxState) {
      return _manualTaxRate;
    }
    return _stateTaxRates[_selectedTaxState] ?? _manualTaxRate;
  }

  double get _salesTaxAmount => _oneTimeSubtotal * _selectedTaxRate;

  double get _dueTodayTotal => _oneTimeSubtotal + _salesTaxAmount;

  double get _estimatedFirstInvoiceTotal =>
      _monthlyRecurringSubtotal + _dueTodayTotal;

  bool get _isSigned => _signedDate != null && _signatureBytes != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _services = _createDefaultServices()
        .map((service) => service.clone())
        .toList();
    _taxRateController.text = '8.25';
    unawaited(_loadSavedServicePrices());
    unawaited(_loadSavedDrafts());
    unawaited(_loadMasterServicesAgreementText());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signatureController.dispose();
    _clientNameController.dispose();
    _quoteNameController.dispose();
    _salesPinController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!mounted) {
      return;
    }

    if (_tabController.index == 0) {
      setState(() {
        _salesViewUnlocked = false;
        _salesPinController.clear();
      });
    }
  }

  void _unlockSalesView() {
    if (_salesPinController.text.trim() == '1972') {
      setState(() {
        _salesViewUnlocked = true;
      });
      _salesPinController.clear();
      _showMessage('Sales view unlocked.');
      return;
    }

    _showMessage('Incorrect sales pin.');
  }

  Future<void> _resetSalesState() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Fresh?'),
        content: const Text(
          'This will clear the sales form, restore default service values, and remove the captured signature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset != true) {
      return;
    }

    setState(() {
      _services = _createDefaultServices()
          .map((service) => service.clone())
          .toList();
      _clientNameController.clear();
      _quoteNameController.text = _defaultQuoteTitle;
      _signatureBytes = null;
      _signedDate = null;
      _lastInternalPdfPath = null;
      _selectedTaxState = _defaultTaxState;
      _manualTaxRate = _defaultTaxRate;
      _taxRateController.text = '8.25';
      _showSalesHeaderDetails = true;
      _activeDraftId = null;
    });
    unawaited(_applySavedServicePrices());
    _signatureController.clear();
    _showMessage('Sales quote reset to default values.');
  }

  Future<void> _loadSavedDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_quoteDraftsKey);
    if (raw == null || raw.trim().isEmpty || !mounted) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }

      final drafts = <QuoteDraft>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          drafts.add(QuoteDraft.fromJson(item));
        }
      }

      drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      setState(() {
        _savedDrafts = drafts.take(_maxSavedDrafts).toList();
      });
    } catch (_) {
      _showMessage('Unable to read saved drafts on this device.');
    }
  }

  Future<void> _loadMasterServicesAgreementText() async {
    try {
      final agreementText = await rootBundle.loadString(
        _masterServicesAgreementAssetPath,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _masterServicesAgreementText = agreementText.trim();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _masterServicesAgreementText = _masterServicesAgreementFallbackText;
      });
    }
  }

  Future<void> _persistSavedDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      _savedDrafts
          .take(_maxSavedDrafts)
          .map((draft) => draft.toJson())
          .toList(),
    );
    await prefs.setString(_quoteDraftsKey, payload);
  }

  String _newDraftId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  String _suggestedDraftName() {
    final client = _clientNameController.text.trim();
    if (client.isNotEmpty) {
      return client;
    }

    final title = _quoteNameController.text.trim();
    if (title.isNotEmpty && title != _defaultQuoteTitle) {
      return title;
    }

    return 'Quote ${DateFormat.yMd().add_jm().format(DateTime.now())}';
  }

  QuoteDraft _buildCurrentDraft({required String id, required String name}) {
    return QuoteDraft(
      id: id,
      name: name,
      quoteTitle: _quoteNameController.text.trim(),
      clientName: _clientNameController.text.trim(),
      selectedTaxState: _selectedTaxState,
      manualTaxRate: _manualTaxRate,
      showBundleAsBundleTotal: _showBundleAsBundleTotal,
      services: _services
          .map((service) => QuoteDraftServiceSnapshot.fromService(service))
          .toList(),
      updatedAt: DateTime.now(),
    );
  }

  Future<String?> _openDraftNameDialog({
    required String title,
    required String actionLabel,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Draft Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    return result;
  }

  Future<void> _saveCurrentDraft() async {
    final existingDraft = _savedDrafts.where(
      (draft) => draft.id == _activeDraftId,
    );
    final initialName = existingDraft.isEmpty
        ? _suggestedDraftName()
        : existingDraft.first.name;

    final name = await _openDraftNameDialog(
      title: 'Save Quote Draft',
      actionLabel: 'Save',
      initialValue: initialName,
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }

    final draft = _buildCurrentDraft(
      id: _activeDraftId ?? _newDraftId(),
      name: name,
    );

    setState(() {
      _savedDrafts = [
        draft,
        ..._savedDrafts.where((item) => item.id != draft.id),
      ];
      if (_savedDrafts.length > _maxSavedDrafts) {
        _savedDrafts = _savedDrafts.take(_maxSavedDrafts).toList();
      }
      _activeDraftId = draft.id;
    });

    await _persistSavedDrafts();
    _showMessage('Saved draft "$name" on this device.');
  }

  void _loadDraft(QuoteDraft draft) {
    final serviceByName = {for (final item in draft.services) item.name: item};

    setState(() {
      _quoteNameController.text = draft.quoteTitle.isEmpty
          ? _defaultQuoteTitle
          : draft.quoteTitle;
      _clientNameController.text = draft.clientName;
      _selectedTaxState = draft.selectedTaxState;
      _manualTaxRate = draft.manualTaxRate;
      _taxRateController.text = (_manualTaxRate * 100).toStringAsFixed(2);
      _showBundleAsBundleTotal = draft.showBundleAsBundleTotal;
      _activeDraftId = draft.id;

      for (final service in _services) {
        final snapshot = serviceByName[service.name];
        if (snapshot == null) {
          continue;
        }
        service.quantity = snapshot.quantity;
        service.unitPrice = snapshot.unitPrice;
        service.isSelected = snapshot.isSelected;
      }

      _signatureBytes = null;
      _signedDate = null;
    });
    _signatureController.clear();
    _showMessage('Loaded draft "${draft.name}".');
  }

  Future<void> _duplicateDraft(QuoteDraft draft) async {
    final name = await _openDraftNameDialog(
      title: 'Duplicate Draft',
      actionLabel: 'Duplicate',
      initialValue: '${draft.name} Copy',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }

    final duplicate = draft.copyWith(
      id: _newDraftId(),
      name: name,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _savedDrafts = [duplicate, ..._savedDrafts];
      if (_savedDrafts.length > _maxSavedDrafts) {
        _savedDrafts = _savedDrafts.take(_maxSavedDrafts).toList();
      }
    });

    await _persistSavedDrafts();
    _showMessage('Draft duplicated as "$name".');
  }

  Future<void> _deleteDraft(QuoteDraft draft) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft?'),
        content: Text('Delete "${draft.name}" from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _savedDrafts = _savedDrafts.where((item) => item.id != draft.id).toList();
      if (_activeDraftId == draft.id) {
        _activeDraftId = null;
      }
    });

    await _persistSavedDrafts();
    _showMessage('Draft deleted.');
  }

  Future<void> _openSavedDraftsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved Drafts (Device Only)'),
        content: SizedBox(
          width: 520,
          child: _savedDrafts.isEmpty
              ? const Text('No drafts saved yet.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _savedDrafts.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final draft = _savedDrafts[index];
                    final subtitleClient = draft.clientName.trim().isEmpty
                        ? 'Client not set'
                        : draft.clientName.trim();

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(draft.name),
                      subtitle: Text(
                        '$subtitleClient • ${DateFormat.yMMMd().add_jm().format(draft.updatedAt)}',
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _loadDraft(draft);
                            },
                            child: const Text('Load'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              unawaited(_duplicateDraft(draft));
                            },
                            child: const Text('Duplicate'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              unawaited(_deleteDraft(draft));
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleSalesActionSelection(String action) {
    switch (action) {
      case 'save_draft':
        unawaited(_saveCurrentDraft());
        break;
      case 'saved_drafts':
        unawaited(_openSavedDraftsDialog());
        break;
      case 'open_internal_pdf':
        unawaited(_openLastInternalPdf());
        break;
      case 'start_fresh':
        unawaited(_resetSalesState());
        break;
    }
  }

  Future<void> _loadSavedServicePrices() async {
    await _applySavedServicePrices();
  }

  Future<void> _applySavedServicePrices() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }

    setState(() {
      for (final service in _services) {
        final savedPrice = prefs.getDouble(_servicePriceKey(service.name));
        if (savedPrice != null) {
          service.unitPrice = savedPrice;
        }
      }
    });
  }

  Future<void> _persistServicePrices() async {
    final prefs = await SharedPreferences.getInstance();
    for (final service in _services) {
      await prefs.setDouble(_servicePriceKey(service.name), service.unitPrice);
    }
  }

  String _servicePriceKey(String serviceName) {
    return 'service_price_$serviceName';
  }

  Future<void> _captureSignature() async {
    if (_signatureController.isEmpty) {
      _showMessage('Signature area is empty. Please sign before confirming.');
      return;
    }

    final pngData = await _signatureController.toPngBytes();
    if (pngData == null) {
      _showMessage('Unable to capture signature. Please try again.');
      return;
    }

    setState(() {
      _signatureBytes = pngData;
      _signedDate = DateTime.now();
    });

    _showMessage('Proposal signed and date applied automatically.');
  }

  Future<pw.Document> _buildClientPdf() async {
    final pdf = pw.Document();
    final supportItems = _selectedServices
        .where((service) => service.category == ServiceCategory.supportBundle)
        .toList();
    final onboardingItems = _selectedServices
        .where((service) => service.category == ServiceCategory.onboarding)
        .toList();
    final alaCarteItems = _selectedServices
        .where((service) => service.category == ServiceCategory.alaCarte)
        .toList();

    pw.Widget buildSection(String title, List<QuoteService> items) {
      if (items.isEmpty) {
        return pw.Container();
      }

      if (title == 'Remote Support Bundle' && _showBundleAsBundleTotal) {
        final bundleTotal = items.fold<double>(
          0,
          (sum, item) => sum + item.lineTotal,
        );
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#084C8D'),
              ),
            ),
            pw.SizedBox(height: 8),
            ...items.map((service) => pw.Text('• ${service.name}')),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Expanded(child: pw.Text('Bundle total')),
                pw.Text(_currency.format(bundleTotal)),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
        );
      }

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#084C8D'),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Service', isHeader: true),
                  _pdfCell('Billing', isHeader: true),
                  _pdfCell('Qty', isHeader: true),
                  _pdfCell('Unit Price', isHeader: true),
                  _pdfCell('Line Total', isHeader: true),
                ],
              ),
              ...items.map(
                (service) => pw.TableRow(
                  children: [
                    _pdfCell(service.name),
                    _pdfCell(_billingLabel(service)),
                    _pdfCell('${service.quantity}'),
                    _pdfCell(_currency.format(service.unitPrice)),
                    _pdfCell(_currency.format(service.lineTotal)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            _quoteNameController.text.trim().isEmpty
                ? _defaultQuoteTitle
                : _quoteNameController.text.trim(),
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#084C8D'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Prepared for: ${_clientNameController.text.trim().isEmpty ? 'Client' : _clientNameController.text.trim()}',
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Prepared by Dentek Systems on ${DateFormat.yMMMd().format(DateTime.now())}',
          ),
          pw.SizedBox(height: 20),
          buildSection('Remote Support Bundle', supportItems),
          buildSection('Onboarding', onboardingItems),
          buildSection('A La Carte Services', alaCarteItems),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColors.grey100,
            child: pw.Column(
              children: [
                _pdfSummaryRow(
                  'Monthly Recurring Subtotal',
                  _currency.format(_monthlyRecurringSubtotal),
                ),
                pw.SizedBox(height: 4),
                _pdfSummaryRow(
                  'One-Time Subtotal',
                  _currency.format(_oneTimeSubtotal),
                ),
                pw.SizedBox(height: 4),
                _pdfSummaryRow(
                  'Sales Tax (${(_selectedTaxRate * 100).toStringAsFixed(2)}%)',
                  _currency.format(_salesTaxAmount),
                ),
                pw.Divider(color: PdfColors.grey500),
                _pdfSummaryRow(
                  'Due Today',
                  _currency.format(_dueTodayTotal),
                  emphasize: true,
                ),
                pw.SizedBox(height: 4),
                _pdfSummaryRow(
                  'Estimated First Invoice',
                  _currency.format(_estimatedFirstInvoiceTotal),
                  emphasize: true,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          if (_signatureBytes != null) ...[
            pw.Text(
              'Client Signature',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              height: 80,
              width: 220,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Image(pw.MemoryImage(_signatureBytes!)),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Date Signed: ${DateFormat.yMMMMd().format(_signedDate!)}'),
          ],
          pw.SizedBox(height: 24),
          pw.Text(
            'Terms of Service',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#084C8D'),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _masterServicesAgreementText,
            style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.2),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _masterServicesAgreementUrl,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue),
          ),
        ],
      ),
    );

    return pdf;
  }

  Future<pw.Document> _buildInternalPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Internal Implementation Sheet',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#084C8D'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Client: ${_clientNameController.text.trim().isEmpty ? 'Client' : _clientNameController.text.trim()}',
          ),
          pw.Text(
            'Generated: ${DateFormat.yMMMMd().add_jm().format(DateTime.now())}',
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.7),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.8),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(2),
              5: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Service', isHeader: true),
                  _pdfCell('Category', isHeader: true),
                  _pdfCell('Billing', isHeader: true),
                  _pdfCell('Qty', isHeader: true),
                  _pdfCell('Unit', isHeader: true),
                  _pdfCell('Total', isHeader: true),
                ],
              ),
              ..._selectedServices.map(
                (service) => pw.TableRow(
                  children: [
                    _pdfCell(service.name),
                    _pdfCell(_categoryLabel(service.category)),
                    _pdfCell(_billingLabel(service)),
                    _pdfCell('${service.quantity}'),
                    _pdfCell(_currency.format(service.unitPrice)),
                    _pdfCell(_currency.format(service.lineTotal)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            color: PdfColors.grey100,
            child: pw.Column(
              children: [
                _pdfSummaryRow(
                  'Monthly Recurring Subtotal',
                  _currency.format(_monthlyRecurringSubtotal),
                ),
                pw.SizedBox(height: 4),
                _pdfSummaryRow(
                  'One-Time Subtotal',
                  _currency.format(_oneTimeSubtotal),
                ),
                pw.SizedBox(height: 4),
                _pdfSummaryRow(
                  'Sales Tax (${(_selectedTaxRate * 100).toStringAsFixed(2)}%)',
                  _currency.format(_salesTaxAmount),
                ),
                pw.Divider(color: PdfColors.grey500),
                _pdfSummaryRow(
                  'Due Today',
                  _currency.format(_dueTodayTotal),
                  emphasize: true,
                ),
                pw.SizedBox(height: 4),
                _pdfSummaryRow(
                  'Estimated First Invoice',
                  _currency.format(_estimatedFirstInvoiceTotal),
                  emphasize: true,
                ),
              ],
            ),
          ),
          if (_signedDate != null) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Client signed on ${DateFormat.yMMMMd().add_jm().format(_signedDate!)}',
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _pdfCell(String value, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  pw.Widget _pdfSummaryRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(child: pw.Text(label)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Future<io.File> _savePdfToTemp(String fileName, pw.Document pdf) async {
    final tempPath = io.Directory.systemTemp.path;
    final file = io.File('$tempPath/$fileName');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Future<io.File> _savePdfForDesktop(String fileName, pw.Document pdf) async {
    final downloadsDir = await getDownloadsDirectory();
    final fallbackDir = await getTemporaryDirectory();
    final outputDir = downloadsDir ?? fallbackDir;
    final file = io.File('${outputDir.path}/$fileName');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Future<void> _sendClientCopy() async {
    if (!_isSigned) {
      _showMessage('Please capture a client signature before sending.');
      return;
    }

    final clientPdf = await _buildClientPdf();
    final bytes = await clientPdf.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'Dentek_Client_Quote_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _sendInternalCopy() async {
    if (_selectedServices.isEmpty) {
      _showMessage('Select at least one service before sending internal copy.');
      return;
    }

    final internalPdf = await _buildInternalPdf();
    final fileName =
        'Dentek_Internal_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (kIsWeb) {
      setState(() {
        _lastInternalPdfPath = null;
      });

      await Printing.sharePdf(
        bytes: await internalPdf.save(),
        filename: fileName,
      );

      final mailto = Uri(
        scheme: 'mailto',
        path: 'sales@mydentek.com',
        queryParameters: {
          'subject':
              'Dentek Itemized Quote - ${_clientNameController.text.trim().isEmpty ? 'Client' : _clientNameController.text.trim()}',
          'body':
              'The internal PDF has been downloaded/generated from the app. Please attach it to this email.',
        },
      );

      if (await canLaunchUrl(mailto)) {
        await launchUrl(mailto);
      }

      _showMessage(
        'Internal PDF generated. Attach the downloaded PDF to email.',
      );
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final pdfFile = await _savePdfToTemp(fileName, internalPdf);
      setState(() {
        _lastInternalPdfPath = pdfFile.path;
      });

      final email = Email(
        recipients: const ['sales@mydentek.com'],
        subject:
            'Dentek Itemized Quote - ${_clientNameController.text.trim().isEmpty ? 'Client' : _clientNameController.text.trim()}',
        body:
            'Attached is the signed itemized quote for backend implementation.',
        attachmentPaths: [pdfFile.path],
      );
      await FlutterEmailSender.send(email);
      return;
    }

    final pdfFile = await _savePdfForDesktop(fileName, internalPdf);
    setState(() {
      _lastInternalPdfPath = pdfFile.path;
    });

    final mailto = Uri(
      scheme: 'mailto',
      path: 'sales@mydentek.com',
      queryParameters: {
        'subject':
            'Dentek Itemized Quote - ${_clientNameController.text.trim().isEmpty ? 'Client' : _clientNameController.text.trim()}',
        'body': 'Please attach this generated PDF:\n${pdfFile.path}',
      },
    );

    if (await canLaunchUrl(mailto)) {
      await launchUrl(mailto);
    }

    _showMessage('Internal PDF created at ${pdfFile.path}');
  }

  Future<void> _openLastInternalPdf() async {
    final filePath = _lastInternalPdfPath;

    if (kIsWeb || filePath == null || filePath.trim().isEmpty) {
      _showMessage('No local internal PDF file is available yet.');
      return;
    }

    final file = io.File(filePath);
    if (!await file.exists()) {
      _showMessage('The last internal PDF file was not found at: $filePath');
      return;
    }

    final fileUri = Uri.file(filePath);
    if (await canLaunchUrl(fileUri)) {
      await launchUrl(fileUri);
      return;
    }

    _showMessage('Could not open PDF automatically. File path: $filePath');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _categoryLabel(ServiceCategory category) {
    return category == ServiceCategory.supportBundle
        ? 'Remote Support Bundle'
        : category == ServiceCategory.onboarding
        ? 'Onboarding'
        : 'A La Carte';
  }

  String _billingLabel(QuoteService service) {
    return _isOneTimeService(service) ? 'One-Time' : 'Monthly Recurring';
  }

  String _onboardingOptionLabel(double price) {
    if (price == 0) {
      return 'Waived';
    }
    return _currency.format(price);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dentek Quote Builder'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.point_of_sale), text: 'Sales View'),
            Tab(icon: Icon(Icons.description), text: 'Client View'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSalesView(), _buildClientView()],
      ),
    );
  }

  Widget _buildSalesView() {
    if (!_salesViewUnlocked) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales view locked',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Enter the sales PIN to continue.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _salesPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sales PIN',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _unlockSalesView(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use 1972 for now.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _unlockSalesView,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Unlock sales view'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isCompactLayout = MediaQuery.of(context).size.width < 700;
    final hasHeaderDetails =
        _quoteNameController.text.trim().isNotEmpty ||
        _clientNameController.text.trim().isNotEmpty ||
        _selectedTaxState != _defaultTaxState ||
        _manualTaxRate != _defaultTaxRate;
    final showCompactHeaderSummary =
        isCompactLayout && hasHeaderDetails && !_showSalesHeaderDetails;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!showCompactHeaderSummary)
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildBundleViewButton(
                                label: 'Items',
                                selected: !_showBundleAsBundleTotal,
                                onPressed: () {
                                  setState(() {
                                    _showBundleAsBundleTotal = false;
                                  });
                                },
                              ),
                              _buildBundleViewButton(
                                label: 'Bundle total',
                                selected: _showBundleAsBundleTotal,
                                onPressed: () {
                                  setState(() {
                                    _showBundleAsBundleTotal = true;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        if (isCompactLayout && hasHeaderDetails)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showSalesHeaderDetails = false;
                              });
                            },
                            icon: const Icon(Icons.expand_less),
                          ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Quote details ready',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showSalesHeaderDetails = true;
                            });
                          },
                          icon: const Icon(Icons.edit),
                        ),
                      ],
                    ),
                  if (!showCompactHeaderSummary) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _quoteNameController,
                      decoration: const InputDecoration(
                        labelText: 'Proposal Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _clientNameController,
                      decoration: const InputDecoration(
                        labelText: 'Client Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Sales Tax (%)',
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                      controller: _taxRateController,
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed == null) {
                          return;
                        }
                        setState(() {
                          _manualTaxRate = parsed / 100;
                          _selectedTaxState = _defaultTaxState;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: PopupMenuButton<String>(
                      key: const ValueKey('sales_actions_menu_button'),
                      onSelected: _handleSalesActionSelection,
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'save_draft',
                          child: ListTile(
                            leading: Icon(Icons.save),
                            title: Text('Save Draft'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'saved_drafts',
                          child: ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(
                              'Saved Drafts (${_savedDrafts.length})',
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'open_internal_pdf',
                          child: ListTile(
                            leading: Icon(Icons.picture_as_pdf),
                            title: Text('Open Last Internal PDF'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'start_fresh',
                          child: ListTile(
                            leading: Icon(Icons.restart_alt),
                            title: Text('Start Fresh'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.menu),
                            SizedBox(width: 8),
                            Text('Actions'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Drafts are saved only on this device/browser (${_savedDrafts.length}/$_maxSavedDrafts).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                _buildServiceSection(
                  title: 'Remote Support Bundle',
                  services: _services
                      .where(
                        (service) =>
                            service.category == ServiceCategory.supportBundle,
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                _buildServiceSection(
                  title: 'A La Carte',
                  services: _services
                      .where(
                        (service) =>
                            service.category == ServiceCategory.alaCarte,
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientView() {
    final supportItems = _selectedServices
        .where((service) => service.category == ServiceCategory.supportBundle)
        .toList();
    final onboardingItems = _selectedServices
        .where((service) => service.category == ServiceCategory.onboarding)
        .toList();
    final alaCarteItems = _selectedServices
        .where((service) => service.category == ServiceCategory.alaCarte)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _quoteNameController.text.trim().isEmpty
                ? _defaultQuoteTitle
                : _quoteNameController.text.trim(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Prepared for ${_clientNameController.text.trim().isEmpty ? 'Client' : _clientNameController.text.trim()}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (_showBundleAsBundleTotal)
            _buildBundleSummarySection('Remote Support Bundle', supportItems)
          else
            _buildClientSection('Remote Support Bundle', supportItems),
          const SizedBox(height: 12),
          _buildClientSection('Onboarding', onboardingItems),
          const SizedBox(height: 12),
          _buildClientSection('A La Carte', alaCarteItems),
          const SizedBox(height: 10),
          Card(
            color: const Color(0xFFEAF3FF),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildMoneyRow(
                    'Monthly Recurring Subtotal',
                    _monthlyRecurringSubtotal,
                  ),
                  const SizedBox(height: 6),
                  _buildMoneyRow('One-Time Subtotal', _oneTimeSubtotal),
                  const SizedBox(height: 6),
                  _buildMoneyRow(
                    'Sales Tax (${(_selectedTaxRate * 100).toStringAsFixed(2)}%)',
                    _salesTaxAmount,
                  ),
                  const Divider(height: 20),
                  _buildMoneyRow('Due Today', _dueTodayTotal, emphasize: true),
                  const SizedBox(height: 6),
                  _buildMoneyRow(
                    'Estimated First Invoice',
                    _estimatedFirstInvoiceTotal,
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildTermsOfServiceSection(),
          const SizedBox(height: 20),
          Text(
            'Client Signature',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            height: 170,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              color: Colors.white,
            ),
            child: Signature(
              controller: _signatureController,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _captureSignature,
                icon: const Icon(Icons.edit_document),
                label: const Text('Confirm Signature'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _signatureController.clear();
                  setState(() {
                    _signatureBytes = null;
                    _signedDate = null;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Signature'),
              ),
            ],
          ),
          if (_signedDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Signed on ${DateFormat.yMMMMd().add_jm().format(_signedDate!)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _sendClientCopy,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Send Client PDF'),
              ),
              ElevatedButton.icon(
                onPressed: _sendInternalCopy,
                icon: const Icon(Icons.outgoing_mail),
                label: const Text('Send Internal PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsOfServiceSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Terms of Service'),
        initiallyExpanded: false,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SelectableText(
            _masterServicesAgreementText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final uri = Uri.parse(_masterServicesAgreementUrl);
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to open the agreement link.'),
                  ),
                );
              }
            },
            child: Text(
              _masterServicesAgreementUrl,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBundleSummarySection(String title, List<QuoteService> items) {
    final bundleTotal = items.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text('No services selected in this section.')
            else ...[
              ...items.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text('• ${service.name}')),
                      Text(
                        'x${service.quantity}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Bundle total')),
                  Text(_currency.format(bundleTotal)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBundleViewButton({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return selected
        ? ElevatedButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton(onPressed: onPressed, child: Text(label));
  }

  Widget _buildServiceSection({
    required String title,
    required List<QuoteService> services,
  }) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        initiallyExpanded: false,
        children: [
          if (services.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('No services selected in this section.'),
            )
          else
            ...services.map(
              (service) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSalesServiceCard(service),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSalesServiceCard(QuoteService service) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: service.isSelected,
                  onChanged: (value) {
                    setState(() {
                      service.isSelected = value;
                    });
                  },
                ),
              ],
            ),
            Text(service.description),
            const SizedBox(height: 8),
            Text(
              _billingLabel(service),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            if (service.category == ServiceCategory.onboarding)
              Row(
                children: [
                  const Text('Option:'),
                  const SizedBox(width: 12),
                  DropdownButton<double>(
                    value: _onboardingOptions.contains(service.unitPrice)
                        ? service.unitPrice
                        : 0,
                    items: _onboardingOptions
                        .map(
                          (option) => DropdownMenuItem<double>(
                            value: option,
                            child: Text(_onboardingOptionLabel(option)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        service.unitPrice = value;
                        service.quantity = 1;
                      });
                    },
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Text('Qty:'),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      if (service.quantity <= 1) {
                        return;
                      }
                      setState(() {
                        service.quantity -= 1;
                      });
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${service.quantity}'),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        service.quantity += 1;
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  const Spacer(),
                  TextButton(
                    key: ValueKey('price_button_${service.name}'),
                    onPressed: () async {
                      final value = await _openPriceDialog(service.unitPrice);
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        service.unitPrice = value;
                      });
                      unawaited(_persistServicePrices());
                    },
                    child: Text(
                      'Price: ${_currency.format(service.unitPrice)}',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientSection(String title, List<QuoteService> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text('No services selected in this section.')
            else
              ...items.map(
                (service) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(service.name),
                  subtitle: Text(
                    '${_billingLabel(service)} • Qty ${service.quantity} x ${_currency.format(service.unitPrice)}',
                  ),
                  trailing: Text(_currency.format(service.lineTotal)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoneyRow(String label, double amount, {bool emphasize = false}) {
    final valueStyle = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(_currency.format(amount), style: valueStyle),
      ],
    );
  }

  Future<double?> _openPriceDialog(double currentPrice) async {
    final controller = TextEditingController(
      text: currentPrice.toStringAsFixed(2),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Unit Price'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '\$'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || parsed < 0) {
                return;
              }
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    return result;
  }
}
