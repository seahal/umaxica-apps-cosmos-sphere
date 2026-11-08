# GitHub Actions `RAILS_MASTER_KEY` must follow the 2026-11-08 master key rotation

Status: Deferred; recorded at the owner's request on 2026-11-08. Key rotation in CI is mandatory.
The owner instructs when the GitHub secret is changed; no GitHub write is authorized by this entry.

## Background

On 2026-11-08 the four Cosmos repositories (`umaxica-apps-cosmos-identity`, `-global`, `-regional`,
`-press`) stopped sharing credentials keys. They had been created by copying one working tree, so
every repository held the same master keys, and `development` and `production` shared one key.

- Every `config/credentials/<environment>.key` was replaced: twelve distinct keys, one per
  repository and environment. Each `<environment>.yml.enc` was re-encrypted with its new key, with
  its content unchanged. Verified locally: each key opens only its own file.
- `SECRET_KEY_BASE` was removed from all credentials files, and JWT signing keys were removed from
  development and test credentials; development and test use a distinct `tmp/local_secret.txt` per
  repository.

## Required action

In `seahal/umaxica-apps-cosmos-regional`, set the GitHub Actions secret `RAILS_MASTER_KEY` to this
repository's current `config/credentials/test.key`. Today this repository has no `RAILS_MASTER_KEY`
secret.

Until then, CI steps that read test credentials fail. Use this repository's key only; a key from
another Cosmos repository does not decrypt this repository's file.

Follow `docs/runbooks/rails-master-key-rotation.md` for key handling. Never paste the key into a
tracked file, issue, chat or retained shell history.

## Related follow-up

- Production credentials were then removed from this repository:
  `config/credentials/production.yml.enc` and its key were deleted, and the repository handles
  development and test credentials only. A deployed environment must receive every secret, including
  `SECRET_KEY_BASE`, from its own secret store.
- Earlier copies of the credentials files in Git history still decrypt with the previous keys, and
  the values inside (JWT signing keys, HMAC salts, provider secrets) are still identical across the
  four repositories. Rotating those values per repository is separate work; until it is done, the
  previous keys must be treated as able to reveal current secrets and destroyed once no longer
  needed.
