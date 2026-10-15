# Photo Labeller (iOS)

- SwiftUI app, iOS 17+ deployment target, Swift 5 language mode.
- Build: see the xcodebuild command in this file; always use CODE_SIGNING_ALLOWED=NO.
- Source lives in PhotoLabeller/ (Models, Views, Services). Keep new files in these folders.
- Add any new Swift file to PhotoLabeller.xcodeproj/project.pbxproj, or the target won't compile it.
- Don't change the bundle identifier or signing team without asking.

## Build command

```bash
xcodebuild -project PhotoLabeller.xcodeproj -scheme PhotoLabeller -destination 'id=0CD1C709-4FBB-4456-A204-A84DD420B811' CODE_SIGNING_ALLOWED=NO build
```
