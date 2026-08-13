# Dependency Policy

Phase 1 uses immutable Git submodule revisions so a clean checkout compiles against the same protocol code.

| Dependency | Revision | Purpose |
| --- | --- | --- |
| `foundry-rs/forge-std` | `8bbcf6e3f8f62f419e5429a0bd89331c85c37824` | Test and script framework |
| `OpenZeppelin/uniswap-hooks` | `e59fe72c110c3862eec9b332530dce49ca506bbb` | Audited-style hook base and v4 template dependency graph |
| `Uniswap/v4-core` | `a7cf038cd568801a79a9b4cf92cd5b52c95c8585` | PoolManager, hook interfaces, types, math, and integration fixtures |

`v4-core` and `v4-periphery` are recursive submodules of `uniswap-hooks`. Their complete resolved revisions are visible
with:

```bash
git submodule status --recursive
```

## Toolchain

- Foundry: `v1.7.1`
- Solidity: `0.8.26`
- EVM target: Cancun
- Optimizer: enabled, 10,000 runs
- Metadata hash and CBOR metadata: disabled for deterministic bytecode

The Solidity version matches the exact pragma used by the pinned v4 PoolManager. CI installs the exact Foundry release
instead of tracking nightly.

## Update procedure

Dependency updates require their own pull request. That change must:

1. Move the submodule pointer and update `foundry.lock` and this file together.
2. Record upstream release notes or relevant commit changes.
3. Run the full Phase 1 verification gate.
4. Regenerate and review the deterministic-test `.gas-snapshot` intentionally.
5. Re-review hook permissions, callback signatures, return-delta semantics, and compiler constraints.

Floating branches, unpinned package installs, and automatic dependency upgrades are not accepted on protocol branches.
