# CoreDataMigrationHelper

Manage Core Data store migrations with a paginated approach for handling large datasets.

## Usage

```swift
guard let oldModelURL = Bundle.main.url(forResource: "CoreDataTest", withExtension: "momd")?.appendingPathComponent("CoreDataTest.mom"),
      let oldModel = NSManagedObjectModel(contentsOf: oldModelURL)
else { fatalError() }
    
guard let newModelURL = Bundle.main.url(forResource: "CoreDataTest", withExtension: "momd")?.appendingPathComponent("CoreDataTest v2.mom"),
    let newModel = NSManagedObjectModel(contentsOf: newModelURL)
else { fatalError() }
    
let migrator = ManualMigrator(from: oldModel, to: newModel, sourceStoreURL: AppDelegate.current.storeURL, migrationVersion: 1)
migrator.eventDelegate = self
DispatchQueue.global().async {
  migrator.start()
}
```

## Install

Currently, this project is not available through CocoaPods\SPM. Please copy the code into your project directly.
