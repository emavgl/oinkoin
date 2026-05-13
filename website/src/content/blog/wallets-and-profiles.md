---
title: 'New Wallets and Profiles Feature'
description: 'Oinkoin now supports wallets, profiles, and per-wallet currencies — the biggest structural update to the app yet.'
pubDate: 2026-04-25
---

We're thrilled to announce Oinkoin **1.6.0** — the most significant update to the app since its launch. This release introduces three interconnected features that fundamentally expand how you can organise your finances: **wallets**, **profiles**, and **per-wallet currencies**.

## Wallets — One App, All Your Accounts

Until now, all your records lived in a single bucket. Starting with 1.6.0, you can create as many wallets as you need — one for your current account, one for savings, one for cash in your wallet, one for each credit card. Each wallet tracks its own balance independently.

### A Dedicated Wallets Tab

A new **Wallets** tab gives you a clear overview of all your accounts at a glance. The header shows your combined balance across all active wallets. Tap the label to filter the view to specific wallets — perfect for focusing on just your everyday spending accounts while keeping the savings wallet out of the picture.

### Full Customisation

When creating or editing a wallet you can set:

- **Name** — anything from "Cash" to "Emergency Fund"
- **Starting balance** — set the current real-world balance; Oinkoin stores it as an opening amount so your existing records stay untouched
- **Icon** — hundreds of icons to choose from, including emoji support
- **Colour** — the same palette used for categories, making it easy to tell accounts apart at a glance
- **Currency** — assign an ISO 4217 currency code to the wallet (more on this below)

### Assign Records to a Wallet

Every record is now linked to a wallet. When adding or editing a record, you choose which wallet it belongs to. Transfer records — money moved from one wallet to another — are fully supported, and Oinkoin correctly adjusts both balances.

### Sort and Reorder

The wallet list can be sorted by name, by balance (ascending or descending), or kept in your own custom order. Custom ordering uses a drag-to-reorder mode: tap the sort icon, select "Custom order", and drag wallets into the sequence that makes sense to you. Your chosen sort order can be saved as the default.

### Archive Instead of Delete

When an account is no longer active — a closed bank account, a spent gift card — you can **archive** it rather than delete it. Archived wallets disappear from the main list but their records and history are preserved. You can always unarchive, or, if you really want to clean up, delete a wallet entirely and choose what happens to its records: delete them, move them to another wallet, or keep them in the default wallet.

---

## Profiles — Separate Finances for Separate Lives

Profiles take data separation to the next level. Each profile is a completely independent environment with its own wallets, records, categories, and recurring patterns. Switching profiles is instant.

Common use cases:

- **Personal vs. business** — keep household expenses and freelance invoicing completely separate without running two apps
- **Family members** — each person in the household manages their own data on the same device
- **What-if planning** — duplicate your setup into a second profile to model a budget scenario without touching your real data

You can mark one profile as the **default** so the app always opens into the right context. And just like wallets, profiles can be renamed or deleted (deleting a profile removes all its wallets and records, after a confirmation prompt).

---

## Per-Wallet Currencies — Multi-Currency Made Simple

If you hold accounts in more than one currency, you can now assign a currency to each wallet.

### Balance Breakdown

When wallets in your view use different currencies, the combined balance header becomes interactive. Tap it to expand a **currency breakdown** showing the subtotal for each currency separately. If you have configured a main (default) currency with conversion rates, Oinkoin also shows an approximate grand total converted into that currency.

### Conversion Rates

Setting up multi-currency is straightforward. The first time you assign a currency to a wallet you'll be prompted to choose a **main currency** — the one everything else is expressed relative to. Then, for each additional currency, you enter a conversion rate against the main. Oinkoin uses these rates when computing the combined total.

Custom currencies (anything not in the built-in ISO list) can be added as well, which covers loyalty points, commodity-backed assets, or any unit you want to track as a balance.

### No Silent Surprises

Changing the currency of an existing wallet does not silently reinterpret your historical amounts. Oinkoin warns you explicitly: the currency label changes but all record values stay exactly as entered. This keeps your data honest when, for example, you realise you had the wrong currency set.

---

## Upgrade Now

All wallet and profile management features are part of **Oinkoin Pro**. The default wallet and the single default profile are always free.

Download version **1.6.0** from [Google Play](https://play.google.com/store/apps/details?id=com.emavgl.piggybank) or grab the APK directly from our [GitHub releases page](https://github.com/emavgl/oinkoin/releases/tag/1.6.0).

As always, if you run into any issues or have ideas for what to build next, open an issue or start a discussion on [GitHub](https://github.com/emavgl/oinkoin). Thank you for using Oinkoin!
