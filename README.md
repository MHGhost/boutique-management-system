# SR Branded Boutique POS

Offline-first Flutter desktop software for clothing inventory, purchases, sales, returns, reports, and invoice printing. It uses PKR and does not calculate VAT. The Windows app stores data in a local SQLite database and does not sync data between computers.

## Build and verify

From the project folder, with Flutter and the Windows desktop toolchain installed:

```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter build windows --release
```

For client delivery, copy the **entire** `build\windows\x64\runner\Release` folder. Do not send only `inventoryapp.exe`; the Flutter runtime, plugins, and assets beside it are required. Run the app from that folder on the target PC and complete a shop workflow before handing it over.

The release ZIP includes `CLIENT_HANDOFF.md` with first-run, local-data, and backup guidance.

## First launch

The first launch asks the shop owner to create the initial administrator account. Keep its password private. Then enter business details in Settings, create a backup, and verify a test invoice prints correctly. Currency is PKR; VAT is not used.

At checkout, the owner can enter a fixed discount in PKR. The app validates it against the sale subtotal and includes the discount in line-level profit calculations and the invoice total. From Invoice Preview, choose **Save invoice PDF to this PC** to save a copy under `Documents\SR Branded Boutique\Invoices`.

## Database and backups

The live database is stored at `%USERPROFILE%\Documents\friends_inventory.sqlite`. Use Settings → Data Backup to create a consistent SQLite backup. Backups are placed under `%USERPROFILE%\Documents\InventoryBackups`. They remain on this computer until copied to another safe location. A backup may contain customer and sales data, so protect it accordingly.

Add dated rent, utilities, wages, and other operating costs under Settings → Business Expenses. Enter recurring costs for each period; reports subtract only costs dated in the selected period, so adding a new expense does not rewrite past totals. Profit reports adjust gross profit for refunds, exchanges, restocked returns, and replacement item cost, then subtract operating expenses. Stock purchase costs stay in cost of goods sold and are not counted again as business expenses. Existing replacement records are migrated using the product's current catalog purchase cost as an estimate because older versions did not store the replacement cost at the time of the return.

The app currently creates backups but does not provide an in-app restore flow. For recovery, close the app first and have a technician restore a verified backup; preserve a copy of the current database before replacing anything. Do not copy the live SQLite file while the app is open.

## Before client handoff

- Build from the exact source revision intended for delivery.
- Run `flutter analyze` and `flutter test` and resolve any failures.
- Test on the target Windows computer: first-run admin setup, product stock, purchase, sale, invoice output, refund or exchange, supplier return, report, and printing.
- Create a backup and confirm the file exists and is non-empty.
- Agree with the client on who owns administrator credentials and who will copy backups off the computer.

This README describes the implementation; it is not a substitute for acceptance testing on the client's hardware and printer.
