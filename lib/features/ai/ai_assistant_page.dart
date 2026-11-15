import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final _promptController = TextEditingController();
  final ApiClient _api = ApiClient.instance;
  final List<_AiMessage> _messages = [
    const _AiMessage(
      text:
          'أهلاً بك في NEXOR AI. أصبحت أستطيع تحليل ملخص بيانات متجرك الفعلية، مثل المبيعات والطلبات والمخزون والمشتريات والمرتجعات. اسألني عن أداء آخر 30 يوماً أو اطلب توصية مبنية على الأرقام.',
      isUser: false,
    ),
  ];
  final List<String> _suggestions = [
    'لخّص أداء المبيعات لهذا الأسبوع',
    'ما المنتجات التي قاربت على النفاد؟',
    'ما أكثر المنتجات مبيعاً خلال آخر 30 يوماً؟',
    'حلّل الطلبات الملغاة واقترح أسباباً محتملة',
    'قارن المبيعات بالمشتريات والمرتجعات',
  ];

  bool _isSending = false;
  bool _isCheckingStatus = true;
  bool _aiEnabled = false;
  String? _modelName;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final response = await _api.get<dynamic>('ai/status');
      final data = _asMap(response.data);
      if (!mounted) return;
      setState(() {
        _aiEnabled = data['enabled'] == true;
        _modelName = data['model']?.toString();
        _statusError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiEnabled = false;
        _statusError = 'تعذر التحقق من حالة الخادم. تأكد من الاتصال وتسجيل الدخول.';
      });
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _isCheckingStatus
        ? const Color(0xFFF0B65F)
        : (_aiEnabled ? const Color(0xFF39B982) : const Color(0xFFF0B65F));
    final statusLabel = _isCheckingStatus
        ? 'جارٍ التحقق'
        : (_statusError != null
            ? 'تعذر التحقق'
            : (_aiEnabled ? 'مفتاح Gemini مضبوط' : 'المحرك غير مهيأ'));
    final statusMessage = _isCheckingStatus
        ? 'يجري التحقق من اتصال محرك الذكاء الاصطناعي...'
        : (_statusError ??
            (_aiEnabled
                ? 'تم ضبط Google Gemini. عند إرسال سؤال، يجلب NEXOR ملخص آخر 30 يوماً للطلبات والمبيعات والمشتريات والمرتجعات والمخزون ويرسله إلى Gemini. لا نرسل أسماء العملاء أو الموردين أو بيانات تواصلهم؛ تجنب إدخال بيانات شخصية أو كلمات مرور في السؤال.'
                : 'الواجهة جاهزة، لكن مفتاح Google Gemini غير مضبوط في Backend. أضف GEMINI_API_KEY إلى ملف إعدادات الخادم ثم أعد تشغيله لتفعيل التحليل الحقيقي.'));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 23, 25, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXOR INTELLIGENCE',
                        style: TextStyle(
                          color: Color(0xFF9188FF),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'مساعد AI',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'مركز مساعدتك الذكي لفهم متجرك واتخاذ قرارات أفضل.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: .55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: statusColor.withValues(alpha: .25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: statusColor,
                        size: 9,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        statusLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF8175FF).withValues(alpha: .08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: const Color(0xFF8175FF).withValues(alpha: .18),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _aiEnabled
                        ? Icons.verified_user_outlined
                        : Icons.info_outline_rounded,
                    color: const Color(0xFF9B92FF),
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      statusMessage,
                      style: const TextStyle(fontSize: 10, height: 1.5),
                    ),
                  ),
                  if (!_isCheckingStatus && !_aiEnabled)
                    IconButton(
                      tooltip: 'إعادة فحص الاتصال',
                      onPressed: () {
                        setState(() => _isCheckingStatus = true);
                        _checkStatus();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 900;
                  final chat = _chatPanel(theme);
                  final side = _toolsPanel(theme);
                  if (isNarrow) {
                    return Column(
                      children: [
                        SizedBox(height: 285, child: side),
                        const SizedBox(height: 12),
                        Expanded(child: chat),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(width: 300, child: side),
                      const SizedBox(width: 14),
                      Expanded(child: chat),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolsPanel(ThemeData theme) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Color(0xFF9B92FF)),
                SizedBox(width: 9),
                Text(
                  'ماذا تريد أن تفعل؟',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              'ابدأ بأحد الاقتراحات الجاهزة.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: .5),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => InkWell(
                  onTap: _isSending
                      ? null
                      : () {
                          _promptController.text = _suggestions[index];
                          _promptController.selection = TextSelection.collapsed(
                            offset: _promptController.text.length,
                          );
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: .25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: Color(0xFF9B92FF),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _suggestions[index],
                            style: const TextStyle(
                              fontSize: 10,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.north_west_rounded,
                          size: 13,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8175FF).withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 17,
                    color: Color(0xFF9B92FF),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'يُرسل ملخص تشغيلي محدود دون بيانات تواصل العملاء والموردين. يُرسل أيضاً سؤالك وسياق المحادثة إلى مزود AI؛ تجنب إدخال بيانات شخصية أو كلمات مرور.',
                      style: TextStyle(fontSize: 9, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatPanel(ThemeData theme) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9B92FF), Color(0xFF675DE1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXOR AI Assistant',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _aiEnabled
                            ? 'متصل ببيانات المتجر${_modelName == null ? '' : ' • $_modelName'}'
                            : 'بانتظار إعداد مفتاح API',
                        style: const TextStyle(color: Colors.grey, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSending
                      ? null
                      : () => setState(() {
                          _messages
                            ..clear()
                            ..add(
                              const _AiMessage(
                                text:
                                    'بدأنا محادثة جديدة. اسألني عن بيانات متجرك وسأجيب اعتماداً على ملخص آخر 30 يوماً.',
                                isUser: false,
                              ),
                            );
                        }),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                    'محادثة جديدة',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              width: double.infinity,
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF10131C)
                  : const Color(0xFFF7F8FC),
              child: ListView.builder(
                padding: const EdgeInsets.all(21),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isSending && index == _messages.length) {
                    return const Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 13),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 9),
                            Text('أحلّل بيانات متجرك...', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }
                  final m = _messages[index];
                  return Align(
                    alignment: m.isUser
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      margin: const EdgeInsets.only(bottom: 13),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: m.isUser
                            ? const Color(0xFF6C63FF)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: m.isUser
                            ? null
                            : Border.all(
                                color: theme.dividerColor.withValues(
                                  alpha: .25,
                                ),
                              ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!m.isUser)
                            const Padding(
                              padding: EdgeInsets.only(left: 9),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF9B92FF),
                                size: 18,
                              ),
                            ),
                          Expanded(
                            child: SelectableText(
                              m.text,
                              style: TextStyle(
                                color: m.isUser
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                                fontSize: 11,
                                height: 1.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    enabled: !_isSending,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendPrompt(),
                    decoration: const InputDecoration(
                      hintText: 'اكتب سؤالك عن متجرك...',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                FilledButton(
                  onPressed: _isSending ? null : _sendPrompt,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF786BFA),
                    minimumSize: const Size(50, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _isSending) return;

    final recentHistory = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : List<_AiMessage>.from(_messages);

    setState(() {
      _messages.add(_AiMessage(text: prompt, isUser: true));
      _promptController.clear();
      _isSending = true;
    });

    try {
      final response = await _api.post<dynamic>(
        'ai/chat',
        data: {
          'message': prompt,
          'history': recentHistory
              .map(
                (message) => {
                  'role': message.isUser ? 'user' : 'assistant',
                  'content': message.text,
                },
              )
              .toList(),
        },
      );
      final data = _asMap(response.data);
      final reply = data['reply']?.toString().trim();
      if (reply == null || reply.isEmpty) {
        throw Exception('لم تصل إجابة من محرك الذكاء الاصطناعي.');
      }
      if (!mounted) return;
      setState(() => _messages.add(_AiMessage(text: reply, isUser: false)));
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _AiMessage(text: _friendlyError(error), isUser: false),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _AiMessage(
            text: error.toString().replaceFirst('Exception: ', ''),
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _friendlyError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List && message.isNotEmpty) {
        return message.map((item) => item.toString()).join('\n');
      }
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'تعذر الاتصال بالخادم. تأكد أن Backend يعمل وأن عنوان API صحيح.';
    }
    if (error.response?.statusCode == 401) {
      return 'انتهت جلسة الدخول. سجّل الدخول مجدداً.';
    }
    return 'تعذر الحصول على إجابة من NEXOR AI. تحقق من إعدادات الخادم وحاول مجدداً.';
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

class _AiMessage {
  final String text;
  final bool isUser;
  const _AiMessage({required this.text, required this.isUser});
}
