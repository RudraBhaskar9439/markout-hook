# MARKOUT Judge Application

The judge application turns MARKOUT's mechanism and reproducible experiment into one guided browser story. It is a
Cloudflare Worker-compatible React application built with vinext and the Sites Vite plugin.

## Product boundary

- The comparison values come from the committed Phase 6 deterministic experiment.
- The event timeline demonstrates the tested outcome-to-settlement lifecycle without simulating live network state.
- The interface links the public Pyth publication, Circle settlement, and claimed rebate from the dated manifest.
- The public evidence contrasts both allocation extremes: 100% rebated after negative markout and 100% retained for LP
  protection after positive markout.
- Reactive remains visibly optional and is not labeled live without a public destination callback.
- There is no wallet, persistent database, authentication surface, upload surface, or secret in this application.

## Local use

```bash
npm ci
npm run dev
```

Open `http://localhost:3000`, select each flow class, and replay the five-step autonomous lifecycle.

## Verification

```bash
npm run verify
```

The gate lints the TypeScript application, builds the Cloudflare-compatible output, verifies server-rendered product
content and starter removal, and rejects high-severity production dependency advisories.

The development-only vinext tool currently inherits two `image-size` parser advisories. MARKOUT has no image upload or
untrusted image-processing path; the package is excluded from the deployed dependency audit and is used only to compile
repository-owned assets. See `../docs/PHASE_8_VERIFICATION.md` for the exact boundary.
