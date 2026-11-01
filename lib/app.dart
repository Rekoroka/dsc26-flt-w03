import 'package:flutter/material.dart';

import 'data/repositories/practice_repository.dart';
import 'data/services/api_failure.dart';
import 'domain/models/question.dart';
import 'utils/result.dart';

Widget buildPracticeApp({
  required PracticeRepository repository,
  String studentId = 'demo',
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // الواجهة عربية، فنفرض اتجاه RTL (Right-To-Left) على التطبيق كله.
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: PracticeScreen(repository: repository, studentId: studentId),
  );
}

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.repository,
    required this.studentId,
  });

  final PracticeRepository repository;
  final String studentId;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final PracticeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PracticeViewModel(
      repository: widget.repository,
      studentId: widget.studentId,
    );
    _viewModel.load(); // تحميل واحد عند البداية
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // الـ Scaffold كله داخل ListenableBuilder علشان زر الـ refresh
    // في الـ AppBar يتحدّث (يتفعّل/يتعطّل) مع تغيّر الحالة.
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('تمارين اليوم'),
            actions: [
              IconButton(
                key: const Key('practice-refresh'),
                tooltip: 'تحديث',
                onPressed: _viewModel.isLoading ? null : _viewModel.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final result = _viewModel.result;

    if (_viewModel.isLoading || result == null) {
      return const Center(
        child: CircularProgressIndicator(key: Key('practice-loading')),
      );
    }

    return switch (result) {
      Ok(:final value) =>
        value.isEmpty ? _buildEmpty() : _buildList(context, value),
      Err(:final failure) => _buildError(context, failure),
    };
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text(
        'أنهيت تمارين اليوم، أحسنت!',
        key: Key('practice-empty'),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Question> questions) {
    return ListView.builder(
      key: const Key('practice-list'),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        return Card(
          key: Key('question-${question.id}'),
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.stem,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...question.choices.map(
                  (choice) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(choice),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // رسالة مناسبة لكل نوع failure. الـ switch exhaustive لأن ApiFailure sealed.
  // لا نعرض toString() أبدًا حتى لا تظهر كلمة Exception.
  String _messageFor(ApiFailure failure) {
    return switch (failure) {
      Offline() || TimedOut() =>
        'الاتصال ضعيف أو غير متاح. تأكد من الإنترنت وحاول مرة أخرى.',
      ServerError() ||
      RateLimited() => 'الخادم مشغول الآن. حاول مرة أخرى بعد قليل.',
      Unauthorized() => 'انتهت الجلسة. سجّل الدخول مرة أخرى.',
      NotFound() ||
      BadResponse() ||
      UnexpectedStatus() => 'حدثت مشكلة في تحميل الأسئلة. حاول مرة أخرى.',
    };
  }

  Widget _buildError(BuildContext context, ApiFailure failure) {
    final isUnauthorized = failure is Unauthorized;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: const Key('practice-error'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(_messageFor(failure), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (isUnauthorized)
              ElevatedButton(
                key: const Key('practice-signin'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تسجيل الدخول غير متاح حاليًا.'),
                    ),
                  );
                },
                child: const Text('تسجيل الدخول'),
              )
            else
              ElevatedButton(
                key: const Key('practice-retry'),
                onPressed: _viewModel.isLoading ? null : _viewModel.refresh,
                child: const Text('إعادة المحاولة'),
              ),
          ],
        ),
      ),
    );
  }
}

class PracticeViewModel extends ChangeNotifier {
  PracticeViewModel({
    required PracticeRepository repository,
    required String studentId,
  }) : _repository = repository,
       _studentId = studentId;

  final PracticeRepository _repository;
  final String _studentId;

  bool _isLoading = true; // أول حالة هي loading
  bool _disposed = false;
  Result<List<Question>>? _result;

  bool get isLoading => _isLoading;
  Result<List<Question>>? get result => _result;

  /// التحميل الأول: الحالة loading أصلًا، فلا نحتاج notifyListeners قبل الطلب.
  Future<void> load() => _fetch();

  /// تجاهل أي ضغطة أثناء التحميل، فالضغط المزدوج يرسل طلبًا واحدًا فقط.
  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    await _fetch();
  }

  Future<void> _fetch() async {
    Result<List<Question>> result;
    try {
      result = await _repository.nextQuestions(_studentId);
    } catch (_) {
      result = const Err(BadResponse('Unexpected error'));
    }

    // الخروج من الشاشة أثناء الطلب أو أثناء انتظار الـ retry:
    // لا نلمس الـ notifier بعد dispose.
    if (_disposed) return;

    _result = result;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
