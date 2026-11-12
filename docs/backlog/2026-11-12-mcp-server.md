# MCP Server in Sphere (2026-11-12)

Owner: Sphere. Status: decided direction (owner), design open; no implementation yet.

The owner decided on 2026-11-12 that MCP servers live in Press and Sphere, because their resources
are the ones AI clients and the UMAXICA CLI must operate, and that authentication goes through
Access (OAuth authorization server; this repository is an OAuth resource server). The shared design
draft is in Access: `specs/mcp-resource-servers/spec.md`.

This repository owns: its MCP endpoint, its tools (thin adapters over its own Rails services and
Action Policy, read-only first), local token validation (Access JWKS, issuer, its own audience,
expiry, scope), Protected Resource Metadata (RFC 9728) naming Access, audit records and rate limits
for tool calls. App and Org stay separate resources and audiences.

The former `POST /mcp` endpoint was withdrawn (`adr/mcp-endpoint-withdrawal.md`); re-enabling MCP
requires the follow-up ADR that record names (authentication, transport review, tool ownership).
