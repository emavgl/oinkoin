---
title: 'Changelog 1.15.0: Per-Transfer Exchange Rates and Chinese (Traditional)'
description: 'Set the amount received on each transfer and let Oinkoin calculate the exchange rate, plus Chinese (Traditional) support.'
pubDate: 2026-10-10
---

**Changelog 1.15.0**

New features:
- Per-transfer exchange rates: when you move money between wallets with different currencies, enter the amount that actually arrived and Oinkoin calculates the rate. Cross-currency transfers now show both the sent and received amounts.
- Chinese (Traditional) is now available as a language.

Fixes:
- A wallet without a currency is treated as the default currency.
- Amount inputs: currency spacing follows your preference and there is no longer a stray trailing space.
- In-app keyboard: fast taps during the slide-in animation now register.
- Fixed a startup crash for locales without intl data.
- Amount expressions are evaluated before saving.
- Technical translation fixes.
