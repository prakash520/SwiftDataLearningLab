<img width="240" height="562" alt="Screenshot iPhone 17 12-10-2026 at 11 54 28 PM" src="https://github.com/user-attachments/assets/0b7ead30-93ff-415b-a4e8-a074247efcd4" />
<img width="240" height="562" alt="Screenshot iPhone 17 12-10-2026 at 11 54 39 PM" src="https://github.com/user-attachments/assets/6615a768-ba21-481f-af51-6beefbaf37be" />



# SwiftData Learning Lab

An offline iOS app that teaches SwiftData with runnable examples. The Xcode project, target, and source folder are `SwiftDataLearningLab`. The home screen title is SwiftData Learning Lab.

Deployment target: iOS 17. The store is local. CloudKit is not enabled.

## Run

Open `SwiftDataLearningLab.xcodeproj` and run the `SwiftDataLearningLab` scheme on an iPhone simulator.

## Test

Most tests use an in-memory `ModelContainer`. Unique-attribute and delete-rule tests use a temporary file store. None of them read or write the app's `LearningLab.store`.

On this SDK, `@Attribute(.unique)` keeps one row and a later save replaces that row. It does not throw. `deleteRule: .deny` is declared on `Department` and is not enforced: the department is deleted and its employees remain. The app checks both cases before writing. CloudKit, `#Unique`, `#Index`, and history APIs are explained in the lessons and are not enabled or compiled.

```bash
xcodebuild test -scheme SwiftDataLearningLab -destination 'platform=iOS Simulator,name=iPhone 16'
```

If that simulator is not installed, pick a name from:

```bash
xcrun simctl list devices available
```

In Xcode, use Product > Test.

The same instructions are on the Progress tab under How to run the tests.
