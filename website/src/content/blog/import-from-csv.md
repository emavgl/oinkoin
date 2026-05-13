---
title: 'Import from CSV'
description: 'Oinkoin now lets you import records from a CSV file or clipboard — quickly bring your data from other apps into Oinkoin.'
pubDate: 2026-05-03
---

We're excited to introduce the **Import from CSV** feature — a simple way to bring your financial data into Oinkoin from other apps, spreadsheets, or bank exports.

## Three Steps to Import

The import flow walks you through three screens: load your data, map the columns, and confirm the import.

### 1. Load Your CSV

Head to **Settings → Import from CSV**. You can either pick a CSV file from your device or paste CSV content directly from your clipboard. Oinkoin automatically detects the delimiter (comma, semicolon, or tab) and handles UTF-8 files with or without a BOM.

### 2. Preview Your Data

After loading, you'll see a preview table showing the first rows of your CSV alongside detected columns. This gives you a quick sanity check before mapping begins.

### 3. Map Columns

Each Oinkoin field — **Title**, **Amount**, **Date/Time**, **Category**, **Description**, **Tags**, and **Wallet** — gets its own dropdown where you select which CSV column contains that data. Columns with matching names are auto-detected, so in most cases you only need to review and confirm the mapping.

A live preview below the mapping area shows how the first parsable row will look once imported, letting you verify that amounts, dates, and categories are interpreted correctly before committing.

### 4. Review and Import

The summary screen shows you exactly what will be imported: the total number of records, unique categories, tags, wallets, and the date range. Any rows that couldn't be parsed (missing amounts or dates, for example) are reported as warnings. When you're happy, tap **Import**.

## What Gets Imported

Oinkoin handles the details so you don't have to:

- **Amounts** are parsed from common formats — with or without currency symbols, thousand separators, and locale-aware decimal separators (period or comma). Negative amounts in parentheses `(50.00)` are also recognised.
- **Dates** are parsed from a wide range of formats — ISO 8601, slash/dash/dot delimiters, with or without time components, and Unix timestamps.
- **Categories** are created automatically based on the category name. The category type (Income or Expense) is derived from the amount's sign — positive amounts become Income, negative become Expense.
- **Tags** can be separated by comma or semicolon within a single CSV cell.
- **Duplicates** are automatically skipped — records matching an existing one on datetime, value, title, category, and wallet won't be imported twice.

## Wallet Mapping

If your CSV includes wallet information, you can map it to the Wallet field. Wallet support is an **Oinkoin Pro** feature — non-Pro users will see a PRO label on the Wallet mapping row.

## Saved Mappings

Found a mapping that works well for your bank's CSV export? You can save it with a custom name and load it again later — no need to re-map the same columns every time.

---

Import from CSV is available now in Oinkoin **version 1.6.3+**. Download it from [Google Play](https://play.google.com/store/apps/details?id=com.emavgl.piggybank) or grab the APK from our [GitHub releases page](https://github.com/emavgl/oinkoin/releases).

Have questions or feedback? Open an issue or start a discussion on [GitHub](https://github.com/emavgl/oinkoin).
