# Onboarding motion design

## Approved direction

The first cold launch uses the supplied `Splash Screen.png`, `Splash Screen-1.png`, and `Splash Screen-2.png` as a sequence reference: gold field, Cheetah mark, then the title and `by BocTrust`. Reuse the existing `BocBrandMark` and `CheetahBrand` typography and semantics. The platform launch surface is static and may already show the mark, so Flutter begins with that same mark visible and animates a subtle settle without a disappearance or jump. The existing post-login bootstrap loading and error states stay functional.

The three intro slides use the supplied `Onboarding - 1.png`, `Onboarding - 2.png`, and `Onboarding - 3.png` for layout. Their illustration content is the approved African-inspired revision in `design/onboarding_previews/*-afro-smooth-preview.gif`: contemporary Nigerian characters, natural proportions, clean lines, cream clothing, restrained gold and textile details. The matching `*-afro-smooth-preview.png` files are stills, while `*-afro-master.png` files are the source artwork. The GIFs are 600 × 600, have a `#F6F4EE` background, and loop in 1.92 seconds. Each character and the canvas stay fixed throughout the loop; only small floating motifs move gently. The export is reproducible with `design/onboarding_previews/build_smooth_gifs.py`.

## Splash behavior

- Use `BocColors.goldLight` (`#E5C367`) for the launch field in both themes. Keep the approved blue Cheetah app mark.
- On initial cold launch, keep the mark at the native splash's apparent location and animate a small scale settle (1.0 → 1.04 → 1.0), reveal `Cheetah` after 1,300 ms, then reveal `by BocTrust` after 2,000 ms. Finish by 2,700 ms; if startup work takes longer, keep the final frame visible until routing completes.
- Match the native and Flutter gold fields and mark placement across the handoff. Use navy for splash text to keep it readable on gold.
- Show the existing regulatory copy near the bottom. Reduced-motion mode immediately shows the final composition and does not add an animation delay.
- Do not delay the post-login profile bootstrap, alter its error/retry actions, or change the cold-launch destination decision.

## Carousel behavior

- Render each approved GIF in the upper illustration area on `BocColors.paper` (`#F6F4EE`), with the pale arc background from the supplied screens. Use a white rounded lower panel for heading, description, progress dots, and the navy `PrimaryButton` (`Next` or `Get started`).
- Keep the existing three titles and descriptions in `OnboardingScreen`; the supplied screen text is visual reference, not a product-copy change. Remove the current top Cheetah lockup, Skip action, and regulatory card from the carousel to follow the reference layout.
- Use the 600 × 600 source artwork in a square display box sized to the available viewport, with contain sizing and no clipping. Show its matching still PNG until the GIF's first frame is decoded and if decoding fails. Switching slides restarts the selected GIF; reduced-motion devices show the still PNG only.
- Preserve navigation to sign-in with a visible `I already have an account` action below the primary button, and preserve the current `Get started` destination. Make progress dots accessible tap targets even when their visible marks are small.
- Maintain readable text, reachable controls, and no overflow at 320 px width, large text, and tablet widths. The carousel deliberately stays light in dark mode because its GIF background is baked in.

## Acceptance

Both plans pass focused Flutter widget/configuration tests and a manual iOS/Android review when a simulator or device is available. The review checks the native handoff, delayed title order, reduced motion, illustration scale, smooth GIF loops without character or canvas movement, GIF restart, screen-size behavior, slide navigation, and sign-in access. Report unavailable platform checks as unverified. Copy the approved smooth GIFs and matching stills to production asset names; earlier previews remain review history only. Version the six approved smooth previews and their export script with the plans before using a new worktree.
