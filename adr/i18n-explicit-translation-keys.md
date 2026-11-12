# I18n Explicit Translation Keys

Status: Accepted

Date: 2026-05-25

Scope amendment (owner-approved surface hard reset, 2026-11-11): local user-facing copy now belongs
to Docs, News, Help, Info, and Edit. The retired `sign.app`, `sign.com`, and `sign.org` translation
trees were removed; the remaining shared Edit sign-out and passkey-default keys stay explicit.

## Context

Controllers, services, views, and policies need user-facing messages across the application
surfaces. Rails allows inline fallback text through `I18n.t(..., default: "...")`, but that pattern
hides missing translation keys and makes surface-specific copy drift difficult to review.

Dynamic translation key construction is also risky. Calls such as `t("abc.#{value}")` make the
resolved key depend on runtime data, which defeats code review, weakens static analysis, and can
hide accidental key selection bugs until execution time.

Inline defaults are especially risky in security and lifecycle flows because missing keys can ship
as unreviewed English copy, bypass locale coverage, and make tests pass without proving that the
regional locale files contain the intended text.

## Decision

Application code must not provide user-facing fallback copy with `I18n.t(..., default: "...")` or
equivalent inline defaults.

Application code must also not construct translation keys dynamically at runtime, including string
interpolation, concatenation, or other forms where the final key is not explicit in source.

When code needs a user-facing message, add the translation key to the appropriate locale files under
`config/locales/` for the affected retained surface. The call site should reference the key
directly.

Acceptable:

```ruby
page_title(t("sign.shared.sign_out.unavailable_title"))
```

Not acceptable:

```ruby
page_title(
  t(
    "sign.shared.sign_out.unavailable_title",
    default: "Sign-out is temporarily unavailable.",
  ),
)
```

Not acceptable:

```ruby
t("sign.app.registration.#{step}")
```

## Consequences

Missing translations should fail loudly in development or tests instead of being masked by inline
fallback copy.

Changes that add user-facing strings must update the relevant locale files at the same time as the
code change. Surface-specific keys should remain under the matching retained surface namespace
unless an existing shared translation abstraction explicitly applies.

Translation key references must remain explicit in source so that reviews, grep-based audits, and
locale coverage checks can reliably tell which copy is used.
