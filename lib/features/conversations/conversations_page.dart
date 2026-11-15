import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final _messageController = TextEditingController();
  final _messageScrollController = ScrollController();
  Timer? _inboxRefreshTimer;
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  String? _selectedId;
  bool _loading = true;
  bool _loadingMessages = false;
  bool _sending = false;
  bool _connecting = false;
  String? _error;
  String? _messageError;
  String _filter = 'ALL';

  Map<String, dynamic>? get _selectedConversation {
    for (final item in _conversations) {
      if (item['id']?.toString() == _selectedId) return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Refresh the inbox and the open thread while this page is visible.
    _inboxRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _loading || _loadingMessages || _connecting || _sending) {
        return;
      }
      _refreshInboxSilently();
    });
  }

  @override
  void dispose() {
    _inboxRefreshTimer?.cancel();
    _messageController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.instance.get<dynamic>('/conversations/channels'),
        ApiClient.instance.get<dynamic>(
          '/conversations',
          queryParameters: _filter == 'ALL' ? null : {'status': _filter},
        ),
      ]);
      final channels = _asMapList(results[0].data);
      final conversations = _asMapList(results[1].data);
      final nextSelected =
          conversations.any((item) => item['id']?.toString() == _selectedId)
          ? _selectedId
          : conversations.isEmpty
          ? null
          : conversations.first['id']?.toString();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _conversations = conversations;
        _selectedId = nextSelected;
        _loading = false;
      });
      if (nextSelected != null) {
        await _loadMessages(nextSelected);
      } else {
        setState(() => _messages = []);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorText(error);
      });
    }
  }

  Future<void> _loadMessages(String id) async {
    if (!mounted) return;
    setState(() {
      _loadingMessages = true;
      _messageError = null;
    });
    try {
      final response = await ApiClient.instance.get<dynamic>(
        '/conversations/$id/messages',
      );
      final messages = _asMapList(response.data);
      if (!mounted || _selectedId != id) return;
      final updatedConversations = _conversations.map((item) {
        if (item['id']?.toString() == id) return {...item, 'unreadCount': 0};
        return item;
      }).toList();
      setState(() {
        _messages = messages;
        _conversations = updatedConversations;
        _loadingMessages = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_messageScrollController.hasClients) {
          _messageScrollController.jumpTo(
            _messageScrollController.position.maxScrollExtent,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMessages = false;
        _messageError = _errorText(error);
      });
    }
  }

  Future<void> _connectChannel(String channel) async {
    setState(() => _connecting = true);
    try {
      final response = await ApiClient.instance.get<dynamic>(
        '/conversations/connect-url',
        queryParameters: {'channel': channel},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawUrl = data['authorizationUrl']?.toString() ?? '';
      final uri = Uri.tryParse(rawUrl);
      if (uri == null ||
          !uri.hasScheme ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('تعذر فتح صفحة تفويض Meta.');
      }
      _showMessage(
        'افتح نافذة Meta، اختر الصفحة والحساب ووافق على الصلاحيات. بعد العودة اضغط تحديث الاتصالات.',
      );
    } catch (error) {
      _showMessage(_errorText(error), isError: true);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _connectTelegram() async {
    if (_connecting) return;

    final tokenController = TextEditingController();
    var obscureToken = true;
    final token = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.send_rounded, color: Color(0xFF229ED9)),
              SizedBox(width: 9),
              Text('ربط Telegram Bot'),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ألصق Bot Token الذي حصلت عليه من BotFather. سيُرسل إلى Backend ليُحفظ مشفّراً، ولن يظهر ضمن بيانات القناة.',
                  style: TextStyle(fontSize: 12, height: 1.7),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: tokenController,
                  autofocus: true,
                  obscureText: obscureToken,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  textDirection: ui.TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'Telegram Bot Token',
                    hintText: '123456:ABC...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: obscureToken ? 'إظهار التوكن' : 'إخفاء التوكن',
                      onPressed: () => setDialogState(
                        () => obscureToken = !obscureToken,
                      ),
                      icon: Icon(
                        obscureToken
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'لا تشارك التوكن مع أي شخص. إذا سبق نشره، ألغِه من BotFather وأنشئ توكناً جديداً.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.error,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () {
                final value = tokenController.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              icon: const Icon(Icons.link_rounded, size: 17),
              label: const Text('ربط البوت'),
            ),
          ],
        ),
      ),
    );
    tokenController.clear();
    tokenController.dispose();

    if (!mounted || token == null || token.isEmpty) return;

    setState(() => _connecting = true);
    try {
      final response = await ApiClient.instance.post<dynamic>(
        '/conversations/telegram/connect',
        data: {'botToken': token},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      await _loadAll();
      if (!mounted) return;
      _showMessage(
        data['message']?.toString() ?? 'تم ربط Telegram بنجاح.',
      );
    } catch (error) {
      if (mounted) _showMessage(_errorText(error), isError: true);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _launchLocalWebsiteDemo() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      final response = await ApiClient.instance.post<dynamic>(
        '/conversations/website/demo/setup',
        data: <String, dynamic>{},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawUrl = data['demoUrl']?.toString() ?? '';
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || !uri.hasScheme) {
        throw StateError('لم يرجع الخادم رابط المتجر التجريبي.');
      }
      await _loadAll();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('المتجر التجريبي جاهز'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تم تجهيز القناة وتفعيل Gemini. افتح صفحة المتجر في تبويب جديد، ثم جرّب نافذة «تحدث معنا» أسفل الصفحة.',
                  style: TextStyle(fontSize: 12, height: 1.7),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  rawUrl,
                  textDirection: ui.TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: rawUrl));
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (mounted) _showMessage('تم نسخ رابط المتجر التجريبي.');
              },
              child: const Text('نسخ الرابط'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!dialogContext.mounted) return;
                if (opened) {
                  Navigator.pop(dialogContext);
                } else {
                  await Clipboard.setData(ClipboardData(text: rawUrl));
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (mounted) {
                    _showMessage(
                      'تعذر فتح التبويب تلقائياً؛ تم نسخ الرابط. الصقه في المتصفح.',
                      isError: true,
                    );
                  }
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('فتح المتجر التجريبي'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(_errorText(error), isError: true);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _setupWebsiteChat() async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعداد محادثة الموقع'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'أدخل نطاق موقع المتجر الذي ستظهر عليه نافذة المحادثة. يمكنك إدخال أكثر من نطاق وفصلها بفاصلة.',
                style: TextStyle(fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'نطاق الموقع',
                  hintText: 'https://shop.example.com',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إنشاء كود المحادثة'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) {
      controller.dispose();
      return;
    }
    final origins = controller.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    controller.dispose();
    if (origins.isEmpty) {
      _showMessage('أدخل نطاق الموقع أولاً.', isError: true);
      return;
    }
    if (mounted) setState(() => _connecting = true);
    try {
      final response = await ApiClient.instance.post<dynamic>(
        '/conversations/website/setup',
        data: {'allowedOrigins': origins},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      await _loadAll();
      if (!mounted) return;
      final embedCode = data['embedCode']?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('كود نافذة NEXOR Chat'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'انسخ الكود وضعه قبل وسم الإغلاق body في موقع المتجر. تأكد أن PUBLIC_API_BASE_URL يشير إلى عنوان Backend العام الذي يعمل عبر HTTPS.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  embedCode,
                  textDirection: ui.TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: embedCode));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _showMessage('تم نسخ كود المحادثة.');
              },
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: const Text('نسخ الكود'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showMessage(_errorText(error), isError: true);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _toggleChannelAutomation(
    Map<String, dynamic> connection,
    bool enabled,
  ) async {
    final id = connection['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await ApiClient.instance.patch<dynamic>(
        '/conversations/channels/$id/automation',
        data: {'enabled': enabled},
      );
      await _loadAll();
      _showMessage(enabled ? 'تم تفعيل رد NEXOR AI لهذه القناة.' : 'تم إيقاف الرد الآلي لهذه القناة.');
    } catch (error) {
      _showMessage(_errorText(error), isError: true);
    }
  }

  Future<void> _toggleConversationAutomation() async {
    final conversation = _selectedConversation;
    if (conversation == null) return;
    final id = conversation['id']?.toString();
    if (id == null || id.isEmpty) return;
    final paused = conversation['aiPaused'] == true;
    try {
      await ApiClient.instance.patch<dynamic>(
        '/conversations/$id/automation',
        data: {'paused': !paused},
      );
      await _loadAll();
      _showMessage(paused ? 'تم استئناف رد NEXOR AI لهذه المحادثة.' : 'تم إيقاف رد AI لتتولى المحادثة يدوياً.');
    } catch (error) {
      _showMessage(_errorText(error), isError: true);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final id = _selectedId;
    if (text.isEmpty || id == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.post<dynamic>(
        '/conversations/$id/messages',
        data: {'text': text},
      );
      _messageController.clear();
      await _loadMessages(id);
      await _loadAllWithoutThread();
    } catch (error) {
      _showMessage(_errorText(error), isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _loadAllWithoutThread() async {
    try {
      final response = await ApiClient.instance.get<dynamic>(
        '/conversations',
        queryParameters: _filter == 'ALL' ? null : {'status': _filter},
      );
      if (!mounted) return;
      setState(() => _conversations = _asMapList(response.data));
    } catch (_) {
      // Keep the already displayed thread if the sidebar refresh fails.
    }
  }

  Future<void> _refreshInboxSilently() async {
    final selectedId = _selectedId;
    final previousLastMessageId = _messages.isEmpty
        ? null
        : _messages.last['id']?.toString();
    final wasNearBottom = _messageScrollController.hasClients &&
        (_messageScrollController.position.maxScrollExtent -
                _messageScrollController.position.pixels) <
            100;
    try {
      final conversationResponse = await ApiClient.instance.get<dynamic>(
        '/conversations',
        queryParameters: _filter == 'ALL' ? null : {'status': _filter},
      );
      final conversations = _asMapList(conversationResponse.data);
      List<Map<String, dynamic>>? messages;

      if (selectedId != null) {
        final stillExists = conversations.any(
          (item) => item['id']?.toString() == selectedId,
        );
        if (stillExists) {
          final messageResponse = await ApiClient.instance.get<dynamic>(
            '/conversations/$selectedId/messages',
          );
          messages = _asMapList(messageResponse.data);
        }
      }

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        if (selectedId != null && selectedId == _selectedId) {
          if (messages != null) {
            _messages = messages;
          } else if (!conversations.any(
            (item) => item['id']?.toString() == selectedId,
          )) {
            _selectedId = conversations.isEmpty
                ? null
                : conversations.first['id']?.toString();
            _messages = [];
          }
        }
      });

      final newestMessageId = messages == null || messages.isEmpty
          ? null
          : messages.last['id']?.toString();
      final hasNewMessage = newestMessageId != null &&
          newestMessageId != previousLastMessageId;
      if (hasNewMessage && wasNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_messageScrollController.hasClients) {
            _messageScrollController.jumpTo(
              _messageScrollController.position.maxScrollExtent,
            );
          }
        });
      }
    } catch (_) {
      // Keep the current inbox visible if a silent background refresh fails.
    }
  }

  Future<void> _toggleStatus() async {
    final conversation = _selectedConversation;
    if (conversation == null) return;
    final oldStatus = conversation['status']?.toString() ?? 'OPEN';
    final nextStatus = oldStatus == 'OPEN' ? 'CLOSED' : 'OPEN';
    try {
      await ApiClient.instance.patch<dynamic>(
        '/conversations/${conversation['id']}/status',
        data: {'status': nextStatus},
      );
      await _loadAll();
    } catch (error) {
      _showMessage(_errorText(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(theme),
            const SizedBox(height: 14),
            _channelBar(theme),
            const SizedBox(height: 14),
            Expanded(
              child: _loading && _conversations.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _conversations.isEmpty
                  ? _errorPanel(theme)
                  : _inboxLayout(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF292344), Color(0xFF171923)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF8B84FF).withValues(alpha: .22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF8B84FF).withValues(alpha: .15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: Color(0xFFB5AFFF),
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مركز المحادثات',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'صندوق موحّد لمحادثات Telegram وInstagram وMessenger وموقع المتجر',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .65),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('تحديث'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: .25)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelBar(ThemeData theme) {
    final telegram = _channels
        .where((c) => c['channel'] == 'TELEGRAM')
        .toList();
    final instagram = _channels
        .where((c) => c['channel'] == 'INSTAGRAM')
        .toList();
    final messenger = _channels
        .where((c) => c['channel'] == 'MESSENGER')
        .toList();
    final website = _channels
        .where((c) => c['channel'] == 'WEBSITE')
        .toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _channelCard(
          theme,
          'Telegram',
          Icons.send_rounded,
          const Color(0xFF229ED9),
          telegram,
          'TELEGRAM',
        ),
        _channelCard(
          theme,
          'Instagram',
          Icons.camera_alt_rounded,
          const Color(0xFFE56A9B),
          instagram,
          'INSTAGRAM',
        ),
        _channelCard(
          theme,
          'Facebook Messenger',
          Icons.messenger_rounded,
          const Color(0xFF438AF5),
          messenger,
          'MESSENGER',
        ),
        _channelCard(
          theme,
          'محادثة الموقع',
          Icons.language_rounded,
          const Color(0xFF27A889),
          website,
          'WEBSITE',
        ),
      ],
    );
  }

  Widget _channelCard(
    ThemeData theme,
    String title,
    IconData icon,
    Color color,
    List<Map<String, dynamic>> connections,
    String channel,
  ) {
    final active = connections
        .where((item) => item['isActive'] == true)
        .toList();
    return Container(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 430),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                if (active.isEmpty)
                  Text(
                    channel == 'WEBSITE'
                        ? 'لم يتم إعداد نافذة الموقع'
                        : channel == 'TELEGRAM'
                            ? 'لم يتم ربط بوت Telegram'
                            : 'غير مربوط',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: .55),
                    ),
                  )
                else
                  ...active.map(
                    (connection) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            connection['accountName']?.toString() ?? title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: .62,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Tooltip(
                          message: connection['aiAutoReplyEnabled'] == true
                              ? 'إيقاف الرد التلقائي لهذه القناة'
                              : 'تفعيل رد NEXOR AI التلقائي لهذه القناة',
                          child: const Icon(
                            Icons.smart_toy_rounded,
                            size: 13,
                            color: Color(0xFF9185FF),
                          ),
                        ),
                        Switch.adaptive(
                          value: connection['aiAutoReplyEnabled'] == true,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (value) =>
                              _toggleChannelAutomation(connection, value),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (channel == 'WEBSITE')
            TextButton.icon(
              onPressed: _connecting ? null : _launchLocalWebsiteDemo,
              icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
              label: const Text(
                'تجربة محلية',
                style: TextStyle(fontSize: 11),
              ),
            ),
          TextButton(
            onPressed: _connecting
                ? null
                : () {
                    if (channel == 'WEBSITE') {
                      _setupWebsiteChat();
                    } else if (channel == 'TELEGRAM') {
                      _connectTelegram();
                    } else {
                      _connectChannel(channel);
                    }
                  },
            child: Text(
              channel == 'WEBSITE'
                  ? 'إعداد'
                  : channel == 'TELEGRAM'
                      ? (active.isEmpty ? 'ربط البوت' : 'تحديث الربط')
                      : (active.isEmpty ? 'ربط' : 'إضافة حساب'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inboxLayout(ThemeData theme) {
    final narrow = MediaQuery.of(context).size.width < 820;
    if (narrow) {
      return Column(
        children: [
          SizedBox(height: 290, child: _conversationPanel(theme)),
          const SizedBox(height: 10),
          Expanded(child: _threadPanel(theme)),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 340, child: _conversationPanel(theme)),
        const SizedBox(width: 12),
        Expanded(child: _threadPanel(theme)),
      ],
    );
  }

  Widget _conversationPanel(ThemeData theme) {
    final shown = _conversations.where((c) {
      if (_filter == 'ALL') return true;
      return c['status'] == _filter;
    }).toList();
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'المحادثات',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${shown.length}',
                  style: const TextStyle(
                    color: Color(0xFF9B92FF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 7),
                PopupMenuButton<String>(
                  tooltip: 'تصفية المحادثات',
                  initialValue: _filter,
                  onSelected: (value) async {
                    setState(() => _filter = value);
                    await _loadAll();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'ALL', child: Text('كل المحادثات')),
                    PopupMenuItem(value: 'OPEN', child: Text('مفتوحة')),
                    PopupMenuItem(value: 'CLOSED', child: Text('مغلقة')),
                  ],
                  child: const Icon(Icons.filter_list_rounded, size: 20),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: .35)),
          Expanded(
            child: shown.isEmpty
                ? _emptyConversations(theme)
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = shown[index];
                      final id = item['id']?.toString();
                      final selected = id == _selectedId;
                      final channel = item['channel']?.toString() ?? '';
                      final color = _channelColor(channel);
                      final unread =
                          (item['unreadCount'] as num?)?.toInt() ?? 0;
                      return Material(
                        color: selected
                            ? const Color(0xFF786BFA).withValues(alpha: .12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: id == null
                              ? null
                              : () async {
                                  setState(() => _selectedId = id);
                                  await _loadMessages(id);
                                  await _loadAllWithoutThread();
                                },
                          child: Padding(
                            padding: const EdgeInsets.all(11),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: color.withValues(alpha: .14),
                                  child: Icon(
                    _channelIcon(channel),
                                    color: color,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item['customerName']
                                                      ?.toString() ??
                                                  'عميل',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _timeLabel(item['lastMessageAt']),
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: .45),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        item['lastMessageText']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true
                                            ? item['lastMessageText'].toString()
                                            : 'لا يوجد نص للرسالة',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: .58),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (unread > 0) ...[
                                  const SizedBox(width: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 4,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF786BFA),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyConversations(ThemeData theme) {
    final connected = _channels.any((c) => c['isActive'] == true);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              connected
                  ? Icons.mark_chat_unread_outlined
                  : Icons.link_off_rounded,
              size: 34,
              color: Colors.grey,
            ),
            const SizedBox(height: 10),
            Text(
              connected ? 'لا توجد محادثات واردة بعد' : 'اربط أول قناة للبدء',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              connected
                  ? 'ستظهر الرسائل الجديدة هنا فور وصولها من القنوات المربوطة.'
                  : 'اربط Telegram أو Instagram أو Messenger، أو أعد إعداد نافذة محادثة موقعك.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: .55),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _threadPanel(ThemeData theme) {
    final conversation = _selectedConversation;
    if (conversation == null) {
      return Container(
        decoration: _panelDecoration(theme),
        child: const Center(
          child: Text(
            'اختر محادثة لعرض الرسائل',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    final channel = conversation['channel']?.toString() ?? '';
    final color = _channelColor(channel);
    final isOpen = conversation['status'] == 'OPEN';
    final lastInbound = DateTime.tryParse(
      conversation['lastInboundAt']?.toString() ?? '',
    );
    final canReply = channel == 'WEBSITE' ||
        channel == 'TELEGRAM' ||
        (lastInbound != null &&
            DateTime.now().difference(lastInbound).inHours < 24);
    return Container(
      decoration: _panelDecoration(theme),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .13),
                  child: Icon(
                    _channelIcon(channel),
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation['customerName']?.toString() ?? 'عميل',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_channelLabel(channel)} • ${conversation['accountName'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: .55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadingMessages
                      ? null
                      : () => _loadMessages(_selectedId!),
                  tooltip: 'تحديث الرسائل',
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                ),
                if (conversation['aiAutoReplyEnabled'] == true)
                  IconButton(
                    tooltip: conversation['aiPaused'] == true
                        ? 'استئناف رد الذكاء الاصطناعي'
                        : 'إيقاف رد الذكاء الاصطناعي لهذه المحادثة',
                    onPressed: _toggleConversationAutomation,
                    icon: Icon(
                      conversation['aiPaused'] == true
                          ? Icons.smart_toy_outlined
                          : Icons.smart_toy_rounded,
                      color: conversation['aiPaused'] == true
                          ? Colors.orangeAccent
                          : const Color(0xFF9185FF),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _toggleStatus,
                  icon: Icon(
                    isOpen
                        ? Icons.check_circle_outline_rounded
                        : Icons.lock_open_rounded,
                    size: 16,
                  ),
                  label: Text(isOpen ? 'إغلاق' : 'إعادة فتح'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: .35)),
          Expanded(
            child: _loadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _messageError != null
                ? Center(
                    child: Text(
                      _messageError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  )
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد رسائل في هذه المحادثة بعد.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _messageScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _messageBubble(theme, _messages[index]),
                  ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: .35)),
          if (!canReply)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF0A84B).withValues(alpha: .08),
              child: Text(
                'انتهت نافذة الرد أو لم تصل رسالة من العميل بعد. تسمح Meta بالرد العادي خلال 24 ساعة من آخر رسالة واردة.',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFF0B65F),
                  height: 1.5,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: canReply && isOpen && !_sending,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: canReply
                          ? 'اكتب ردك للعميل...'
                          : 'الرد غير متاح حالياً',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                IconButton.filled(
                  onPressed: canReply && isOpen && !_sending
                      ? _sendMessage
                      : null,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF786BFA),
                    foregroundColor: Colors.white,
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  tooltip: 'إرسال',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(ThemeData theme, Map<String, dynamic> message) {
    final outgoing = message['direction'] == 'OUTBOUND';
    final attachment = message['attachmentUrl']?.toString();
    return Align(
      alignment: outgoing ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: outgoing
              ? const Color(0xFF786BFA).withValues(alpha: .17)
              : theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(outgoing ? 14 : 4),
            bottomRight: Radius.circular(outgoing ? 4 : 14),
          ),
          border: Border.all(
            color: outgoing
                ? const Color(0xFF786BFA).withValues(alpha: .16)
                : theme.dividerColor.withValues(alpha: .22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((message['body']?.toString() ?? '').isNotEmpty)
              Text(
                message['body'].toString(),
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
            if (attachment != null && attachment.isNotEmpty) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(attachment),
                  mode: LaunchMode.externalApplication,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.attach_file_rounded,
                      size: 16,
                      color: Color(0xFF958BFF),
                    ),
                    Text(
                      'فتح المرفق (${message['attachmentType'] ?? 'ملف'})',
                      style: const TextStyle(
                        color: Color(0xFF958BFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 5),
            Text(
              _timeLabel(message['createdAt']),
              style: TextStyle(
                fontSize: 9,
                color: theme.colorScheme.onSurface.withValues(alpha: .42),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPanel(ThemeData theme) {
    return Container(
      decoration: _panelDecoration(theme),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'تعذر تحميل المحادثات',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'تحقق من اتصال Backend وتسجيل الدخول.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration(ThemeData theme) => BoxDecoration(
    color: theme.cardColor,
    borderRadius: BorderRadius.circular(17),
    border: Border.all(color: theme.dividerColor.withValues(alpha: .35)),
  );

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _errorText(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        final message = data['message'];
        return message is List ? message.join('\n') : message.toString();
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'تعذر الاتصال بالخادم. تأكد أن Backend يعمل.';
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _channelLabel(String channel) {
    switch (channel) {
      case 'TELEGRAM':
        return 'Telegram';
      case 'INSTAGRAM':
        return 'Instagram';
      case 'MESSENGER':
        return 'Messenger';
      case 'WEBSITE':
        return 'موقع المتجر';
      default:
        return channel;
    }
  }

  IconData _channelIcon(String channel) {
    switch (channel) {
      case 'TELEGRAM':
        return Icons.send_rounded;
      case 'INSTAGRAM':
        return Icons.camera_alt_rounded;
      case 'WEBSITE':
        return Icons.language_rounded;
      case 'MESSENGER':
      default:
        return Icons.person_rounded;
    }
  }

  Color _channelColor(String channel) {
    switch (channel) {
      case 'TELEGRAM':
        return const Color(0xFF229ED9);
      case 'INSTAGRAM':
        return const Color(0xFFE56A9B);
      case 'WEBSITE':
        return const Color(0xFF27A889);
      case 'MESSENGER':
      default:
        return const Color(0xFF438AF5);
    }
  }

  String _timeLabel(dynamic value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return '';
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('MM/dd').format(local);
  }
}
