# ARC-0020 Build & Run Instructions

## Prerequisites

The programs in this directory require a Leo compiler built from the `master` branch, which includes interface support introduced by ARC-0009 (Dynamic Dispatch).

### Build Leo from `master`

```bash
# Clone the Leo compiler
git clone https://github.com/ProvableHQ/leo.git
cd leo

# Build from master (interface support is on master, not yet in a release)
git checkout master
cargo build --release

# Optionally install to PATH
cargo install --path .
# or add ./target/release to PATH:
export PATH="$PWD/target/release:$PATH"
```

Verify the build supports interfaces:

```bash
leo --version
```

## Program Dependency Order

Build programs in this order (dependencies must be built before dependents):

1. **`merkle_tree`** — no external deps
2. **`multisig_core`** — no external deps
3. **`credits`** — no external deps (Leo analog of built-in `credits.aleo`)
4. **`freezelist_program`** — depends on `merkle_tree`, `multisig_core`
5. **`token_registry`** — depends on `credits`
6. **`stablecoin_program`** — depends on `credits`, `token_registry`, `freezelist_program`
7. **`bridge_program`** — depends on `credits`, `token_registry`, `multisig_core`

## Building Programs

From the `arc-0020/` directory:

```bash
cd programs

# Step 1: No-dependency programs
(cd merkle_tree && leo build)
(cd multisig_core && leo build)
(cd credits && leo build)

# Step 2: Programs with simple deps
(cd freezelist_program && leo build)
(cd token_registry && leo build)

# Step 3: Programs with multiple deps
(cd stablecoin_program && leo build)
(cd bridge_program && leo build)
```

Or build all at once (in order):

```bash
cd programs
for prog in merkle_tree multisig_core credits freezelist_program token_registry stablecoin_program bridge_program; do
  echo "Building $prog..."
  (cd "$prog" && leo build) || { echo "FAILED: $prog"; exit 1; }
done
```

## Notes on Adaptation

The programs in this directory were originally written for Leo versions without interface support. When building with Leo from `master`, you may need to adapt:

1. **Interface declarations** — Programs implementing the ARC-0020 token interface will need `implements` annotations (per ARC-0009 syntax).
2. **External program references** — Local dependencies in `program.json` use relative paths. Ensure the path structure matches the layout in `programs/`.
3. **`credits.aleo` vs `credits/`** — The `credits` program here is a Leo analog of the built-in `credits.aleo`. In production, programs will import `credits.aleo` directly from the AVM; the Leo version is provided for local testing and specification purposes only.

## Troubleshooting

- If `leo build` fails with "interface not found", ensure you're using Leo built from `master`.
- If dependency resolution fails, verify the `dependencies` array in each `program.json` uses the correct relative paths matching the `programs/` directory layout.
- The `stablecoin_program` and `bridge_program` are the most complex and may require the most adaptation to the new Leo version.
