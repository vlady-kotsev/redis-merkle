# redis-merkle

A Redis module, that maintains a SHA-256 Merkle tree over Redis hashes.

Each leaf of the tree is the digest of a Redis hash key. Insert a hash into a tree and you get a
root commitment for the whole set (`MT.ROOT`), plus an inclusion proof for any member
(`MT.PROOFS`), so a third party holding only the root can be convinced that a given record is part
of the set.

The tree lives in its own Redis key as a custom module data type (`mrkeltree`), and is persisted
via RDB.

## Requirements

- Zig `0.16.0` (see `minimum_zig_version` in `build.zig.zon`)

## Build

```sh
zig build
```

## Load

At startup:

```sh
redis-server --loadmodule ./zig-out/lib/libredis-merkle.so.0.1.0
```

Or at runtime, with an absolute path:

```
MODULE LOAD /path/to/zig-out/lib/libredis-merkle.so.0.1.0
```

The module registers itself under the name `MT`; verify with `MODULE LIST`.

## Quick start

```
> HSET user:1 name alice email alice@example.com
(integer) 2
> HSET user:2 name bob email bob@example.com
(integer) 2

> MT.INSERT users user:1
(integer) 1
> MT.INSERT users user:2
(integer) 2

> MT.ROOT users
"C6E5...9A"

> MT.PROOFS users user:1
1) "Right:"
2) "F4B2...31"      # digest of user:2

> MT.DELETE users user:2
(integer) 1
```

## Commands

### `MT.INSERT tree-key hash-key`

Hashes `hash-key` and appends the digest to the tree as a new leaf, then rebuilds the tree.
Creates `tree-key` if it does not exist.

- **Reply:** integer — the number of leaves in the tree after the insert.
- **Reply:** Null if `hash-key` does not exist.
- **Error:** `WRONGTYPE` if `tree-key` is not a `mrkeltree` or `hash-key` is not a hash.

Two things to be aware of: duplicates are not detected, so inserting the same hash twice creates
two identical leaves; and `tree-key` is created before `hash-key` is validated, so a call naming a
nonexistent hash still leaves an empty tree behind (whose `MT.ROOT` is 64 zeros).

### `MT.DELETE tree-key hash-key`

Hashes `hash-key`, removes the first matching leaf, and rebuilds the tree. When the last leaf is
removed, `tree-key` is deleted.

- **Reply:** integer — the number of leaves remaining (`0` when the tree key was deleted).
- **Reply:** Null if `tree-key` or `hash-key` does not exist.
- **Error:** if the digest is not a leaf of the tree.

Removal is by swap, not by shift: the last leaf takes the removed leaf's slot. See
[Notes and limitations](#notes-and-limitations).

### `MT.ROOT tree-key`

- **Reply:** bulk string — the 64-character uppercase hex root hash.
- **Reply:** Null if `tree-key` does not exist.

For a single-leaf tree the root *is* that leaf's digest.

### `MT.PROOFS tree-key hash-key`

Returns the inclusion proof (audit path) for the leaf matching `hash-key`'s digest.

- **Reply:** a flat array of `2 × depth` elements — for each level from the leaf up, a side label
  (`"Left:"` or `"Right:"`) followed by the 64-character uppercase hex sibling hash. An empty array
  means the leaf is the root.
- **Reply:** Null if `tree-key` or `hash-key` does not exist, or if the digest is not in the tree.

The label states which side the **sibling hash** sits on, so verification is:

```python
import hashlib

def verify(leaf_digest: bytes, proof: list[tuple[str, bytes]], root: bytes) -> bool:
    h = leaf_digest
    for side, sibling in proof:            # proof is the reply, paired up
        if side == "Left:":
            h = hashlib.sha256(sibling + h).digest()
        else:
            h = hashlib.sha256(h + sibling).digest()
    return h == root
```

A sibling of 32 zero bytes is the padding used for an odd node at that level, and always appears
as `"Right:"`.

### `MT.HASH hash-key`

Computes the leaf digest of a hash key without touching any tree. Useful for checking what
`MT.INSERT` would store.

- **Reply:** the 64-character uppercase hex digest.
- **Reply:** Null if `hash-key` does not exist.

## How the tree is built

**Leaf digest.** For a Redis hash, every field and value is appended to one buffer in
`RedisModule_ScanKey` iteration order, and the leaf digest is `SHA-256` of that buffer:

```
leaf = SHA256(field₁ ‖ value₁ ‖ field₂ ‖ value₂ ‖ …)
```


## TODO

- [x] `MT.INSERT tree-key hash-key` — hash a Redis hash and append it as a leaf
- [x] `MT.DELETE tree-key hash-key` — remove the matching leaf
- [x] `MT.ROOT tree-key` — return the root hash
- [x] `MT.PROOFS tree-key hash-key` — return the inclusion proof for a leaf
- [x] `MT.HASH hash-key` — return the leaf digest of a hash, without a tree
- [ ] `MT.LEN tree-key` — number of leaves in the tree
- [ ] `MT.TREE tree-key` — render the tree level by level for inspection
- [ ] Tests
- [ ] Efficient tree rebuilding

