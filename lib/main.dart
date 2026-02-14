import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse, parseFragment;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
const _mobileAuthRedirectUri = 'urlinbox://login-callback/';
const _defaultWebAuthRedirectUri = 'https://inbox-19g.pages.dev/';
const _configuredWebAuthRedirectUri = String.fromEnvironment('WEB_AUTH_REDIRECT', defaultValue: _defaultWebAuthRedirectUri);

String get _authRedirectUri {
  if (!kIsWeb) return _mobileAuthRedirectUri;

  final candidate = _configuredWebAuthRedirectUri.trim();
  if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
    return candidate.endsWith('/') ? candidate : '$candidate/';
  }
  return _defaultWebAuthRedirectUri;
}

bool get _cloudConfigured => _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_cloudConfigured) {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  }
  runApp(const ProviderScope(child: UrlInboxApp()));
}

final repoProvider = Provider((_) => AppRepository());
final reminderProvider = Provider((_) => ReminderService());
final cloudSyncProvider = Provider<CloudSyncService?>((_) {
  if (!_cloudConfigured) return null;
  return CloudSyncService(Supabase.instance.client);
});
final appProvider = StateNotifierProvider<AppController, AppState>((ref) {
  return AppController(ref.read(repoProvider), ref.read(reminderProvider), ref.read(cloudSyncProvider));
});
final routerProvider = Provider<GoRouter>((_) => GoRouter(
      initialLocation: '/',
      overridePlatformDefaultLocation: true,
      errorBuilder: (_, __) => const RootPage(),
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const RootPage(),
          routes: [
            GoRoute(path: 'detail/:id', builder: (_, s) => LinkDetailPage(id: s.pathParameters['id']!)),
            GoRoute(path: 'folder/:id', builder: (_, s) => FolderLinksPage(id: s.pathParameters['id']!)),
          ],
        )
      ],
    ));

class UrlInboxApp extends ConsumerWidget {
  const UrlInboxApp({super.key});

