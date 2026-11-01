# AI usage: dsc26-flt-w03

## 1. Tools I used

- ChatGPT: Used to understand the task requirements, implement the data layer and practice screen, and explain code issues.
- Claude: Used for an independent review of the implementation against the task requirements.
- Flutter CLI: Used `flutter test` and `flutter analyze` to check the implementation.

## 2. The prompts that helped most

1. "Implement the QuestionApi and PracticeRepository according to the W3 task requirements, including response parsing, error handling, and retry behavior."

2. "Review my Flutter implementation against the W3 task requirements. Check the API behavior, retry policy, UI states, refresh behavior, and handling requests when the screen is disposed."

## 3. Where the assistant's code would have failed a hidden-test area, and how I noticed

In an earlier ChatGPT-generated version of `app.dart`, the ViewModel did not check whether it had been disposed before calling `notifyListeners()` after an API request completed. If the screen was removed while a request was still in progress, this could cause a Flutter error and fail H13. Claude identified this during an independent code review. I fixed it by adding a `_disposed` flag, checking it before updating the state or calling `notifyListeners()`, and setting it to true in `dispose()`.

## 4. My state-management choice

I chose ChangeNotifier to keep the loading state and API result in one ViewModel, separating UI updates from the widgets.