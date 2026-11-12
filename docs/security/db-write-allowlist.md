# DB Write Allowlist

## Purpose

Normal `GET` and `HEAD` requests should be read-only unless the write is an explicit lifecycle
exception. This allowlist records the current accepted exceptions so future CI can fail any
unreviewed `INSERT`, `UPDATE`, or `DELETE` observed during read-only request tests.

The database remains the source of truth. JWTs are projections or runtime credentials, not an
authority to invent new state.

## Current Allowlist

| ID  | Classification             | Request phase          | Expected write                                                                              | GET/HEAD lifecycle exception? | Current scope                     |
| --- | -------------------------- | ---------------------- | ------------------------------------------------------------------------------------------- | ----------------------------- | --------------------------------- |
| W16 | OIDC callback              | Protocol callback      | Exchange code, create or update local session/token state, and complete callback lifecycle. | No                            | retained Edit (Org) OIDC callback |
| W18 | Maintenance or repair task | Explicit operator task | Repair, admin, or maintenance writes performed outside ordinary read-only request handling. | No                            | explicitly invoked tasks only     |

Preference writes W8-W11 and social/auth callback writes W17 were removed with the former browser
surfaces on 2026-11-11. Preference models and migrations remain for the next database review, but
this application has no Preference write route. The remaining protocol callback boundary is the Edit
(Org) OIDC callback. Earlier W1-W7 and W14-W15 GET-write entries were removed on 2026-09-25.

W12 and W13, the former App/Org/Com login-time preference adoption writes, were retired on
2026-10-31. Visa APP/ORG now performs one-way explicit-field sign-in reflection and a separate
database-sourced sign-out rebuild through `PreferenceWriteBoundary`. Visa OIDC result GETs validate
the browser binding and result reference, then render a same-origin continuation form. The existing
`Visa::{App,Org}::Oauth::AuthorizationsController#create` POST revalidates and finalizes the result,
then applies the Preference sign-in reflection. GET/HEAD do not finalize authentication or write
Preference state; the POST is the explicit protocol commit boundary, not a read-side exception.

## CI Direction

Future CI should subscribe to SQL and fail `GET`/`HEAD` request tests when `INSERT`, `UPDATE`, or
`DELETE` appears outside this allowlist. A new write path must update this document before the test
allowlist expands.

The allowlist is intentionally behavioral. It does not grant permission to move writes into generic
controller setup, to repair broken JWTs from the database on normal reads, or to introduce hidden
state changes behind read-only routes.
