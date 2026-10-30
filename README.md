# dsc26-flt-w03 · Masaraat practice: fetching the next questions safely

DSC Summer Internship 2026 · Flutter track · Week 3 · **Flutter 3.47.6, Dart 3.13, `http` 1.6.0** · expected time 3–4 hours

## Scenario

When a Masaraat student opens practice, the app asks the backend for the next questions chosen for them. The student is on a cheap phone, on mobile data that drops in and out. You build the data layer and the practice screen so that every situation ends in a sensible screen and Arabic text arrives intact. The situations are: slow, offline, server busy, session expired, and nothing left to practise.

## Getting started

1. **Use this template** → a **public** repository in your own account named exactly **`dsc26-flt-w03`**.
2. `flutter pub get`, then `flutter test` (the public tests fail until you implement the task).

Do **not** rename the package (`name: dsc26_flt_w03`). The grader's tests import `package:dsc26_flt_w03/...`, so a renamed package scores 0.

## File layout

```text
lib/
  app.dart                                   buildPracticeApp (you write it)
  main.dart                                  demo entry point with a fake server (given; not graded)
  utils/result.dart                          Result, Ok, Err (given, do not change)
  data/services/api_failure.dart             sealed ApiFailure + subclasses with isTransient (given, do not change)
  data/services/question_api.dart            QuestionApi (you write it)
  data/repositories/practice_repository.dart PracticeRepository (you write it)
  domain/models/question.dart                Question (fields given; fromJson to write)
test/public_test.dart
AI_USAGE.md
```

Add your view model, state classes and widgets wherever you like (for example `lib/ui/practice/...`).

## What to build

### 1. `QuestionApi` (`lib/data/services/question_api.dart`)

Keep the constructor `QuestionApi({required http.Client client, required Uri baseUrl, Duration timeout = const Duration(seconds: 10)})` and the method:

```dart
Future<Result<List<Question>>> fetchNext({required String studentId, int limit = 10})
```

- **Request:** `GET {baseUrl}/v1/students/{studentId}/next-questions?limit={limit}` with the header `Accept: application/json`.
  - Keep any path the base URL already has (`https://gw.example/mobile/` → `/mobile/v1/students/...`). Ignore a trailing slash.
  - `studentId` is encoded as **one** path segment: a space becomes `%20`, a `/` becomes `%2F`. Use `baseUrl.replace(pathSegments: [...], queryParameters: {...})`, not string concatenation.
  - `limit` outside 1–50 throws `ArgumentError` before any request is sent. This is a programming error, not a network failure.
- **Response 200:** the body is `{"questions": [ {"id", "skillId", "stem", "choices": [...]} ]}`.
  - Decode it **from bytes as UTF-8, whatever the headers say** (`utf8.decode(response.bodyBytes)`). The tests send Arabic with no `Content-Type` at all, and with a header that wrongly claims Latin-1.
  - Unknown fields are ignored. `id`, `skillId` and `stem` are non-empty strings. `choices` is a list of 2 to 6 non-empty strings.
  - Malformed JSON, invalid UTF-8, a top-level array, a missing `questions` list, or any missing or wrongly typed field → `Err(BadResponse(...))`. Never throw.
- **Status mapping:**

| Status | Result |
|---|---|
| 200 | parse as above |
| 401 | `Err(Unauthorized())` |
| 404 | `Err(NotFound())` |
| 429 | `Err(RateLimited(retryAfter))`. `retryAfter` comes from the `retry-after` response header in whole seconds (`"12"` → 12 s, `"120"` → 120 s). If the header is missing or not a whole number (an HTTP date, `"2.5"`, text), use 5 s. `package:http` gives you header names in lower case. |
| 500–599 | `Err(ServerError(code))` |
| anything else | `Err(UnexpectedStatus(code))` |

- **Network failures:** `http.ClientException` → `Err(Offline())`. No answer within `timeout` (use `.timeout(...)`) → `Err(TimedOut())`. `fetchNext` never throws for network or server problems.

### 2. `PracticeRepository` (`lib/data/repositories/practice_repository.dart`)

Keep the constructor `PracticeRepository({required QuestionApi api, required Future<void> Function(Duration) sleep, int maxRetries = 2})` and `Future<Result<List<Question>>> nextQuestions(String studentId)`.

