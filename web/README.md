# MARKOUT Judge Application

The judge application turns MARKOUT's mechanism and reproducible experiment into one guided browser story. It is a
Cloudflare Worker-compatible React application built with vinext and the Sites Vite plugin.

## Product boundary

- The comparison values come from the committed Phase 6 deterministic experiment.
- The event timeline demonstrates the already-tested local Reactive lifecycle.
- The interface explicitly labels the missing public Lasna proof instead of manufacturing explorer links.
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
