PennyTests migration fixtures.

PR 2 adds Penny-v1.0.4.store here (a store written by the shipping app).
The PennyTests target bundles this folder, so the file is copied into the test bundle
without another Xcode project edit.

The upgrade test must open that store and prove no data is lost, including a timing
check that migrates about 5,000 transactions.