  static const _tossBlue = Color(0xFF0064FF);
  static const _tossGreyBg = Color(0xFFF2F4F6);
  static const _tossDarkBg = Color(0xFF101012);
  static const _tossDarkSurface = Color(0xFF202022);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appProvider.select((s) => s.themeMode));
    
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _tossBlue,
        primary: _tossBlue,
        surface: Colors.white,
        surfaceContainerHighest: const Color(0xFFE5E8EB),
        outline: const Color(0xFFD1D6DB),
      ),
      scaffoldBackgroundColor: _tossGreyBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _tossGreyBg,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: Color(0xFF191F28), fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        iconTheme: IconThemeData(color: Color(0xFF191F28)),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: _tossBlue.withValues(alpha: 0.1),
        labelStyle: const TextStyle(color: Color(0xFF4E5968), fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: _tossBlue, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.transparent)),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF2F4F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _tossBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _tossBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _tossBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _tossBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const IconThemeData(color: _tossBlue);
          return const IconThemeData(color: Color(0xFFB0B8C1));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const TextStyle(color: _tossBlue, fontSize: 12, fontWeight: FontWeight.bold);
          return const TextStyle(color: Color(0xFFB0B8C1), fontSize: 12, fontWeight: FontWeight.w500);
        }),
        elevation: 0,
        height: 64,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF191F28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFF2F4F6), thickness: 1, space: 1),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _tossBlue,
        brightness: Brightness.dark,
        primary: _tossBlue,
        surface: _tossDarkSurface,
        surfaceContainerHighest: const Color(0xFF2C2C35),
        outline: const Color(0xFF4E5968),
      ),
      scaffoldBackgroundColor: _tossDarkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _tossDarkBg,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: _tossDarkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _tossDarkSurface,
        selectedColor: _tossBlue.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: _tossBlue, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.transparent)),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C35),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _tossBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: const TextStyle(color: Color(0xFF6B7684)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _tossBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _tossBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _tossBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _tossDarkSurface,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const IconThemeData(color: _tossBlue);
          return const IconThemeData(color: Color(0xFF6B7684));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const TextStyle(color: _tossBlue, fontSize: 12, fontWeight: FontWeight.bold);
          return const TextStyle(color: Color(0xFF6B7684), fontSize: 12, fontWeight: FontWeight.w500);
        }),
        elevation: 0,
        height: 64,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _tossDarkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _tossDarkSurface,
        modalBackgroundColor: _tossDarkSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2C2C35), thickness: 1, space: 1),
    );

    return MaterialApp.router(
      title: 'URL Inbox',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

enum InboxFilter { all, unread, starred, today }

enum SearchPeriod { all, day, week, month }

class LinkItem {
  const LinkItem({
    required this.id,
    required this.url,
    required this.normalizedUrl,
    required this.title,
    required this.domain,
    required this.createdAt,
    required this.updatedAt,
    required this.isRead,
    required this.isStarred,
    required this.isArchived,
    required this.tags,
    required this.note,
    this.description = '',
    this.imageUrl = '',
    this.faviconUrl = '',
    this.folderId,
    this.sourceApp,
    this.lastOpenedAt,
  });

  final String id;
  final String url;
  final String normalizedUrl;
  final String title;
  final String description;
  final String imageUrl;
  final String domain;
  final String faviconUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isRead;
  final bool isStarred;
  final bool isArchived;
  final List<String> tags;
  final String? folderId;
  final String note;
  final String? sourceApp;
  final DateTime? lastOpenedAt;

  LinkItem copyWith({bool? isRead, bool? isStarred, bool? isArchived, String? note, String? folderId, List<String>? tags, DateTime? updatedAt, DateTime? lastOpenedAt, String? title, String? description, String? imageUrl, String? faviconUrl}) {
    return LinkItem(
      id: id,
      url: url,
      normalizedUrl: normalizedUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      domain: domain,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRead: isRead ?? this.isRead,
      isStarred: isStarred ?? this.isStarred,
      isArchived: isArchived ?? this.isArchived,
      tags: tags ?? this.tags,
      folderId: folderId ?? this.folderId,
      note: note ?? this.note,
      sourceApp: sourceApp,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'url': url,
        'normalized_url': normalizedUrl,
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'domain': domain,
        'favicon_url': faviconUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_read': isRead ? 1 : 0,
        'is_starred': isStarred ? 1 : 0,
        'is_archived': isArchived ? 1 : 0,
        'tags': tags.join(','),
        'folder_id': folderId,
        'note': note,
        'source_app': sourceApp,
        'last_opened_at': lastOpenedAt?.toIso8601String(),
      };

  factory LinkItem.fromMap(Map<String, Object?> m) => LinkItem(
        id: m['id'] as String,
        url: m['url'] as String,
        normalizedUrl: m['normalized_url'] as String,
        title: (m['title'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        imageUrl: (m['image_url'] as String?) ?? '',
        domain: (m['domain'] as String?) ?? '',
        faviconUrl: (m['favicon_url'] as String?) ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        isRead: (m['is_read'] as int? ?? 0) == 1,
        isStarred: (m['is_starred'] as int? ?? 0) == 1,
        isArchived: (m['is_archived'] as int? ?? 0) == 1,
        tags: ((m['tags'] as String?) ?? '').split(',').where((e) => e.isNotEmpty).toList(),
        folderId: m['folder_id'] as String?,
        note: (m['note'] as String?) ?? '',
        sourceApp: m['source_app'] as String?,
        lastOpenedAt: (m['last_opened_at'] as String?) == null ? null : DateTime.parse(m['last_opened_at'] as String),
      );
}

class TagItem { const TagItem({required this.id, required this.name}); final String id; final String name; }
class FolderItem { const FolderItem({required this.id, required this.name, required this.sortOrder}); final String id; final String name; final int sortOrder; }

class AppState {
  const AppState({
    required this.loading,
    required this.links,
    required this.tags,
    required this.folders,
    required this.tab,
    required this.filter,
    required this.query,
    required this.searchDomain,
    required this.searchTag,
    required this.period,
    required this.clipboardEnabled,
    required this.reminderEnabled,
    required this.themeMode,
    required this.cloudConfigured,
    required this.signedIn,
    required this.authGatePassed,
    required this.syncing,
    this.userEmail,
    required this.candidate,
    required this.dismissedUrls,
    this.pendingTitleEditId,
  });

  final bool loading;
  final List<LinkItem> links;
  final List<TagItem> tags;
  final List<FolderItem> folders;
  final int tab;
  final InboxFilter filter;
  final String query;
  final String? searchDomain;
  final String? searchTag;
  final SearchPeriod period;
  final bool clipboardEnabled;
  final bool reminderEnabled;
  final ThemeMode themeMode;
  final bool cloudConfigured;
  final bool signedIn;
  final bool authGatePassed;
  final bool syncing;
  final String? userEmail;
  final String? candidate;
  final Set<String> dismissedUrls;
  final String? pendingTitleEditId;

  AppState copyWith({
    bool? loading,
    List<LinkItem>? links,
    List<TagItem>? tags,
    List<FolderItem>? folders,
    int? tab,
    InboxFilter? filter,
    String? query,
    String? searchDomain,
    String? searchTag,
    SearchPeriod? period,
    bool? clipboardEnabled,
    bool? reminderEnabled,
    ThemeMode? themeMode,
    bool? cloudConfigured,
    bool? signedIn,
    bool? authGatePassed,
    bool? syncing,
    String? userEmail,
    String? candidate,
    Set<String>? dismissedUrls,
    String? pendingTitleEditId,
  }) =>
      AppState(
        loading: loading ?? this.loading,
        links: links ?? this.links,
        tags: tags ?? this.tags,
        folders: folders ?? this.folders,
        tab: tab ?? this.tab,
        filter: filter ?? this.filter,
        query: query ?? this.query,
        searchDomain: searchDomain ?? this.searchDomain,
        searchTag: searchTag ?? this.searchTag,
        period: period ?? this.period,
        clipboardEnabled: clipboardEnabled ?? this.clipboardEnabled,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        themeMode: themeMode ?? this.themeMode,
        cloudConfigured: cloudConfigured ?? this.cloudConfigured,
        signedIn: signedIn ?? this.signedIn,
        authGatePassed: authGatePassed ?? this.authGatePassed,
        syncing: syncing ?? this.syncing,
        userEmail: userEmail ?? this.userEmail,
        candidate: candidate,
        dismissedUrls: dismissedUrls ?? this.dismissedUrls,
        pendingTitleEditId: pendingTitleEditId,
      );

  static const initial = AppState(
    loading: true,
    links: [],
    tags: [],
    folders: [],
    tab: 0,
    filter: InboxFilter.all,
    query: '',
    searchDomain: null,
    searchTag: null,
    period: SearchPeriod.all,
    clipboardEnabled: true,
    reminderEnabled: false,
    themeMode: ThemeMode.light,
    cloudConfigured: false,
    signedIn: false,
    authGatePassed: false,
    syncing: false,
    userEmail: null,
    candidate: null,
    dismissedUrls: {},
  );
}

class AppController extends StateNotifier<AppState> {
  AppController(this.repo, this.reminder, this.cloud) : super(AppState.initial) {
    _init();
  }

  final AppRepository repo;
  final ReminderService reminder;
  final CloudSyncService? cloud;
  StreamSubscription<AuthState>? _authSub;

  String? get _userId => _cloudConfigured ? Supabase.instance.client.auth.currentUser?.id : null;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _bindAuthState() {
    if (!_cloudConfigured) return;
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      final user = event.session?.user;
      if (user != null) {
        await repo.saveBool('guest_mode', false);
        state = state.copyWith(signedIn: true, userEmail: user.email, authGatePassed: true);
        await syncNow(silent: true);
      } else {
        final guestMode = await repo.getBool('guest_mode') ?? false;
        state = state.copyWith(signedIn: false, userEmail: null, authGatePassed: guestMode);
      }
    });
  }

  Future<void> signInWithGoogle() async {
    if (!_cloudConfigured) return;
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _authRedirectUri,
    );
  }

  Future<void> sendMagicLink(String email) async {
    if (!_cloudConfigured) return;
    await Supabase.instance.client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: _authRedirectUri,
    );
  }

  Future<void> signOutCloud() async {
    if (!_cloudConfigured) return;
    await Supabase.instance.client.auth.signOut();
    await repo.saveBool('guest_mode', false);
    state = state.copyWith(signedIn: false, userEmail: null, authGatePassed: false);
  }

  Future<void> continueWithoutLogin() async {
    await repo.saveBool('guest_mode', true);
    state = state.copyWith(authGatePassed: true);
  }

  Future<void> syncNow({bool silent = false}) async {
    if (cloud == null) return;
    final userId = _userId;
    if (userId == null) return;

    if (!silent) state = state.copyWith(syncing: true);
    try {
      final localFolders = await repo.folders();
      final localTags = await repo.tags();
      final localLinks = await repo.links();

      await cloud!.upsertFolders(userId, localFolders);
      await cloud!.upsertTags(userId, localTags);
      await cloud!.upsertLinks(userId, localLinks);

      final remoteFolders = await cloud!.fetchFolders(userId);
      final remoteTags = await cloud!.fetchTags(userId);
      final remoteLinks = await cloud!.fetchLinks(userId);

      await _mergeRemoteFolders(remoteFolders);
      await _mergeRemoteTags(remoteTags);
      await _mergeRemoteLinks(remoteLinks);
      await refresh();
    } finally {
      if (!silent) state = state.copyWith(syncing: false);
    }
  }

  Future<void> _mergeRemoteFolders(List<FolderItem> remote) async {
    for (final folder in remote) {
      await repo.upsertFolder(folder);
    }
  }

  Future<void> _mergeRemoteTags(List<TagItem> remote) async {
    for (final tag in remote) {
      await repo.upsertTag(tag);
    }
  }

  Future<void> _mergeRemoteLinks(List<LinkItem> remote) async {
    final current = await repo.links();
    final byNormalized = {for (final e in current) e.normalizedUrl: e};

    for (final remoteItem in remote) {
      final localItem = byNormalized[remoteItem.normalizedUrl];
      if (localItem != null && !remoteItem.updatedAt.isAfter(localItem.updatedAt)) {
        continue;
      }

      final merged = _mergeRemoteToLocal(remoteItem, localItem);
      await repo.upsert(merged);
      if (merged.tags.isNotEmpty) {
        await repo.ensureTags(merged.tags);
      }
    }
  }

  LinkItem _mergeRemoteToLocal(LinkItem remote, LinkItem? local) {
    return LinkItem(
      id: local?.id ?? _uuid.v4(),
      url: remote.url,
      normalizedUrl: remote.normalizedUrl,
      title: remote.title,
      description: remote.description,
      imageUrl: remote.imageUrl,
      domain: remote.domain,
      faviconUrl: remote.faviconUrl,
      createdAt: local?.createdAt ?? remote.createdAt,
      updatedAt: remote.updatedAt,
      isRead: remote.isRead,
      isStarred: remote.isStarred,
      isArchived: remote.isArchived,
      tags: remote.tags,
      folderId: remote.folderId ?? local?.folderId,
      note: remote.note,
      sourceApp: remote.sourceApp,
      lastOpenedAt: remote.lastOpenedAt,
    );
  }

  void _triggerBackgroundSync() {
    if (!state.signedIn) return;
    unawaited(syncNow(silent: true));
  }

  Future<void> onAppResumed() async {
    await checkClipboard();
    _triggerBackgroundSync();
  }

  Future<void> _init() async {
    final user = _cloudConfigured ? Supabase.instance.client.auth.currentUser : null;
    try {
      await repo.init();
      if (!kIsWeb) {
        await reminder.init();
      }
      final guestMode = await repo.getBool('guest_mode') ?? false;
      state = state.copyWith(
        loading: false,
        clipboardEnabled: await repo.getBool('clipboard_enabled') ?? true,
        reminderEnabled: await repo.getBool('reminder_enabled') ?? false,
        themeMode: _parseThemeMode(await repo.getString('theme_mode')),
        cloudConfigured: _cloudConfigured,
        signedIn: user != null,
        authGatePassed: user != null || guestMode,
        userEmail: user?.email,
      );
      _bindAuthState();
      await refresh();
      if (user != null) {
        await syncNow(silent: true);
      }
      // 공유 링크는 비동기로 처리 (UI 블로킹 방지)
      _processSharedLinksInBackground();
    } catch (e) {
      // 초기화 실패 시에도 앱이 로드되도록 함
      state = state.copyWith(
        loading: false,
        cloudConfigured: _cloudConfigured,
        signedIn: user != null,
        authGatePassed: user != null,
        userEmail: user?.email,
      );
      _bindAuthState();
    }
  }

  Future<void> _processSharedLinksInBackground() async {
    try {
      await ingestShared();
    } catch (_) {
      // 공유 처리 실패 무시
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(links: await repo.links(), tags: await repo.tags(), folders: await repo.folders());
    await _syncReminder();
  }

  List<LinkItem> get inbox {
    final base = state.links.where((e) => !e.isArchived).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return switch (state.filter) {
      InboxFilter.unread => base.where((e) => !e.isRead).toList(),
      InboxFilter.starred => base.where((e) => e.isStarred).toList(),
      InboxFilter.today => base.where((e) => DateTime.now().difference(e.createdAt).inDays == 0).toList(),
      InboxFilter.all => base,
    };
  }

  List<LinkItem> get searched => state.links.where((e) {
        final q = state.query.toLowerCase();
        final queryOk = q.isEmpty ||
            e.title.toLowerCase().contains(q) ||
            e.domain.toLowerCase().contains(q) ||
            e.note.toLowerCase().contains(q) ||
            e.tags.any((t) => t.toLowerCase().contains(q));
        final domainOk = state.searchDomain == null || e.domain == state.searchDomain;
        final tagOk = state.searchTag == null || e.tags.contains(state.searchTag);
        final periodOk = switch (state.period) {
          SearchPeriod.day => DateTime.now().difference(e.createdAt).inDays < 1,
          SearchPeriod.week => DateTime.now().difference(e.createdAt).inDays < 7,
          SearchPeriod.month => DateTime.now().difference(e.createdAt).inDays < 30,
          SearchPeriod.all => true,
        };
        return queryOk && domainOk && tagOk && periodOk;
      }).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<LinkItem?> addLink(String raw, {String? title, String? note, String? source}) async {
    final input = _sanitizeIncomingUrl(raw);
    if (input.isEmpty) return null;
    final url = _withScheme(input);
    if (!_isUrl(url)) return null;
    final normalized = _normalize(url);
    final existing = state.links.where((e) => e.normalizedUrl == normalized).firstOrNull;
    final meta = await Metadata.fetch(url);
    final primaryMedia = meta.mediaUrls.firstOrNull ?? meta.image;
    final now = DateTime.now();
    final autoTag = _domainTag(meta.domain);

    LinkItem savedItem;
    
    if (existing != null) {
      savedItem = existing.copyWith(
        title: title ?? meta.title ?? existing.title,
        description: meta.description ?? existing.description,
        imageUrl: primaryMedia ?? existing.imageUrl,
        faviconUrl: meta.profileImage ?? (existing.faviconUrl.isEmpty ? meta.favicon : existing.faviconUrl),
        note: (note == null || note.isEmpty) ? existing.note : note,
        tags: {...existing.tags, autoTag}.toList(),
        updatedAt: now,
      );
      await repo.upsert(savedItem);
      await repo.ensureTags(savedItem.tags);
    } else {
      savedItem = LinkItem(
        id: _uuid.v4(),
        url: url,
        normalizedUrl: normalized,
        title: title ?? meta.title ?? url,
        description: meta.description ?? '',
        imageUrl: primaryMedia ?? '',
        domain: meta.domain,
        faviconUrl: meta.profileImage ?? meta.favicon,
        createdAt: now,
        updatedAt: now,
        isRead: false,
        isStarred: false,
        isArchived: false,
        tags: [autoTag],
        folderId: null,
        note: note ?? '',
        sourceApp: source,
        lastOpenedAt: null,
      );
      await repo.upsert(savedItem);
      await repo.ensureTags(savedItem.tags);
    }
    await refresh();
    _triggerBackgroundSync();
    return savedItem;
  }

  bool isGenericTitle(String title) {
    final generic = [
      '네이버 카페', 'naver cafe', '네이버카페',
      '네이버 블로그', 'naver blog',
      '카카오톡', 'kakaotalk',
      '인스타그램', 'instagram',
      '페이스북', 'facebook',
      '트위터', 'twitter', 'x',
    ];
    final lower = title.toLowerCase().trim();
    return generic.any((g) => lower == g || lower.startsWith('$g ') || lower.endsWith(' $g'));
  }

  Future<List<LinkItem>> ingestShared() async {
    final shared = await ShareBridge.consume();
    final needsEdit = <LinkItem>[];
    for (final item in shared) {
      final url = item['url'] as String;
      final title = item['title'] as String?;
      final saved = await addLink(url, title: (title != null && title.isNotEmpty) ? title : null, source: 'shared');
      if (saved != null && (isGenericTitle(saved.title) || saved.title == saved.url || saved.title == saved.domain)) {
        needsEdit.add(saved);
      }
    }
    return needsEdit;
  }

  Future<void> checkClipboard() async {
    if (!state.clipboardEnabled) return;
    final txt = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (txt != null && _isUrl(txt)) {
      final normalized = _normalize(txt);
      if (!state.links.any((e) => e.normalizedUrl == normalized) && !state.dismissedUrls.contains(normalized)) {
        state = state.copyWith(candidate: txt);
      }
    }
  }

  Future<void> saveCandidate() async {
    final v = state.candidate;
    if (v != null) await addLink(v, source: 'clipboard');
    state = state.copyWith(candidate: null);
  }

  void dismissCandidate() {
    final v = state.candidate;
    if (v != null) {
      state = state.copyWith(candidate: null, dismissedUrls: {...state.dismissedUrls, _normalize(v)});
    }
  }
  Future<void> setTab(int v) async => state = state.copyWith(tab: v);
  Future<void> setFilter(InboxFilter v) async => state = state.copyWith(filter: v);
  Future<void> setQuery(String v) async => state = state.copyWith(query: v);
  Future<void> setSearchDomain(String? v) async => state = state.copyWith(searchDomain: v);
  Future<void> setSearchTag(String? v) async => state = state.copyWith(searchTag: v);
  Future<void> setPeriod(SearchPeriod v) async => state = state.copyWith(period: v);

  Future<void> toggleRead(LinkItem i) async {
    await repo.upsert(i.copyWith(isRead: !i.isRead, updatedAt: DateTime.now()));
    await refresh();
    _triggerBackgroundSync();
  }

  Future<void> toggleStar(LinkItem i) async {
    await repo.upsert(i.copyWith(isStarred: !i.isStarred, updatedAt: DateTime.now()));
    await refresh();
    _triggerBackgroundSync();
  }

  Future<void> archive(LinkItem i) async {
    await repo.upsert(i.copyWith(isArchived: true, updatedAt: DateTime.now()));
    await refresh();
    _triggerBackgroundSync();
  }

  Future<void> remove(LinkItem i) async {
    final userId = _userId;
    if (cloud != null && userId != null) {
      await cloud!.markDeleted(userId, i.normalizedUrl);
    }
    await repo.delete(i.id);
    await refresh();
    _triggerBackgroundSync();
  }

  Future<void> updateDetail(LinkItem i, {String? title, String? note, String? folderId, List<String>? tags}) async {
    await repo.upsert(i.copyWith(title: title, note: note, folderId: folderId, tags: tags, updatedAt: DateTime.now()));
    if (tags != null) await repo.ensureTags(tags);
    await refresh();
    _triggerBackgroundSync();
  }

  Future<void> openOriginal(LinkItem i) async {
    final uri = Uri.tryParse(i.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    await repo.upsert(i.copyWith(isRead: true, lastOpenedAt: DateTime.now(), updatedAt: DateTime.now()));
    await refresh();
    _triggerBackgroundSync();
  }

  Future<void> createTag(String name) async {
    final v = name.trim();
    if (v.isEmpty) return;
    await repo.insertTag(TagItem(id: _uuid.v4(), name: v));
    await refresh();
    _triggerBackgroundSync();
  }

  Future<void> createFolder(String name) async {
    final v = name.trim();
    if (v.isEmpty) return;
    await repo.insertFolder(FolderItem(id: _uuid.v4(), name: v, sortOrder: state.folders.length + 1));
    await refresh();
    _triggerBackgroundSync();
  }

  Future<void> removeFolder(String id) async {
    final userId = _userId;
    if (cloud != null && userId != null) {
      await cloud!.markFolderDeleted(userId, id);
    }
    await repo.deleteFolder(id);
    await refresh();
    _triggerBackgroundSync();
  }

  void clearPendingTitleEdit() {
    state = state.copyWith(pendingTitleEditId: null);
  }

  Future<void> setClipboardEnabled(bool v) async {
    await repo.saveBool('clipboard_enabled', v);
    state = state.copyWith(clipboardEnabled: v);
  }

  Future<void> setReminderEnabled(bool v) async {
    await repo.saveBool('reminder_enabled', v);
    state = state.copyWith(reminderEnabled: v);
    await _syncReminder();
  }

  Future<void> setThemeMode(ThemeMode v) async {
    final normalized = v == ThemeMode.system ? ThemeMode.light : v;
    await repo.saveString('theme_mode', normalized.name);
    state = state.copyWith(themeMode: normalized);
  }

  ThemeMode _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.light;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> _syncReminder() async {
    if (kIsWeb) return;
    if (!state.reminderEnabled) {
      return reminder.cancel();
    }
    await reminder.schedule(state.links.where((e) => !e.isRead && !e.isArchived).length);
  }

}

class AppRepository {
  Database? _db;
  static const _dbVersion = 2;

  Future<void> init() async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'url_inbox.db'),
      version: _dbVersion,
      onCreate: (db, _) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _migrate(db, oldVersion, newVersion);
      },
      onOpen: (db) async {
        await _repairSchema(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS links(id TEXT PRIMARY KEY,url TEXT,normalized_url TEXT UNIQUE,title TEXT,description TEXT,image_url TEXT,domain TEXT,favicon_url TEXT,created_at TEXT,updated_at TEXT,is_read INTEGER,is_starred INTEGER,is_archived INTEGER,tags TEXT,folder_id TEXT,note TEXT,source_app TEXT,last_opened_at TEXT)',
    );
    await db.execute('CREATE TABLE IF NOT EXISTS tags(id TEXT PRIMARY KEY,name TEXT UNIQUE)');
    await db.execute('CREATE TABLE IF NOT EXISTS folders(id TEXT PRIMARY KEY,name TEXT UNIQUE,sort_order INTEGER)');
  }

  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _repairSchema(db);
    }
  }

  Future<void> _repairSchema(Database db) async {
    await _createSchema(db);

    final linkCols = await _tableColumns(db, 'links');
    final linkAdditions = <String, String>{
      'description': "TEXT DEFAULT ''",
      'image_url': "TEXT DEFAULT ''",
      'favicon_url': "TEXT DEFAULT ''",
      'is_read': 'INTEGER NOT NULL DEFAULT 0',
      'is_starred': 'INTEGER NOT NULL DEFAULT 0',
      'is_archived': 'INTEGER NOT NULL DEFAULT 0',
      'tags': "TEXT DEFAULT '[]'",
      'note': "TEXT DEFAULT ''",
      'source_app': 'TEXT',
      'last_opened_at': 'TEXT',
      'folder_id': 'TEXT',
      'created_at': 'TEXT',
      'updated_at': 'TEXT',
    };
    for (final entry in linkAdditions.entries) {
      if (!linkCols.contains(entry.key)) {
        await db.execute('ALTER TABLE links ADD COLUMN ${entry.key} ${entry.value}');
      }
    }

    final now = DateTime.now().toIso8601String();
    await db.rawUpdate("UPDATE links SET created_at = ? WHERE created_at IS NULL OR created_at = ''", [now]);
    await db.rawUpdate("UPDATE links SET updated_at = COALESCE(NULLIF(updated_at, ''), created_at, ?) WHERE updated_at IS NULL OR updated_at = ''", [now]);

    final folderCols = await _tableColumns(db, 'folders');
    if (!folderCols.contains('sort_order')) {
      await db.execute('ALTER TABLE folders ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
      await db.rawUpdate('UPDATE folders SET sort_order = rowid WHERE sort_order IS NULL OR sort_order = 0');
    }
  }

  Future<Set<String>> _tableColumns(DatabaseExecutor db, String tableName) async {
    final rows = await db.rawQuery('PRAGMA table_info($tableName)');
    return rows.map((r) => (r['name'] as String).toLowerCase()).toSet();
  }

  Future<Database> get db async {
    await init();
    return _db!;
  }

  Future<List<LinkItem>> links() async => (await (await db).query('links')).map(LinkItem.fromMap).toList();

  Future<void> upsert(LinkItem item) async {
    await (await db).insert('links', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    await (await db).delete('links', where: 'id=?', whereArgs: [id]);
  }

  Future<List<TagItem>> tags() async {
    return (await (await db).query('tags', orderBy: 'name ASC')).map((e) => TagItem(id: e['id'] as String, name: e['name'] as String)).toList();
  }

  Future<void> ensureTags(List<String> names) async {
    final d = await db;
    for (final n in names) {
      final v = n.trim();
      if (v.isNotEmpty) {
        await d.insert('tags', {'id': _uuid.v4(), 'name': v}, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<void> insertTag(TagItem t) async {
    await (await db).insert('tags', {'id': t.id, 'name': t.name}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> upsertTag(TagItem t) async {
    final d = await db;
    final byName = await d.query('tags', where: 'name = ?', whereArgs: [t.name], limit: 1);
    if (byName.isNotEmpty) return;
    await d.insert('tags', {'id': t.id, 'name': t.name}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FolderItem>> folders() async {
    return (await (await db).query('folders', orderBy: 'sort_order ASC'))
        .map((e) => FolderItem(id: e['id'] as String, name: e['name'] as String, sortOrder: e['sort_order'] as int))
        .toList();
  }

  Future<void> insertFolder(FolderItem f) async {
    await (await db).insert('folders', {'id': f.id, 'name': f.name, 'sort_order': f.sortOrder}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> upsertFolder(FolderItem f) async {
    final d = await db;
    final byId = await d.query('folders', where: 'id = ?', whereArgs: [f.id], limit: 1);
    if (byId.isNotEmpty) {
      await d.update('folders', {'name': f.name, 'sort_order': f.sortOrder}, where: 'id = ?', whereArgs: [f.id]);
      return;
    }
    await d.insert('folders', {'id': f.id, 'name': f.name, 'sort_order': f.sortOrder}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> deleteFolder(String id) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.update('links', {'folder_id': null}, where: 'folder_id = ?', whereArgs: [id]);
      await txn.delete('folders', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<bool?> getBool(String key) async => (await SharedPreferences.getInstance()).getBool(key);

  Future<void> saveBool(String key, bool value) async => (await SharedPreferences.getInstance()).setBool(key, value);

  Future<String?> getString(String key) async => (await SharedPreferences.getInstance()).getString(key);

  Future<void> saveString(String key, String value) async => (await SharedPreferences.getInstance()).setString(key, value);

}

class CloudSyncService {
  CloudSyncService(this.client);

  final SupabaseClient client;

  Future<void> upsertFolders(String userId, List<FolderItem> folders) async {
    if (folders.isEmpty) return;
    for (final folder in folders) {
      final row = {
        'id': folder.id,
        'user_id': userId,
        'name': folder.name,
        'sort_order': folder.sortOrder,
        'updated_at': DateTime.now().toIso8601String(),
        'deleted_at': null,
      };
      try {
        await client.from('folders').upsert(row, onConflict: 'id');
      } catch (_) {
        await client.from('folders').update({
          'sort_order': folder.sortOrder,
          'updated_at': DateTime.now().toIso8601String(),
          'deleted_at': null,
        }).eq('user_id', userId).eq('name', folder.name);
      }
    }
  }

  Future<void> upsertTags(String userId, List<TagItem> tags) async {
    if (tags.isEmpty) return;
    for (final tag in tags) {
      final row = {
        'id': tag.id,
        'user_id': userId,
        'name': tag.name,
        'updated_at': DateTime.now().toIso8601String(),
        'deleted_at': null,
      };
      try {
        await client.from('tags').upsert(row, onConflict: 'id');
      } catch (_) {
        await client.from('tags').update({
          'updated_at': DateTime.now().toIso8601String(),
          'deleted_at': null,
        }).eq('user_id', userId).eq('name', tag.name);
      }
    }
  }

  Future<void> markFolderDeleted(String userId, String folderId) async {
    await client.from('folders').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId).eq('id', folderId);
  }

  Future<List<FolderItem>> fetchFolders(String userId) async {
    final data = await client.from('folders').select().eq('user_id', userId).order('sort_order', ascending: true);
    final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final out = <FolderItem>[];
    for (final row in rows) {
      if (row['deleted_at'] != null) continue;
      final id = (row['id'] as String?) ?? '';
      final name = (row['name'] as String?) ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      final order = (row['sort_order'] as num?)?.toInt() ?? 0;
      out.add(FolderItem(id: id, name: name, sortOrder: order));
    }
    return out;
  }

  Future<List<TagItem>> fetchTags(String userId) async {
    final data = await client.from('tags').select().eq('user_id', userId).order('name', ascending: true);
    final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final out = <TagItem>[];
    for (final row in rows) {
      if (row['deleted_at'] != null) continue;
      final id = (row['id'] as String?) ?? '';
      final name = (row['name'] as String?) ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      out.add(TagItem(id: id, name: name));
    }
    return out;
  }

  Future<void> upsertLinks(String userId, List<LinkItem> links) async {
    if (links.isEmpty) return;
    final payload = links
        .map((e) => {
              'user_id': userId,
              'url': e.url,
              'normalized_url': e.normalizedUrl,
              'title': e.title,
              'description': e.description,
              'image_url': e.imageUrl,
              'domain': e.domain,
              'favicon_url': e.faviconUrl,
              'is_read': e.isRead,
              'is_starred': e.isStarred,
              'is_archived': e.isArchived,
              'tags': e.tags,
              'folder_id': e.folderId,
              'note': e.note,
              'source_app': e.sourceApp,
              'last_opened_at': e.lastOpenedAt?.toIso8601String(),
              'created_at': e.createdAt.toIso8601String(),
              'updated_at': e.updatedAt.toIso8601String(),
              'deleted_at': null,
            })
        .toList();

    await client.from('links').upsert(payload, onConflict: 'user_id,normalized_url');
  }

  Future<void> markDeleted(String userId, String normalizedUrl) async {
    await client.from('links').update({
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId).eq('normalized_url', normalizedUrl);
  }

  Future<List<LinkItem>> fetchLinks(String userId) async {
    final data = await client.from('links').select().eq('user_id', userId).order('updated_at', ascending: false);
    final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final out = <LinkItem>[];
    for (final row in rows) {
      if (row['deleted_at'] != null) continue;

      final url = (row['url'] as String?) ?? '';
      if (url.isEmpty) continue;
      final normalized = (row['normalized_url'] as String?) ?? _normalize(url);
      final createdAt = DateTime.tryParse((row['created_at'] as String?) ?? '') ?? DateTime.now();
      final updatedAt = DateTime.tryParse((row['updated_at'] as String?) ?? '') ?? createdAt;

      out.add(LinkItem(
        id: _uuid.v4(),
        url: url,
        normalizedUrl: normalized,
        title: (row['title'] as String?) ?? url,
        description: (row['description'] as String?) ?? '',
        imageUrl: (row['image_url'] as String?) ?? '',
        domain: (row['domain'] as String?) ?? (Uri.tryParse(url)?.host ?? ''),
        faviconUrl: (row['favicon_url'] as String?) ?? '',
        createdAt: createdAt,
        updatedAt: updatedAt,
        isRead: _toBool(row['is_read']),
        isStarred: _toBool(row['is_starred']),
        isArchived: _toBool(row['is_archived']),
        tags: _toTags(row['tags']),
        folderId: row['folder_id'] as String?,
        note: (row['note'] as String?) ?? '',
        sourceApp: row['source_app'] as String?,
        lastOpenedAt: DateTime.tryParse((row['last_opened_at'] as String?) ?? ''),
      ));
    }
    return out;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  List<String> _toTags(dynamic value) {
    if (value is List) {
      return value.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    if (value is String) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }
}

class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  Future<void> schedule(int unread) async {
    if (unread <= 0) return _plugin.cancel(9001);
    await _plugin.periodicallyShow(
      9001,
      'URL Inbox 리마인더',
      '읽지 않은 링크 $unread개가 있습니다.',
      RepeatInterval.daily,
      const NotificationDetails(android: AndroidNotificationDetails('daily', 'Daily')),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel() async {
    await _plugin.cancel(9001);
  }
}

class ShareBridge {
  static const _channel = MethodChannel('url_inbox/share');

  static Future<List<Map<String, dynamic>>> consume() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('consumeSharedUrls');
      if (raw == null) return const [];

      if (raw is String) {
        if (raw.trim().isEmpty || raw == '[]') return const [];
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) {
            if (e is Map) return Map<String, dynamic>.from(e);
            if (e is String) return {'url': e, 'title': ''};
            return <String, dynamic>{};
          }).where((e) => (e['url'] as String?)?.isNotEmpty == true).toList();
        }
      }

      if (raw is List) {
        return raw.map((e) {
          if (e is Map) return Map<String, dynamic>.from(e);
          if (e is String) return {'url': e, 'title': ''};
          return <String, dynamic>{};
        }).where((e) => (e['url'] as String?)?.isNotEmpty == true).toList();
      }

      return const [];
    } catch (_) {
      return const [];
    }
  }
}

class Meta {
  const Meta({required this.domain, required this.favicon, this.title, this.description, this.image, this.profileImage, this.mediaUrls = const []});

  final String domain;
  final String favicon;
  final String? title;
  final String? description;
  final String? image;
  final String? profileImage;
  final List<String> mediaUrls;
}

class XAssets {
  const XAssets({this.profileImageUrl, this.mediaUrls = const []});

  final String? profileImageUrl;
  final List<String> mediaUrls;
}

class Metadata {
  static Future<Meta> fetch(String url) async {
    final uri = Uri.parse(url);
    var domain = uri.host.replaceFirst('www.', '');
    final favicon = '${uri.scheme}://$domain/favicon.ico';
    final requestTimeout = (domain.contains('naver.com') || _isXDomain(domain)) ? const Duration(seconds: 8) : const Duration(seconds: 4);

    String? youtubeImage;
    if (domain.contains('youtube.com') || domain.contains('youtu.be')) {
      final videoId = _extractYoutubeId(url);
      if (videoId != null) youtubeImage = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
    }

    final client = http.Client();
    try {
      String? xProfileImage;
      var xMediaUrls = <String>[];

      // 1. 기본 요청 (리다이렉트 확인용)
      final normalizedUri = _normalizeNaverCafeUri(uri);
      var request = http.Request('GET', normalizedUri);
      // 네이버 카페 앱 느낌의 User-Agent 사용
      request.headers['User-Agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1';
      request.headers['Accept-Language'] = 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7';
      request.followRedirects = true;
      request.maxRedirects = 5;

      var streamedResponse = await client.send(request).timeout(requestTimeout);
      var res = await http.Response.fromStream(streamedResponse);
      var finalUrl = streamedResponse.request?.url ?? normalizedUri;
      var finalDomain = finalUrl.host.replaceFirst('www.', '');

      // 2. 만약 네이버 카페 PC 버전으로 리다이렉트 되었다면, 모바일로 강제 전환 후 재요청
      final mobileTarget = _toNaverCafeMobileUrl(finalUrl);
      if (mobileTarget != null && mobileTarget.toString() != finalUrl.toString()) {
        debugPrint('Converting Naver URL to Mobile: $mobileTarget');
        final mRequest = http.Request('GET', mobileTarget);
        mRequest.headers['User-Agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1';
        mRequest.headers['Accept-Language'] = 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7';
        mRequest.followRedirects = true;
        mRequest.maxRedirects = 5;

        final mStreamed = await client.send(mRequest).timeout(requestTimeout);
        res = await http.Response.fromStream(mStreamed);
        finalUrl = mStreamed.request?.url ?? mobileTarget;
        finalDomain = finalUrl.host.replaceFirst('www.', '');
      }

      if ((_isXDomain(domain) || _isXDomain(finalDomain)) && res.statusCode >= 400) {
        final xSource = _isXDomain(finalUrl.host) ? finalUrl : uri;
        final xFallback = await _fetchXFallback(client, xSource, requestTimeout);
        final xOEmbed = await _fetchXOEmbedFallback(client, xSource, requestTimeout);

        if (xFallback != null || xOEmbed != null) {
          final media = _mergeUniqueUrls(
            _toStringList(xFallback?['mediaUrls']),
            _toStringList(xOEmbed?['mediaUrls']),
          );
          final mergedProfile = _pickBetterXProfile(
            xFallback?['profileImage'] as String?,
            xOEmbed?['profileImage'] as String?,
          );
          return Meta(
            domain: _isXDomain(finalDomain) ? finalDomain : domain,
            favicon: favicon,
            title: _firstNonBlank([xFallback?['title'] as String?, xOEmbed?['title'] as String?, uri.toString()]),
            description: _firstNonBlank([xFallback?['description'] as String?, xOEmbed?['description'] as String?]),
            image: _firstNonBlank([xFallback?['image'] as String?, xOEmbed?['image'] as String?, media.firstOrNull]),
            profileImage: mergedProfile,
            mediaUrls: media,
          );
        }
      }

      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      final document = parse(body);
      debugPrint('Deep Fetch Status: ${res.statusCode}');
      debugPrint('Body length: ${body.length}');

      // 3. 데이터 추출 (네이버 카페 모바일 특화 셀렉터 추가)
      String? title = _firstNonBlank([
        _findMeta(document, ['og:title', 'twitter:title']),
        _textOfSelectors(document, ['h2.tit', '.title_area .title', '.article_title', '.item_title', '.title', '.ArticleTitle', '.se-title-text']),
        document.querySelector('title')?.text,
      ]);

      String? description = _firstNonBlank([
        _findMeta(document, ['og:description', 'twitter:description', 'description']),
        _textOfSelectors(document, [
          '.post_area',
          '.article_viewer',
          '#postContent',
          '.content_area',
          '.post_view',
          '.se-main-container',
          '.se-component-content',
          '.ContentRenderer',
          '.ArticleContentBox',
          '.article_container',
        ]),
      ]);

      String? image = _findMeta(document, ['og:image', 'twitter:image', 'image']);
      image ??= _firstImageFromSelectors(document, [
        '.post_area img',
        '.article_viewer img',
        '#postContent img',
        '.content_area img',
        '.post_view img',
        '.se-main-container img',
        '.se-component img',
        '.ContentRenderer img',
        '.ArticleContentBox img',
      ]);

      if (_isXDomain(finalDomain)) {
        final xAssets = _extractXAssetsFromDocument(document, finalUrl);
        xProfileImage = _pickBetterXProfile(
          xAssets.profileImageUrl,
          _profileImageFromHandle(_extractXHandleFromUrl(finalUrl.toString())),
        );
        xMediaUrls = _mergeUniqueUrls(xMediaUrls, xAssets.mediaUrls);
        image = _firstNonBlank([image, xMediaUrls.firstOrNull]);
      }

      if (_isXDomain(finalDomain) && _isWeakXMeta(title, description, image)) {
        final xFallback = await _fetchXFallback(client, finalUrl, requestTimeout);
        if (xFallback != null) {
          final fallbackTitle = xFallback['title'];
          if (_isGenericXTitle(title) && fallbackTitle != null) {
            title = fallbackTitle;
          }
          description = _firstNonBlank([description, xFallback['description']]);
          image = _firstNonBlank([image, xFallback['image']]);
          xProfileImage = _pickBetterXProfile(xProfileImage, xFallback['profileImage'] as String?);
          xMediaUrls = _mergeUniqueUrls(xMediaUrls, _toStringList(xFallback['mediaUrls']));
        }

        if (_isWeakXMeta(title, description, image)) {
          final xOEmbed = await _fetchXOEmbedFallback(client, finalUrl, requestTimeout);
          if (xOEmbed != null) {
            final oEmbedTitle = xOEmbed['title'];
            if (_isGenericXTitle(title) && oEmbedTitle != null) {
              title = oEmbedTitle;
            }
            description = _firstNonBlank([description, xOEmbed['description']]);
            image = _firstNonBlank([image, xOEmbed['image']]);
            xProfileImage = _pickBetterXProfile(xProfileImage, xOEmbed['profileImage'] as String?);
            xMediaUrls = _mergeUniqueUrls(xMediaUrls, _toStringList(xOEmbed['mediaUrls']));
          }
        }
      }

      // 4. 네이버 카페 제목이 여전히 불량할 경우 (설명 첫 줄 활용)
      if ((title == null || title.trim().isEmpty || title.trim() == '네이버 카페' || title.trim() == 'Naver Cafe') && description != null) {
        final lines = description.split('\n').map((l) => l.trim()).where((l) => l.length > 2).toList();
        if (lines.isNotEmpty) title = lines.first;
      }

      // 제목이 여전히 없으면 URL이나 도메인 사용
      title = _firstNonBlank([title, finalUrl.toString().length > 30 ? finalDomain : finalUrl.toString()]);
      description = _firstNonBlank([description]);

      // 이미지 절대 경로 해결
      if (image != null && image.trim().isNotEmpty) {
        image = finalUrl.resolve(image).toString();
      } else {
        image = youtubeImage;
      }

      if (_isXDomain(finalDomain)) {
        xMediaUrls = _mergeUniqueUrls(xMediaUrls, [if (image != null) image]);
      }

      return Meta(
        domain: finalDomain,
        favicon: favicon,
        title: title,
        description: description,
        image: image,
        profileImage: xProfileImage,
        mediaUrls: xMediaUrls,
      );
    } catch (e) {
      debugPrint('Metadata fetch error: $e');
      return Meta(domain: domain, favicon: favicon, image: youtubeImage);
    } finally {
      client.close();
    }
  }

  static Uri _normalizeNaverCafeUri(Uri uri) {
    final mobile = _toNaverCafeMobileUrl(uri);
    return mobile ?? uri;
  }

  static Uri? _toNaverCafeMobileUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!(host == 'cafe.naver.com' || host == 'm.cafe.naver.com')) return null;

    if (host == 'm.cafe.naver.com' && uri.pathSegments.length >= 2) {
      return uri;
    }

    final iframeUrl = uri.queryParameters['iframe_url'];
    if (iframeUrl != null && iframeUrl.isNotEmpty) {
      final decoded = Uri.decodeComponent(iframeUrl);
      final iframeUri = Uri.tryParse(decoded);
      if (iframeUri != null) {
        final iframeClubId = iframeUri.queryParameters['clubid'];
        final iframeArticleId = iframeUri.queryParameters['articleid'];
        if (_isNotBlank(iframeClubId) && _isNotBlank(iframeArticleId)) {
          return Uri.parse('https://m.cafe.naver.com/${iframeClubId!.trim()}/${iframeArticleId!.trim()}');
        }
      }
    }

    final clubId = uri.queryParameters['clubid'];
    final articleId = uri.queryParameters['articleid'];
    if (_isNotBlank(clubId) && _isNotBlank(articleId)) {
      return Uri.parse('https://m.cafe.naver.com/${clubId!.trim()}/${articleId!.trim()}');
    }

    final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (host == 'cafe.naver.com' && pathSegments.length >= 2 && pathSegments[0] != 'ca-fe') {
      return Uri.parse('https://m.cafe.naver.com/${pathSegments[0]}/${pathSegments[1]}');
    }

    return null;
  }

  static String? _findMeta(dynamic doc, List<String> properties) {
    for (final prop in properties) {
      // property 또는 name 속성 모두 체크
      final element = doc.querySelector('meta[property="$prop"]') ?? doc.querySelector('meta[name="$prop"]');
      final content = element?.attributes['content'];
      if (content != null && content.trim().isNotEmpty) return content.trim();
    }
    return null;
  }

  static String? _extractYoutubeId(String url) {
    final reg = RegExp(r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})', caseSensitive: false);
    return reg.firstMatch(url)?.group(1);
  }

  static String? _textOfSelectors(dynamic doc, List<String> selectors) {
    for (final selector in selectors) {
      final text = doc.querySelector(selector)?.text;
      final normalized = _normalizeText(text);
      if (normalized != null) return normalized;
    }
    return null;
  }

  static String? _firstImageFromSelectors(dynamic doc, List<String> selectors) {
    for (final selector in selectors) {
      final elements = doc.querySelectorAll(selector);
      for (final element in elements) {
        final src = _firstNonBlank([
          element.attributes['data-src'],
          element.attributes['data-lazy-src'],
          element.attributes['data-original'],
          element.attributes['src'],
        ]);
        if (src == null || src.startsWith('data:')) continue;
        if (src.contains('spacer') || src.contains('blank') || src.contains('default_profile')) continue;
        return src;
      }
    }
    return null;
  }

  static String? _firstNonBlank(Iterable<String?> values) {
    for (final value in values) {
      final normalized = _normalizeText(value);
      if (normalized != null) return normalized;
    }
    return null;
  }

  static String? _normalizeText(String? value) {
    if (value == null) return null;
    final cleaned = value
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static bool _isNotBlank(String? value) => value != null && value.trim().isNotEmpty;

  static bool _isXDomain(String host) {
    final h = host.toLowerCase();
    return h == 'x.com' ||
        h.endsWith('.x.com') ||
        h == 'twitter.com' ||
        h.endsWith('.twitter.com') ||
        h == 'fixupx.com' ||
        h.endsWith('.fixupx.com') ||
        h == 'fxtwitter.com' ||
        h.endsWith('.fxtwitter.com') ||
        h == 'vxtwitter.com' ||
        h.endsWith('.vxtwitter.com');
  }

  static bool _isGenericXTitle(String? title) {
    if (title == null) return true;
    final t = title.trim().toLowerCase();
    return t.isEmpty || t == 'x' || t == 'twitter' || t == '트위터' || t == 'x / twitter' || t == 'x (formerly twitter)';
  }

  static bool _isWeakXMeta(String? title, String? description, String? image) {
    final hasDescription = description != null && description.trim().length >= 12;
    final hasImage = image != null && image.trim().isNotEmpty;
    final lowerTitle = title?.toLowerCase() ?? '';
    final lowerDesc = description?.toLowerCase() ?? '';
    final blockedLike = lowerTitle.contains('attention required') ||
        lowerTitle.contains('just a moment') ||
        lowerTitle.contains('access denied') ||
        lowerDesc.contains('cloudflare') ||
        lowerDesc.contains('enable javascript and cookies');
    return blockedLike || _isGenericXTitle(title) || (!hasDescription && !hasImage);
  }

  static Uri? _toFixupXUri(Uri uri) {
    if (!_isXDomain(uri.host)) return null;
    if (uri.host.toLowerCase().contains('fixupx.com')) return uri;
    return uri.replace(host: 'fixupx.com');
  }

  static Future<Map<String, dynamic>?> _fetchXFallback(http.Client client, Uri sourceUrl, Duration timeout) async {
    final fallbackUri = _toFixupXUri(sourceUrl);
    if (fallbackUri == null) return null;

    try {
      final request = http.Request('GET', fallbackUri);
      request.headers['User-Agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1';
      request.headers['Accept-Language'] = 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7';
      request.followRedirects = true;
      request.maxRedirects = 5;

      final streamed = await client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 400) return null;

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final document = parse(body);
      final title = _firstNonBlank([
        _findMeta(document, ['og:title', 'twitter:title']),
        document.querySelector('title')?.text,
      ]);
      final description = _firstNonBlank([
        _findMeta(document, ['og:description', 'twitter:description', 'description']),
      ]);
      final assets = _extractXAssetsFromDocument(document, fallbackUri);
      final creatorHandle = _extractXHandle(_firstNonBlank([
        _findMeta(document, ['twitter:site', 'twitter:creator']),
      ]));
      final imageRaw = _firstNonBlank([
        _findMeta(document, ['og:image', 'twitter:image', 'image']),
      ]);
      final image = _firstNonBlank([
        imageRaw == null ? null : fallbackUri.resolve(imageRaw).toString(),
        assets.mediaUrls.firstOrNull,
      ]);

      if (title == null && description == null && image == null && assets.profileImageUrl == null && assets.mediaUrls.isEmpty) return null;
      return {
        'title': title,
        'description': description,
        'image': image,
        'profileImage': _firstNonBlank([assets.profileImageUrl, _profileImageFromHandle(creatorHandle)]),
        'mediaUrls': assets.mediaUrls,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _fetchXOEmbedFallback(http.Client client, Uri sourceUrl, Duration timeout) async {
    final normalizedSource = _normalizeXSourceUri(sourceUrl);
    if (!_isXDomain(normalizedSource.host) && !normalizedSource.host.toLowerCase().contains('twitter.com')) return null;

    try {
      final oembedUri = Uri.https('publish.twitter.com', '/oembed', {
        'url': normalizedSource.toString(),
        'omit_script': '1',
      });

      final request = http.Request('GET', oembedUri);
      request.headers['Accept'] = 'application/json';
      request.headers['User-Agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1';
      request.followRedirects = true;
      request.maxRedirects = 5;

      final streamed = await client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 400) return null;

      final raw = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);

      final description = _extractTweetTextFromEmbedHtml(map['html'] as String?);
      final authorUrl = _normalizeText(map['author_url'] as String?);
      final handle = _extractXHandleFromUrl(authorUrl);
      final title = _firstNonBlank([
        _shortenSingleLine(description, 72),
        _normalizeText(map['author_name'] as String?),
        _normalizeText(map['url'] as String?),
      ]);
      final image = _normalizeText(map['thumbnail_url'] as String?);

      if (title == null && description == null && image == null) return null;
      return {
        'title': title,
        'description': description,
        'image': image,
        'profileImage': _profileImageFromHandle(handle),
        'mediaUrls': image == null ? <String>[] : <String>[image],
      };
    } catch (_) {
      return null;
    }
  }

  static XAssets _extractXAssetsFromDocument(dynamic doc, Uri baseUri) {
    final profileRaw = _firstNonBlank([
      doc.querySelector('link[rel="apple-touch-icon"]')?.attributes['href'],
      doc.querySelector('meta[property="twitter:creator:image"]')?.attributes['content'],
      doc.querySelector('meta[name="twitter:creator:image"]')?.attributes['content'],
      doc.querySelector('meta[property="og:image:user_generated"]')?.attributes['content'],
    ]);
    final profileImageResolved = profileRaw == null ? null : baseUri.resolve(profileRaw).toString();
    final profileImage = _isGenericXProfileImage(profileImageResolved) ? null : profileImageResolved;

    final media = <String>[];
    void addMediaFromMeta(String selector) {
      for (final element in doc.querySelectorAll(selector)) {
        final raw = _normalizeText(element.attributes['content']);
        if (raw == null) continue;
        if (raw.startsWith('data:')) continue;
        final resolved = baseUri.resolve(raw).toString();
        media.add(resolved);
      }
    }

    addMediaFromMeta('meta[property="og:image"]');
    addMediaFromMeta('meta[name="og:image"]');
    addMediaFromMeta('meta[property="twitter:image"]');
    addMediaFromMeta('meta[name="twitter:image"]');
    addMediaFromMeta('meta[property="og:video"]');
    addMediaFromMeta('meta[property="og:video:url"]');
    addMediaFromMeta('meta[property="twitter:player:stream"]');
    addMediaFromMeta('meta[name="twitter:player:stream"]');

    final mediaUrls = _mergeUniqueUrls([], media.where((e) {
      final lower = e.toLowerCase();
      if (lower.contains('default_profile') || lower.contains('profile_images') || lower.contains('avatar')) return false;
      if (lower.contains('spacer') || lower.contains('blank')) return false;
      return true;
    }));

    return XAssets(profileImageUrl: profileImage, mediaUrls: mediaUrls);
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => _normalizeText(e?.toString())).whereType<String>().toList();
    }
    return const [];
  }

  static List<String> _mergeUniqueUrls(Iterable<String> base, Iterable<String> extra) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in [...base, ...extra]) {
      final normalized = _normalizeText(raw);
      if (normalized == null) continue;
      if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) continue;
      if (seen.add(normalized)) out.add(normalized);
    }
    return out;
  }

  static String? _extractXHandle(String? raw) {
    final v = _normalizeText(raw);
    if (v == null) return null;
    return v.replaceFirst('@', '').trim().split(' ').firstOrNull;
  }

  static String? _extractXHandleFromUrl(String? rawUrl) {
    final v = _normalizeText(rawUrl);
    if (v == null) return null;
    final uri = Uri.tryParse(v);
    if (uri == null) return null;
    final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (seg.isEmpty) return null;
    if (seg.first == 'i') return null;
    return seg.first;
  }

  static String? _profileImageFromHandle(String? handle) {
    final h = _normalizeText(handle);
    if (h == null) return null;
    final normalized = h.replaceFirst('@', '').trim();
    if (normalized.isEmpty) return null;
    return 'https://unavatar.io/x/$normalized';
  }

  static String? _pickBetterXProfile(String? primary, String? secondary) {
    final p = _normalizeText(primary);
    final s = _normalizeText(secondary);
    if (p == null) return s;
    if (s == null) return p;
    if (_isGenericXProfileImage(p) && !_isGenericXProfileImage(s)) return s;
    return p;
  }

  static bool _isGenericXProfileImage(String? url) {
    final u = _normalizeText(url)?.toLowerCase();
    if (u == null || u.isEmpty) return true;
    if (u.contains('abs.twimg.com/responsive-web/client-web/icon-ios')) return true;
    if (u.contains('abs.twimg.com/responsive-web/client-web/icon-')) return true;
    if (u.endsWith('/icon-ios.png') || u.endsWith('/icon.svg')) return true;
    return false;
  }

  static Uri _normalizeXSourceUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'x.com' || host.endsWith('.x.com') || host.contains('fixupx.com') || host.contains('fxtwitter.com') || host.contains('vxtwitter.com')) {
      return uri.replace(host: 'twitter.com');
    }
    return uri;
  }

  static String? _extractTweetTextFromEmbedHtml(String? html) {
    if (html == null || html.trim().isEmpty) return null;
    try {
      final fragment = parseFragment(html);
      final text = fragment.querySelector('p')?.text ?? fragment.text;
      return _normalizeText(text);
    } catch (_) {
      return null;
    }
  }

  static String? _shortenSingleLine(String? text, int maxLength) {
    final normalized = _normalizeText(text);
    if (normalized == null) return null;
    final oneLine = normalized.replaceAll('\n', ' ').trim();
    if (oneLine.length <= maxLength) return oneLine;
    return '${oneLine.substring(0, maxLength - 1)}...';
  }
}

class AuthEntryPage extends ConsumerWidget {
  const AuthEntryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(appProvider.notifier);
    final cloudReady = _cloudConfigured;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.inbox_rounded, size: 52),
                  const SizedBox(height: 16),
                  const Text('URL Inbox', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('웹과 앱에서 같은 링크를 보려면 로그인하세요.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8B95A1))),
                  const SizedBox(height: 24),
                  if (!cloudReady)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('클라우드 설정이 없어 로그인 기능이 비활성화되었습니다.', textAlign: TextAlign.center, style: TextStyle(color: Colors.orange)),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: c.signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded),
                      label: const Text('Google로 로그인'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final email = await _showEmailInputDialog(context);
                        if (email == null || email.isEmpty) return;
                        await c.sendMagicLink(email);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일로 로그인 링크를 보냈습니다.')));
                      },
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: const Text('이메일 로그인 링크 받기'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextButton(
                    onPressed: c.continueWithoutLogin,
                    child: const Text('로그인 없이 사용하기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RootPage extends ConsumerWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final c = ref.read(appProvider.notifier);
    if (state.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!state.authGatePassed) return const AuthEntryPage();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ['인박스', '검색', '컬렉션', '설정'][state.tab],
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26),
        ),
        centerTitle: false,
        titleSpacing: 24,
      ),
      body: switch (state.tab) {
        1 => const SearchPage(),
        2 => const CollectionPage(),
        3 => const SettingsPage(),
        _ => const InboxPage(),
      },
      floatingActionButton: state.tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showSaveSheet(context, c),
              icon: const Icon(Icons.add_rounded),
              label: const Text('링크 추가', style: TextStyle(fontWeight: FontWeight.bold)),
              elevation: 0,
              highlightElevation: 0,
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: NavigationBar(
          selectedIndex: state.tab,
          onDestinationSelected: c.setTab,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox_rounded),
              label: '인박스',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search_rounded),
              label: '검색',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_open_outlined),
              selectedIcon: Icon(Icons.folder_rounded),
              label: '컬렉션',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}

class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});
  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(appProvider.notifier).onAppResumed());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(appProvider.notifier).onAppResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final c = ref.read(appProvider.notifier);
    final items = c.inbox;
    final grouped = _groupItems(items);

    return Column(
      children: [
        if (state.candidate != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('클립보드 링크 감지', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(state.candidate!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(onPressed: c.saveCandidate, child: const Text('저장')),
                IconButton(onPressed: c.dismissCandidate, icon: const Icon(Icons.close, size: 18)),
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              ChoiceChip(label: const Text('전체'), selected: state.filter == InboxFilter.all, onSelected: (_) => c.setFilter(InboxFilter.all)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('읽지 않음'), selected: state.filter == InboxFilter.unread, onSelected: (_) => c.setFilter(InboxFilter.unread)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('즐겨찾기'), selected: state.filter == InboxFilter.starred, onSelected: (_) => c.setFilter(InboxFilter.starred)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('오늘'), selected: state.filter == InboxFilter.today, onSelected: (_) => c.setFilter(InboxFilter.today)),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('인박스가 비어 있습니다', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                      const SizedBox(height: 8),
                      Text('영감을 주는 링크를 저장해 보세요!', style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _showSaveSheet(context, c),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('첫 링크 저장하기'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: grouped.length,
                  itemBuilder: (_, i) {
                    final row = grouped[i];
                    if (row is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Text(row, style: const TextStyle(color: Color(0xFF6B7684), fontWeight: FontWeight.bold, fontSize: 14)),
                      );
                    }
                    final item = row as LinkItem;
                    final thumbUrl = _inboxThumbUrl(item);
                    return Dismissible(
                      key: ValueKey(item.id),
                      background: Container(color: Colors.blue, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 24), child: const Icon(Icons.check, color: Colors.white)),
                      secondaryBackground: Container(color: Colors.grey, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), child: const Icon(Icons.archive_outlined, color: Colors.white)),
                      confirmDismiss: (d) async {
                        if (d == DismissDirection.startToEnd) {
                          await c.toggleRead(item);
                        } else {
                          await c.archive(item);
                        }
                        return false;
                      },
                      child: InkWell(
                        onTap: () => context.push('/detail/${item.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: item.isRead ? Colors.transparent : Theme.of(context).cardColor,
                            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5))),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  image: thumbUrl != null ? DecorationImage(image: NetworkImage(thumbUrl), fit: BoxFit.cover) : null,
                                ),
                                child: thumbUrl == null
                                    ? Center(child: Text(item.domain.isEmpty ? '?' : item.domain[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)))
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _dashboardTitle(item),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                                        fontSize: 16,
                                        color: item.isRead ? const Color(0xFF8B95A1) : Theme.of(context).colorScheme.onSurface,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (item.description.isNotEmpty && !item.isRead) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF8B95A1)),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        if (item.isStarred) ...[
                                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            '${item.domain} · ${_friendly(item.updatedAt)}${item.folderId != null ? ' · ${state.folders.where((f) => f.id == item.folderId).firstOrNull?.name ?? ''}' : ''}',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF8B95A1)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<dynamic> _groupItems(List<LinkItem> items) {
    if (items.isEmpty) return [];
    final List<dynamic> rows = [];
    String? lastHeader;
    for (final item in items) {
      final header = _dateHeader(item.updatedAt);
      if (header != lastHeader) {
        rows.add(header);
        lastHeader = header;
      }
      rows.add(item);
    }
    return rows;
  }

  String _dateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(dt.year, dt.month, dt.day);

    if (itemDate == today) return '오늘';
    if (itemDate == yesterday) return '어제';
    if (today.difference(itemDate).inDays < 7) return '이번 주';
    if (today.difference(itemDate).inDays < 30) return '이번 달';
    return DateFormat('yyyy년 MM월').format(dt);
  }
}

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final c = ref.read(appProvider.notifier);
    final domains = state.links.map((e) => e.domain).toSet().toList()..sort();
    final result = c.searched;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            onChanged: c.setQuery,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '제목, 도메인, 태그 검색',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none),
              filled: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterDropdown<String?>(
                  value: state.searchDomain,
                  items: [const DropdownMenuItem<String?>(value: null, child: Text('도메인 전체')), ...domains.map((e) => DropdownMenuItem<String?>(value: e, child: Text(e)))],
                  onChanged: c.setSearchDomain,
                  hint: '도메인',
                ),
                const SizedBox(width: 8),
                _FilterDropdown<String?>(
                  value: state.searchTag,
                  items: [const DropdownMenuItem<String?>(value: null, child: Text('태그 전체')), ...state.tags.map((e) => DropdownMenuItem<String?>(value: e.name, child: Text(e.name)))],
                  onChanged: c.setSearchTag,
                  hint: '태그',
                ),
                const SizedBox(width: 8),
                _FilterDropdown<SearchPeriod>(
                  value: state.period,
                  items: const [
                    DropdownMenuItem(value: SearchPeriod.all, child: Text('기간 전체')),
                    DropdownMenuItem(value: SearchPeriod.day, child: Text('1일 이내')),
                    DropdownMenuItem(value: SearchPeriod.week, child: Text('1주 이내')),
                    DropdownMenuItem(value: SearchPeriod.month, child: Text('1개월 이내')),
                  ],
                  onChanged: (v) {
                    if (v != null) c.setPeriod(v);
                  },
                  hint: '기간',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: result.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('검색 결과가 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: result.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = result[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            image: item.imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(item.imageUrl), fit: BoxFit.cover) : null,
                          ),
                          child: item.imageUrl.isEmpty
                              ? Center(child: Text(item.domain.isEmpty ? '?' : item.domain[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))
                              : null,
                        ),
                        title: Text(
                          _dashboardTitle(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.description.isNotEmpty)
                              Text(
                                item.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF8B95A1)),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.domain} · ${_friendly(item.updatedAt)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF8B95A1)),
                            ),
                          ],
                        ),
                        onTap: () => context.push('/detail/${item.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({required this.value, required this.items, required this.onChanged, required this.hint});
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: Text(hint),
          style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          isDense: true,
        ),
      ),
    );
  }
}

