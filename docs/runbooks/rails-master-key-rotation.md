# Rails Master Key Rotation

## Scope and trigger

This runbook rotates the key that decrypts `config/credentials/<environment>.yml.enc` without a boot
outage. It uses only what Rails already provides: `RAILS_MASTER_KEY` accepts several comma-separated
keys, the first is the primary key and every key is tried for decryption.

Run it on a scheduled rotation, when a person holding the key leaves, or when the key is suspected
to be disclosed (see [Emergency rotation](#emergency-rotation)).

Out of scope: the values inside the credentials file. Rotating the master key does not rotate any
API key, signing key or password stored in the file; rotate those through their own runbooks (for
example [JWT key rotation](jwt-key-rotation.md)). Per-role credentials bundles are deferred by
`adr/runtime-secret-isolation-deferred.md`.

## Prerequisites and owners

- Write access to the secret store that delivers `RAILS_MASTER_KEY` to the deployed environment, and
  to the GitHub Actions `RAILS_MASTER_KEY` secret when the rotated environment is `test`. How the
  production key is delivered is not recorded in this repository; confirm it with the secret owner
  before starting.
- The current key for the environment, obtained as described in
  `docs/operations/development-credential-provisioning.md`. Never paste a key into a tracked file,
  an issue, a chat or a shell history that is kept.
- A list of every release that may be rolled back to during the rotation window.

Key resolution order, observed on Rails `8.2.0.alpha` (`activesupport` `encrypted_file.rb`):

- `RAILS_MASTER_KEY`, when set and non-blank, is the only source. `config/credentials/<env>.key` is
  not consulted, even if the environment variable keys fail.
- Otherwise `config/credentials/<env>.key` is read.

## Procedure

Write `OLD` for the current key and `NEW` for the replacement. Placeholders only; never record the
values.

### 1. Generate the new key

```bash
bundle exec ruby -ractive_support -ractive_support/encrypted_file \
  -e 'puts ActiveSupport::EncryptedFile.generate_key'
```

Do not use `bin/rails credentials:edit` to create it: that command writes a fresh key file and an
empty credentials file when none exist.

Store the key in these places, and nowhere else:

| Holder                          | Location                                                                                                                               | When                            |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| Deployed environment            | The secret store that delivers `RAILS_MASTER_KEY`, as a new version; keep `OLD` as an enabled version                                  | Step 1                          |
| CI (`test` environment only)    | GitHub Actions secret `RAILS_MASTER_KEY`                                                                                               | Step 2 value, then step 5 value |
| People who edit the credentials | `config/credentials/<environment>.key`, mode `600`, delivered as described in `docs/operations/development-credential-provisioning.md` | After step 3                    |

The key file is ignored by Git (`/config/credentials/*.key`). Never commit it, and never put it in
an image layer.

### 2. Deploy both keys

Set `RAILS_MASTER_KEY` to `NEW,OLD` on every node and restart. Both the current credentials file
(encrypted with `OLD`) and the one produced in step 3 (encrypted with `NEW`) now decrypt.

How Rails reads the list: it splits the value on `,`, uses the first element as the primary key and
registers the remaining elements, in order, as older keys that are tried when the primary key fails
to decrypt. For reading, the order does not change the result (`OLD,NEW` also decrypts both files).
Put `NEW` first anyway: the first element is the key the file is meant to be encrypted with, and
listing the current key first keeps the value unambiguous for the next operator. List at most the
two keys of one rotation; remove keys from earlier rotations.

Format rules, each observed to break boot when violated:

- No spaces around the comma (`NEW, OLD` fails).
- No line break inside the value; check what the secret store's paste field stores.
- No empty element at the front (`,OLD` fails). A trailing comma is tolerated but avoid it.
- Every element must be a 32-character hex key. A malformed first element fails boot even when a
  later element is correct.

Do not continue until every node runs with `NEW,OLD`. A node still running with `OLD` alone fails to
boot once it receives the release from step 3.

### 3. Re-encrypt the credentials file with the new key

On a trusted workstation, from the repository root. The plaintext never touches disk.

```bash
read -rs REKEY_OLD_KEY && read -rs REKEY_NEW_KEY && export REKEY_OLD_KEY REKEY_NEW_KEY
bundle exec ruby -ractive_support -ractive_support/encrypted_file -e '
  path = ARGV.fetch(0)
  file = ->(key) {
    ENV["REKEY_KEY"] = key
    ActiveSupport::EncryptedFile.new(content_path: path, key_path: "/nonexistent",
                                     env_key: "REKEY_KEY", raise_if_missing_key: true)
  }
  plain = file.(ENV.fetch("REKEY_OLD_KEY")).read
  file.(ENV.fetch("REKEY_NEW_KEY")).write(plain)
  abort "verification failed" unless file.(ENV.fetch("REKEY_NEW_KEY")).read == plain
  puts "re-encrypted"
' config/credentials/<environment>.yml.enc
unset REKEY_OLD_KEY REKEY_NEW_KEY
```

Re-encryption must use a single key. Writing while `RAILS_MASTER_KEY` holds several keys raises
`ActiveSupport::EncryptedFile::InvalidKeyLengthError`; this also applies to
`bin/rails credentials:edit`.

Replace the local `config/credentials/<environment>.key` with `NEW` for the people who hold it.
Commit the re-encrypted file and deploy it as a normal release.

### 4. Wait out the rollback window

Every release that may still be rolled back to must contain the file encrypted with `NEW`. A release
that predates step 3 needs `OLD` and fails to boot after step 5.

### 5. Retire the old key

Set `RAILS_MASTER_KEY` to `NEW` alone on every node and restart. Disable the `OLD` version in the
secret store. Rollback past the step 3 release is no longer possible without restoring `OLD`.

## Verification

After each step, on one node (or locally with the same key value):

```bash
bin/rails credentials:show --environment <environment> > /dev/null && echo ok
```

- Step 2: `ok` with `NEW,OLD`.
- Step 3: `ok` with `NEW` alone and a failure (`ActiveSupport::MessageEncryptor::InvalidMessage`)
  with `OLD` alone against the new file.
- Step 5: application boot succeeds on every node.

## Rollback or recovery

| Point of failure                         | Recovery                                                      |
| ---------------------------------------- | ------------------------------------------------------------- |
| Boot fails after step 2                  | Check the format rules; set `RAILS_MASTER_KEY` back to `OLD`  |
| Step 3 release must be rolled back       | Safe while `NEW,OLD` is deployed                              |
| Old release needed after step 5          | Redeploy `NEW,OLD`; requires `OLD` still present in the store |
| `OLD` destroyed and old release required | Not recoverable; the old file can no longer be decrypted      |

Destroying `OLD` in the secret store is irreversible. Do it only after the rollback window has
closed.

## Emergency rotation

When `OLD` is suspected to be disclosed, run steps 1 to 5 back to back and treat every secret inside
the credentials file as disclosed: rotate each one through its own procedure. Re-encryption stops
`OLD` from decrypting the new file, but every earlier copy of the file in Git history and in old
images still decrypts with `OLD`.

## Basis

Observed in a disposable directory on 2026-11-08 at HEAD `308af3589fb2877f77ca65af63c85ed5744db5cc`
with Rails `8.2.0.alpha` (`rails-9ba8b1edeeac`); the uncommitted worktree changes touch tests only
and did not affect the result. Production delivery and multi-node rollout were not exercised.
