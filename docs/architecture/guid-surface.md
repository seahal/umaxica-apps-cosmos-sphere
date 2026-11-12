# Retired GUID surface

The `guid` HTTP surface was retired on 2026-11-09 under
[Cosmos Press route ownership](../../specs/cosmos-press-route-ownership/spec.md). Sphere no longer
draws its routes or retains its dedicated controllers, view, stylesheet, health profile, host
configuration or surface tests. Former GUID hosts do not resolve resources or provide a
compatibility redirect.

This removes the bootstrap HTTP service, not the identifier contracts used by retained code.
`PublicId.generate`, resource public IDs, protocol identifiers, issued values and persisted data
retain their existing ownership and behavior. See the
[identifier contract](../../adr/identifier-contract.md).

The [GUID ADR](../../adr/guid-identifier-surface.md) preserves the retired design and its unresolved
persistence/resolution questions as history. A future identifier service requires a new decision.