class CollectionPage extends ConsumerWidget {
  const CollectionPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final c = ref.read(appProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: '폴더', onAdd: () => _showNameDialog(context, '폴더 추가', c.createFolder)),
        if (state.folders.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('폴더가 없습니다.', style: TextStyle(color: Colors.grey))),
        ...state.folders.map((f) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.folder_rounded, color: Colors.blue),
              ),
              title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                    child: Text('${state.links.where((e) => e.folderId == f.id).length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                    onPressed: () async {
                      final confirmed = await _showConfirmDialog(context, '폴더 삭제', '이 폴더를 삭제하시겠습니까? 폴더 안의 링크는 삭제되지 않습니다.');
                      if (confirmed) await c.removeFolder(f.id);
                    },
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                ],
              ),
              onTap: () => context.push('/folder/${f.id}'),
            )),
        const SizedBox(height: 24),
        _SectionHeader(title: '태그', onAdd: () => _showNameDialog(context, '태그 추가', c.createTag)),
        if (state.tags.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('태그가 없습니다.', style: TextStyle(color: Colors.grey))),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: state.tags.map((t) {
            final count = state.links.where((e) => e.tags.contains(t.name)).length;
            return Chip(
              label: Text('#${t.name} ($count)'),
              backgroundColor: Theme.of(context).cardColor,
              side: BorderSide(color: Theme.of(context).dividerColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('추가'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final c = ref.read(appProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text('화면 설정', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('테마 모드', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(value: ThemeMode.light, label: Text('라이트')),
                          ButtonSegment<ThemeMode>(value: ThemeMode.dark, label: Text('다크')),
                        ],
                        selected: <ThemeMode>{state.themeMode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light},
                        onSelectionChanged: (values) {
                          if (values.isNotEmpty) c.setThemeMode(values.first);
                        },
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text('기능 설정', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: state.clipboardEnabled,
                onChanged: c.setClipboardEnabled,
                title: const Text('클립보드 감지'),
                subtitle: const Text('앱을 열 때 클립보드에 있는 URL을 자동으로 감지합니다.'),
                secondary: const Icon(Icons.paste_rounded),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                value: state.reminderEnabled,
                onChanged: c.setReminderEnabled,
                title: const Text('리마인더 알림'),
                subtitle: const Text('매일 읽지 않은 링크를 알려줍니다.'),
                secondary: const Icon(Icons.notifications_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text('로그인 / 동기화', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              if (!_cloudConfigured)
                const ListTile(
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('클라우드 비활성화'),
                  subtitle: Text('SUPABASE_URL / SUPABASE_ANON_KEY가 설정되지 않았습니다.'),
                )
              else ...[
                ListTile(
                  leading: Icon(state.signedIn ? Icons.verified_user_outlined : Icons.person_outline),
                  title: Text(state.signedIn ? (state.userEmail ?? '로그인됨') : '로그인'),
                  subtitle: Text(state.syncing ? '동기화 중...' : '앱과 웹에서 같은 링크를 확인할 수 있습니다.'),
                  trailing: state.syncing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                if (!state.signedIn) ...[
                  ListTile(
                    leading: const Icon(Icons.mark_email_read_outlined),
                    title: const Text('이메일 매직링크 로그인'),
                    onTap: () async {
                      final email = await _showEmailInputDialog(context);
                      if (email == null || email.isEmpty) return;
                      await c.sendMagicLink(email);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일로 로그인 링크를 보냈습니다.')));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.g_mobiledata_rounded),
                    title: const Text('Google로 로그인'),
                    onTap: () => c.signInWithGoogle(),
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.sync_rounded),
                    title: const Text('지금 동기화'),
                    onTap: () => c.syncNow(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('로그아웃'),
                    onTap: () => c.signOutCloud(),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class LinkDetailPage extends ConsumerStatefulWidget {
  const LinkDetailPage({super.key, required this.id});
  final String id;

  @override
  ConsumerState<LinkDetailPage> createState() => _LinkDetailPageState();
}

class _LinkDetailPageState extends ConsumerState<LinkDetailPage> {
  late final TextEditingController noteController;
  String? xProfileImageUrl;
  List<String> xMediaUrls = const [];

  @override
  void initState() {
    super.initState();
    final link = ref.read(appProvider).links.where((e) => e.id == widget.id).firstOrNull;
    noteController = TextEditingController(text: link?.note ?? '');

    if (link != null && !link.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(appProvider.notifier).toggleRead(link);
      });
    }

    if (link != null && _isXDomainForUi(link.domain)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadXAssets(link.url));
    }
  }

  Future<void> _loadXAssets(String url) async {
    final meta = await Metadata.fetch(url);
    if (!mounted) return;
    setState(() {
      xProfileImageUrl = meta.profileImage;
      xMediaUrls = meta.mediaUrls;
    });
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final c = ref.read(appProvider.notifier);
    final link = state.links.where((e) => e.id == widget.id).firstOrNull;
    if (link == null) return const Scaffold(body: Center(child: Text('링크 없음')));
    final isXLink = _isXDomainForUi(link.domain);
    final profileImageUrl = _firstHttpUrl([xProfileImageUrl, link.faviconUrl]);
    final mediaUrls = _mergeMediaForUi(
      isXLink ? xMediaUrls : const [],
      fallback: link.imageUrl,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('링크 상세', style: TextStyle(fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(link.isStarred ? Icons.star_rounded : Icons.star_outline_rounded, color: link.isStarred ? Colors.amber : null),
            onPressed: () => c.toggleStar(link),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final confirmed = await _showConfirmDialog(context, '링크 삭제', '이 링크를 삭제하시겠습니까?');
              if (confirmed) {
                await c.remove(link);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (isXLink && profileImageUrl != null) ...[
            Row(
              children: [
                CircleAvatar(radius: 18, backgroundImage: NetworkImage(profileImageUrl)),
                const SizedBox(width: 10),
                const Text('작성자 프로필', style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (mediaUrls.isNotEmpty) ...[
            ...mediaUrls.take(4).map((mediaUrl) {
              if (_isLikelyVideoMediaUrl(mediaUrl)) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final u = Uri.tryParse(mediaUrl);
                          if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.play_circle_fill_rounded),
                        label: const Text('동영상 열기'),
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      mediaUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(link.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3)),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                onPressed: () async {
                  final controller = TextEditingController(text: link.title);
                  final result = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('제목 수정'),
                      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '링크 제목')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('저장')),
                      ],
                    ),
                  );
                  if (result != null && result.trim().isNotEmpty && result != link.title) {
                    await c.updateDetail(link, title: result.trim());
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목이 수정되었습니다.')));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(link.domain, style: const TextStyle(fontSize: 14, color: Color(0xFF8B95A1), fontWeight: FontWeight.w500)),
          if (link.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              link.description,
              style: TextStyle(
                fontSize: _isInstagramDomain(link.domain) ? 13 : 15,
                color: const Color(0xFF4E5968),
                height: _isInstagramDomain(link.domain) ? 1.45 : 1.5,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => c.openOriginal(link),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('원문 열기'),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('메모', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '이 링크를 저장한 이유나 기억할 내용을 적어보세요.',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey.withValues(alpha: 0.7)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await c.updateDetail(link, note: noteController.text);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('메모가 저장되었습니다.')));
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('저장'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('분류', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: link.folderId,
                  items: [const DropdownMenuItem<String?>(value: null, child: Text('폴더 없음')), ...state.folders.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name)))],
                  onChanged: (v) => c.updateDetail(link, folderId: v),
                  decoration: const InputDecoration(labelText: '폴더 선택', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: () => _showNameDialog(context, '폴더 추가', c.createFolder),
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: '새 폴더',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...state.tags.map((tag) => FilterChip(
                    label: Text('#${tag.name}'),
                    selected: link.tags.contains(tag.name),
                    onSelected: (v) {
                      final next = [...link.tags];
                      if (v) {
                        if (!next.contains(tag.name)) next.add(tag.name);
                      } else {
                        next.remove(tag.name);
                      }
                      c.updateDetail(link, tags: next);
                    },
                    showCheckmark: false,
                    selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: link.tags.contains(tag.name) ? Theme.of(context).colorScheme.primary : const Color(0xFF4E5968),
                      fontWeight: link.tags.contains(tag.name) ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: link.tags.contains(tag.name) ? BorderSide.none : BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    backgroundColor: Theme.of(context).cardColor,
                  )),
              ActionChip(
                label: const Text('+ 태그'),
                onPressed: () => _showNameDialog(context, '태그 추가', c.createTag),
                avatar: const Icon(Icons.add, size: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Theme.of(context).dividerColor)),
                backgroundColor: Theme.of(context).cardColor,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: 16),
          Text('저장: ${DateFormat('yyyy-MM-dd HH:mm').format(link.createdAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF8B95A1))),
          Text('수정: ${DateFormat('yyyy-MM-dd HH:mm').format(link.updatedAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF8B95A1))),
          if (link.lastOpenedAt != null)
            Text('열람: ${DateFormat('yyyy-MM-dd HH:mm').format(link.lastOpenedAt!)}', style: const TextStyle(fontSize: 12, color: Color(0xFF8B95A1))),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

Future<void> _showSaveSheet(BuildContext context, AppController c) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ManualSaveSheet(controller: c),
  );
}

Future<String?> _showEmailInputDialog(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('이메일 로그인'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'you@example.com'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('보내기')),
      ],
    ),
  );
  controller.dispose();
  return result;
}

class _ManualSaveSheet extends StatefulWidget {
  const _ManualSaveSheet({required this.controller});
  final AppController controller;

  @override
  State<_ManualSaveSheet> createState() => _ManualSaveSheetState();
}

class _ManualSaveSheetState extends State<_ManualSaveSheet> {
  late final TextEditingController url;
  late final TextEditingController title;
  late final TextEditingController note;

  @override
  void initState() {
    super.initState();
    url = TextEditingController();
    title = TextEditingController();
    note = TextEditingController();
  }

  @override
  void dispose() {
    url.dispose();
    title.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: url, decoration: const InputDecoration(labelText: 'URL')),
          const SizedBox(height: 8),
          TextField(controller: title, decoration: const InputDecoration(labelText: '제목(선택)')),
          const SizedBox(height: 8),
          TextField(controller: note, decoration: const InputDecoration(labelText: '메모(선택)')),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                await widget.controller.addLink(
                  url.text,
                  title: title.text.trim().isEmpty ? null : title.text.trim(),
                  note: note.text.trim().isEmpty ? null : note.text.trim(),
                  source: 'manual',
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('저장'),
            ),
          )
        ],
      ),
    );
  }
}

Future<void> _showNameDialog(BuildContext context, String title, Future<void> Function(String) submit) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _NameInputDialog(title: title, submit: submit),
  );
}

class _NameInputDialog extends StatefulWidget {
  const _NameInputDialog({required this.title, required this.submit});
  final String title;
  final Future<void> Function(String) submit;

  @override
  State<_NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends State<_NameInputDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () async {
            await widget.submit(controller.text);
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

Future<bool> _showConfirmDialog(BuildContext context, String title, String content) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
          ],
        ),
      ) ??
      false;
}

class FolderLinksPage extends ConsumerWidget {
  const FolderLinksPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final folder = state.folders.where((e) => e.id == id).firstOrNull;
    if (folder == null) return const Scaffold(body: Center(child: Text('폴더를 찾을 수 없습니다.')));

    final items = state.links.where((e) => e.folderId == id).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(title: Text('${folder.name} (${items.length})')),
      body: items.isEmpty
          ? const Center(child: Text('이 폴더에 저장된 링크가 없습니다.'))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = items[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      image: item.imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(item.imageUrl), fit: BoxFit.cover) : null,
                    ),
                    child: item.imageUrl.isEmpty
                        ? Center(child: Text(item.domain.isEmpty ? '?' : item.domain[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))
                        : null,
                  ),
                  title: Text(
                    _dashboardTitle(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(height: 1.2, fontSize: 15, fontWeight: FontWeight.bold, color: item.isRead ? Colors.grey : null),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${item.domain} · ${_friendly(item.updatedAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF8B95A1))),
                  ),
                  onTap: () => context.push('/detail/${item.id}'),
                );
              },
            ),
    );
  }
}

bool _isUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

String _sanitizeIncomingUrl(String value) {
  var v = value
      .trim()
      .replaceAll('\u200B', '')
      .replaceAll('\u200C', '')
      .replaceAll('\u200D', '')
      .replaceAll('\uFEFF', '');
  while (v.isNotEmpty && ')]}>,.!?;:"\''.contains(v[v.length - 1])) {
    v = v.substring(0, v.length - 1).trimRight();
  }
  while (v.isNotEmpty && '([<{"\''.contains(v[0])) {
    v = v.substring(1).trimLeft();
  }
  return v;
}

String _withScheme(String value) {
  final v = value.trim();
  final lower = v.toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://') ? v : 'https://$v';
}

String _normalize(String value) {
  final uri = Uri.parse(_withScheme(value));
  final q = Map.of(uri.queryParameters)..removeWhere((k, _) => k.startsWith('utm_') || k == 'gclid' || k == 'fbclid');
  return Uri(scheme: uri.scheme.toLowerCase(), host: uri.host.toLowerCase(), path: uri.path.isEmpty ? '/' : uri.path, queryParameters: q.isEmpty ? null : q).toString();
}

String _domainTag(String domain) {
  if (domain.contains('x.com') || domain.contains('twitter.com')) return '트위터';
  if (domain.contains('threads.net')) return '스레드';
  if (domain.contains('youtube.com') || domain.contains('youtu.be')) return '유튜브';
  return domain;
}

String _dashboardTitle(LinkItem item) {
  final prefix = _servicePrefix(item.domain);
  if (prefix.isEmpty) return item.title;
  if (item.title.startsWith('[')) return item.title;
  return '$prefix ${item.title}';
}

String _servicePrefix(String domain) {
  final d = domain.toLowerCase();
  if (d.contains('threads')) return '[Threads]';
  if (d.contains('x.com') || d.contains('twitter.com') || d == 't.co' || d.contains('fixupx.com') || d.contains('fxtwitter.com')) return '[X]';
  if (d.contains('instagram.com') || d.contains('instagr.am')) return '[Instagram]';
  if (d.contains('cafe.naver.com')) return '[Naver Cafe]';
  if (d.contains('blog.naver.com')) return '[Naver Blog]';
  if (d.contains('youtube.com') || d.contains('youtu.be')) return '[YouTube]';
  if (d.contains('facebook.com')) return '[Facebook]';
  return '';
}

bool _isInstagramDomain(String domain) {
  final d = domain.toLowerCase();
  return d.contains('instagram.com') || d.contains('instagr.am');
}

bool _isXDomainForUi(String domain) {
  final d = domain.toLowerCase();
  return d.contains('x.com') || d.contains('twitter.com') || d == 't.co' || d.contains('fixupx.com') || d.contains('fxtwitter.com');
}

String? _inboxThumbUrl(LinkItem item) {
  if (_isXDomainForUi(item.domain)) {
    return _firstHttpUrl([item.faviconUrl, item.imageUrl]);
  }
  return _firstHttpUrl([item.imageUrl, item.faviconUrl]);
}

String? _firstHttpUrl(Iterable<String?> urls) {
  for (final raw in urls) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) continue;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
  }
  return null;
}

List<String> _mergeMediaForUi(Iterable<String> mediaUrls, {String? fallback}) {
  final out = <String>[];
  final seen = <String>{};
  for (final raw in [...mediaUrls, if (fallback != null && fallback.trim().isNotEmpty) fallback.trim()]) {
    if (raw.isEmpty) continue;
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) continue;
    if (seen.add(raw)) out.add(raw);
  }
  return out;
}

bool _isLikelyVideoMediaUrl(String url) {
  final u = url.toLowerCase();
  return u.contains('video.twimg.com') || u.endsWith('.mp4') || u.contains('.m3u8');
}

String _friendly(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return '방금';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  if (d.inDays < 7) return '${d.inDays}일 전';
  return DateFormat('yyyy-MM-dd').format(t);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
