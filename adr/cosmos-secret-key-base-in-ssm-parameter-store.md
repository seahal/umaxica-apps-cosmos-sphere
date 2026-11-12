# `secret_key_base` in AWS SSM Parameter Store (2026-11-10)

## Status

Accepted (2026-11-10) as direction for production and staging. Implementation follows the deployment
work; development and test keep their current source.

## Context

`secret_key_base` signs and encrypts cookies and other Rails messages, so the Rails process must
hold it in memory. AWS KMS signing (`adr/cosmos-jwt-ps256-and-op-signing-in-aws-kms.md`) keeps a
private key inside KMS and cannot serve this symmetric secret. A stored secret is needed, and it
must be cheap, encrypted at rest, and readable only by the repository's own workload.

## Decision

1. **Production and staging store each repository's `secret_key_base` in AWS Systems Manager
   Parameter Store as a standard-tier `SecureString`,** encrypted with KMS. Each of Access,
   Governance, Press and Sphere has its own parameter; no value is shared between repositories.
2. **Only that repository's workload may read its parameter,** through EKS Pod Identity and an IAM
   policy limited to that parameter and the KMS decrypt it needs. Developers never receive AWS
   access.
3. **The value reaches Rails as the `SECRET_KEY_BASE` environment variable,** delivered by the
   platform (for example External Secrets Operator or the Secrets Store CSI driver), so the
   application needs no AWS SDK for it.
4. **A person creates the value** with a cryptographically secure generator; it never appears in
   logs, documents, chat or git. A missing value stops boot.
5. **Rotation follows `docs/runbooks/secret-key-base-rotation.md`,** updated for this store when
   implemented. Rotation invalidates sessions and signed messages, so it is deliberate, not
   automatic.

## Consequences

- Cost stays low: standard-tier parameters carry no storage charge; KMS key and API usage apply.
- Secrets Manager is not used for this value: its automatic rotation does not fit a secret whose
  rotation must be coordinated with session invalidation.
- Kubernetes Secrets hold the delivered value in the cluster; etcd encryption with KMS must be
  enabled.
- Production does not use Rails encrypted credentials, so there is no production credentials master
  key to store (owner, 2026-11-10).

## Not Decided Here

- The delivery mechanism (External Secrets Operator or Secrets Store CSI driver).
- Sphere regions without AWS.