- **Transient** failures (`Offline`, `TimedOut`, `ServerError`, `RateLimited`: `failure.isTransient == true`) are retried up to `maxRetries` times. With the default that is at most 3 calls.
- Before retry *n* (0-based), call `sleep` with `2^n` seconds (1 s, 2 s, 4 s, ...). The one exception: when the failure you are retrying is `RateLimited`, sleep for its `retryAfter`, capped at 30 s. For example, a 429 with `retry-after: 7`, then a 503, then a 200 gives waits of 7 s and then 2 s.
- **Permanent** failures (`Unauthorized`, `NotFound`, `BadResponse`, `UnexpectedStatus`) are returned at once, after that one call, with no sleep. Decide by the failure type, not by counting calls.
- When retries run out, return the last result. Use only the injected `sleep` for waiting, never `Future.delayed` directly: the tests check the exact waits without actually waiting.

### 3. The practice screen: `buildPracticeApp` in `lib/app.dart`

`Widget buildPracticeApp({required PracticeRepository repository, String studentId = 'demo'})` returns the whole app (for example a `MaterialApp`). Use ChangeNotifier, Riverpod 3 or Bloc/Cubit inside; the tests do not care which.

- It loads once on start and shows a list of questions, an empty state ("you have finished today's practice"), or a failure view.
- The failure view has a friendly message and a retry button. For `Unauthorized` it shows a sign-in button **instead of** the retry button. **No text on screen may contain the word `Exception`.**
- A refresh action is **always** present in the app bar (in every state), **disabled while loading**. Tapping it twice quickly sends **one** request.
- Removing the app from the tree while a request is in flight (the tests do `tester.pumpWidget(const SizedBox())`) must not throw when the request or the retry wait finishes. Check `mounted` / `isClosed` / `ref.mounted` / your own disposed flag after every `await` that comes before a UI update.

**Keys the tests use:**

| Key | Widget |
|---|---|
| `practice-loading` | Shown while loading |
| `practice-list` | The list of questions |
| `question-<id>` | One row per question, e.g. `question-q1` |
| `practice-empty` | The empty state |
| `practice-error` | The failure view |
| `practice-retry` | Retry button in the failure view (every failure except `Unauthorized`) |
| `practice-signin` | Sign-in button in the failure view (`Unauthorized` only) |
| `practice-refresh` | The refresh action in the app bar |

Testing tips: `tester.pump()` while a spinner is showing, and `pumpAndSettle()` once data is in. A `Completer<http.Response>` lets a test decide when the server answers. When a mock body contains Arabic, use `http.Response.bytes(utf8.encode(json), 200)`.

## How grading works

Push, then press **Submit for grading** on DSC Hex (5 attempts per task per day). The grader copies your `lib/` into a clean project with the pinned packages, adds the hidden tests and runs `flutter test` on Flutter 3.47.6 with the network off. The run has a 10-minute limit and each test 30 seconds. You get 0–100 and one feedback line per row, with `passed / total` and a hint. If `lib/` does not compile, you score 0 and see the first compiler errors in your files.

| Row | Public name | Weight |
|---|---|---|
| H01 | request: URL building | 7 |
| H02 | request: method and headers | 3 |
| H03 | parsing: success | 10 |
| H04 | parsing: validation | 8 |
| H05 | status mapping | 8 |
| H06 | Retry-After parsing | 6 |
| H07 | network failures | 8 |
| H08 | retry policy (failure sequences from a per-submission seed) | 10 |
| H09 | rate-limit retries | 6 |
| H10 | no retry on permanent failures | 6 |
| H11 | screen states | 12 |
| H12 | refresh while loading | 8 |
| H13 | leaving mid-request | 8 |

Row score = weight × passed ÷ total. Late policy: ×1.0 within 72 hours of the session starting, ×0.6 for the following 7 days, ×0.5 after that until Thu 3 Dec 23:59; W5 reopens W2–W4 at ×1.0. Best attempt counts. The tests never depend on your message wording, only on keys and the absence of `Exception`.

## `AI_USAGE.md` (required)

Fill in: the tools you used; the prompts that helped most; one place where the assistant's code would have failed a hidden-test area above (for example it used `response.body`, retried a 401, or forgot the disposed check) and how you noticed; and which state-management option you chose, with one sentence on why.
