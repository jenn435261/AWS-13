# Decisions Log — Resilience Network overnight run

Every judgement call made during the overnight run (branch `kiro/overnight`) is recorded here with its rationale. Subsequent features append their own decisions below.

## 2026-10-24

### Certificate issuance depth limit = 2

A certificate chain originating from a trusted root may be at most **2 hops deep**. That is, a trusted root may issue to an intermediate authority, and that intermediate may issue to a leaf — but a leaf certificate may not itself act as an issuer beyond that depth.

- Source: spec section 8 open policy question (`docs/SPEC_PROVIDER_AND_FEATURES.md`), pre-specified for this run.
- Rationale: bounds trust propagation so a single compromised intermediate cannot mint arbitrarily long chains; keeps verification cost and the trust surface small for an offline-first network where roots are distributed out of band.
- Applies wherever certificate chains are validated (trust engine / trust roots). Chains deeper than 2 hops from a trusted root are rejected.
