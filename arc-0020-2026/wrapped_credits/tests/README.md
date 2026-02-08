# JavaScript tests for wrapped_credits

This folder contains a minimal JavaScript test harness for the `wrapped_credits` Leo program.

Goals:
- Provide a `tests/contract.js` abstraction that prefers the Provable SDK when available.
- Provide `wrappedCredits.test.js` as an example test runner that invokes deploy and a few functions.

Quick start
1. Change to the tests folder:

```bash
cd tests
```

2. Install dependencies (optional — only needed if using the Provable SDK):

```bash
npm install
```

3. Run the test harness (your Leo devnode should be running):

```bash
npm test
```

Notes
- The contract abstraction falls back to calling the local `leo` CLI if `@aleo/provable` is not installed.
- To fully use the Provable SDK, install the correct SDK package and replace the stubbed SDK flows in `contract.js`.
