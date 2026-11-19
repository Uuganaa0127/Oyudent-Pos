# Oyudent POS Desktop

Flutter desktop order-entry app for Oyudent admin, with a sample-data mode and an API-connected mode.

## Run

```sh
flutter pub get
flutter run -d macos
```

The app can also be built for Windows or Linux from a machine with that platform's Flutter desktop build tools installed.

### Installable builds

On a Mac with Flutter and Xcode installed, run this from the project folder.

```sh
bash packaging/build-macos.sh
```

Open the resulting `.pkg` in `build/installers` to install Oyudent POS in Applications. This local build is unsigned. For public distribution, use Developer ID signing and notarization.

On a Windows x64 build PC, install Flutter, Visual Studio with **Desktop development with C++**, and Inno Setup 6. In PowerShell, run this from the project folder.

```powershell
powershell -ExecutionPolicy Bypass -File .\packaging\build-windows.ps1
```

The setup EXE in `build/installers` includes the app, Flutter assets, plugins, and the x64 Visual C++ runtime. It installs for the current user and adds a Start menu shortcut. The build tools are needed only on the build PC.

## Oyudent order APIs currently connected

The POS connection uses the API host and routes observed in the admin order-create page:

- `GET /admin/api/v1/company/ref` — company options for billing.
- `GET /admin/api/v1/branch/ref` — branch options.
- `GET /admin/api/v1/ref-data/PRODUCT_CATEGORY` — product category filters.
- `GET /admin/api/v1/product/list?no_paginate=1&sort=-created_at,-id` — full product catalog, merged with branch stock so unstocked products remain searchable and are marked unavailable.
- `GET /admin/api/v1/order/get-available-stocks?branch_id=...` — available product variants, warehouse, quantity, lot/reference, and price.
- `POST /admin/api/v1/company` — creates a company from the POS billing selector.
- `POST /admin/api/v1/order/` — saves an order with company, branch, VAT mode, invoice date, note, bank account numbers, totals, and line product/variant/warehouse/price/quantity/note fields.

Checkout offers a payment receipt plus separate VAT and no-VAT invoice actions. A receipt summary is shown after a successful save; the API request carries the selected VAT mode and matching totals.
- `GET /admin/api/v1/order/list?no_paginate=1&sort=-created_at,-id` — Zarlaga invoice list with customer, amount, and status fields.
- `POST /admin/api/v1/order/change-status` — applies the same allowed delivery-status transitions as the admin order list.
- `POST /admin/api/v1/order/:id/ship` — creates the delivery invoice for an order in preparing status.
- `POST /admin/api/v1/product/excel` — bulk product import using multipart fields `file`, optional `images_zip`, `upsert`, and `dry_run`.

The observed page also requests `/order/detail/:id` for editing an existing order; this desktop app currently supports creating orders, not loading/editing existing ones. Zarlaga (expenses) is still sample-only.

## Access token

Sign in with the same username and password used at admin.oyudent.com. The app calls `POST /admin/api/v1/admin-user/login`, then `GET /admin/api/v1/admin-user/info` with the returned Bearer token, and loads company, branch, and stock data. The access token and password are kept in memory only; they are not persisted. A manual Bearer-token connection remains available from the POS header. The order APIs have not been exercised against a live account here, and no order was submitted during implementation.

If no API token is connected, the POS uses its sample products and sample stock. The bulk product importer also requires a token. The provided workbook uses `Products` and `Variants` sheets; `product_bulk_template.xlsx` is an example template.
