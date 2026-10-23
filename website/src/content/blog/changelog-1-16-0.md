---
title: 'Changelog 1.16.0: Hidden Wallets'
description: 'Keep a wallet out of your lists and combined balance without losing its records, statistics, or ability to receive transfers.'
pubDate: 2026-10-23
---

Oinkoin **1.16.0** introduces **hidden wallets**: a way to keep a wallet out of your everyday view and out of your combined balance, while keeping all of its history and its ability to send and receive money.

This release also fixes how single-side transfers are counted in budgets, the home page totals, and statistics.

## Why hidden wallets?

The Wallets tab is meant to answer one question quickly: *how much money do I have available right now?* But not every wallet belongs in that answer.

Some wallets are **real but not spendable day to day**: a long-term savings account, a deposit, a gift card, a wallet you track for someone else. Others are **still around for their history** even though the account is closed. Keeping them visible clutters every list and every picker, and including them in the combined balance makes your available money look bigger than it is.

Until now the only options were to keep the wallet in plain sight or archive it. Archiving is for accounts that are finished — you cannot use them for new records. Hidden wallets are different: they are **active wallets that simply stay out of the way**.

## How it works

Open **Wallets → Edit Wallet** and find the new **Visibility** section. Turn on **Hidden**.

From that moment the wallet:

- disappears from the Wallets tab list and from the combined balance;
- disappears from ordinary wallet pickers;
- stops appearing in saved home and Wallets-tab filters (if it was selected, it is removed so hiding takes effect immediately).

Nothing is deleted. The wallet still exists, and you can reveal it at any time with **⋮ → Show hidden wallets** in the Wallets tab or in a picker.

## What stays visible

This is the important part: hiding changes **where a wallet is shown and whether it counts in totals**, not whether its history exists.

- **Records** remain in the home list and in the overview card.
- **Statistics** remain complete, including the "Group by wallet" breakdown.
- **Budgets** are untouched. "All wallets" still means all wallets, hidden ones included; use the budget's wallet picker if you want to leave one out.
- **Transfers** to and from a hidden wallet keep working. The transfer pickers always list hidden wallets (dimmed), so you never have to reveal anything just to move money.

A hidden wallet also counts in the combined balance **when you select it explicitly**, either from the picker or through a saved selection. That keeps the rule simple: hidden means "out of the default view", not "invisible to the app".

## Examples

### The emergency fund

You have a current account with €1,200 and an emergency fund with €8,000. You want the Wallets tab to show the money you can actually spend, not €9,200.

Hide the emergency fund. The combined balance now shows €1,200. Every month you still record a €200 transfer from the current account to the emergency fund — the transfer picker lists it, so nothing gets in the way. When you want to check the fund, open **⋮ → Show hidden wallets** or open a record that uses it.

### The closed bank account

You closed an account two years ago, but its records are part of your history. Archiving would make it a finished account; hiding keeps it active but out of sight, so your wallet list stays focused while the old records remain in statistics and in your backup.

### Gift cards and vouchers

A €50 gift card is money you have, but it is not part of your monthly budget. Hide it. When you spend from it, reveal it, record the expense, and hide it again — or simply pick it from the transfer/expense flow when it is relevant.

### A wallet you track for someone else

If you keep a wallet for a family member's expenses, hide it so it does not inflate your own available balance. Its spending still appears in the records and in the statistics of that wallet, and you can still add records to it by revealing it in the picker.

## Hidden or archived?

| | Hidden | Archived |
|---|---|---|
| Wallet list | Out of the list (reveal to see) | Out of the list |
| Combined balance | Excluded by default | Excluded |
| New records | Allowed (reveal or pick in transfers) | Not selectable |
| Records and statistics | Kept | Kept |
| Purpose | Active wallet, out of the way | Account no longer in use |

If the account is finished, archive it. If it is alive but should not clutter your spending picture, hide it.

## FAQ

**Does hiding a wallet delete its records?**
No. Records, transfers, budgets and statistics are untouched.

**Can I still transfer money to a hidden wallet?**
Yes. Transfer pickers always list hidden wallets, dimmed so you can tell them apart.

**Why is a hidden wallet still in my statistics?**
Because statistics describe what happened, not what you consider spendable. Hiding affects lists and totals, not history.

**Does the hidden wallet appear in "All wallets" budgets?**
Yes. "All wallets" is literal. If you want to exclude it, deselect it in the budget's wallet picker.

**How do I unhide it?**
Edit the wallet and turn **Hidden** off. It returns to the wallet list, pickers, and the combined balance.

**What happens to a saved filter that included the wallet?**
Hiding it removes it from that saved selection, so the filter does not keep counting a wallet you just hid.

---

Version **1.16.0** is available now on [Google Play](https://play.google.com/store/apps/details?id=com.emavgl.piggybank) and on the [GitHub releases page](https://github.com/emavgl/oinkoin/releases/tag/1.16.0).
