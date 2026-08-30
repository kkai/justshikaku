# Just Shikaku — App Store submission runbook

State as of 2026-08-30: iOS 1.0 was **rejected under 4.3(a) (Design — Spam)**
on 2026-08-28; the version is `REJECTED` and therefore editable — the
recovery ships as 1.0 **build 3**, no version bump. The full response (the
Lacquered Room redesign, the curriculum daily, mastery/drills/stats made
real, the rewritten listing) is on `main`; the plan lives in
`~/.claude/plans/go-over-it-vast-walrus.md`.

## 0. Resubmission checklist (2026-08-30)

- [x] App rebuilt: dark identity, curriculum daily, drills, mastery, stats
- [x] Listing rewritten from a blank page (`metadata/*` — push via asc.py)
- [x] Screenshots re-captured dark (`screenshots/iphone-65/dark-*`)
- [x] Resolution Center reply drafted: `resolution-reply-draft.md` —
      **Kai reviews and sends; never sent automatically**
- [ ] Archive + upload build 3, attach to the version
- [ ] Push new metadata (description/subtitle/keywords/promo/review notes)
- [ ] Update the IAP display copy in ASC web UI ("The Whole Room")
- [ ] Kai: App Privacy answer (if still pending), IAP into the review
      submission, send the reply, Add for Review

State as of 2026-08-14 (previous submission): everything was prepared in App
Store Connect on build 2; the version sat in `PREPARE_FOR_SUBMISSION`.

## App record facts (matter for every future release)

- ASC App ID **6801529551** · SKU **just-shikaku-01** · bundle `de.kaikunze.shikaku` · team `8H42EZRCCP`
- iOS 1.0 version id `e01190fe-2930-4b9e-b204-74081caac93b`,
  en-US localization `a213842d-5d08-4ada-98e1-db7dd829a1ed`,
  appInfo `cb85b1e9-1c67-4df6-b9e8-83d0070768bc`,
  appInfoLocalization `865ad37e-0942-4b61-aa60-05da5fc4558e`.
- Bundle id registered 2026-08-14 (seed 8H42EZRCCP, universal).
- iPhone-only: one platform version (iOS 1.0). Screenshots are the
  `APP_IPHONE_65` set only — no iPad set is required for an iPhone-only app,
  and `APP_IPHONE_67` uploads are accepted by the API and then never display.
- IAP `de.kaikunze.shikaku.full`, ASC id **6801538467**, $4.99,
  non-consumable, family-shareable, all 175 territories, `READY_TO_SUBMIT`;
  review screenshot `COMPLETE` (2048×2732), promo image healthy.
- `whatsNew` stays empty: it returns 409 on a first version.

## 1. What is left — all of it yours, all of it in the ASC web UI

Everything the API can reach is done and verified (§3). Three things remain,
and two of them are UI-only by Apple's design:

- [ ] **App Privacy → "Data Not Collected".** No public API exists for it
      (re-verified 2026-08-15). It is the only answer consistent with
      `PrivacyInfo.xcprivacy` (UserDefaults / CA92.1) and the published
      policy.
- [ ] **Add "Shikaku Full" to the 1.0 version's "In-App Purchases and
      Subscriptions" section, then "Add for Review" and Submit.** The IAP
      cannot be attached through the API: `reviewSubmissionItems` needs an
      `inAppPurchaseVersions` id, and that id is exposed by no endpoint,
      include, or filter (probed exhaustively; `GET` on a *known* id works,
      so it exists but cannot be discovered). Apple confirms the requirement
      from the other side too: `POST inAppPurchaseSubmissions` returns
      `FIRST_NON_CONSUMABLE_MUST_BE_SUBMITTED_ON_VERSION`. See §2 for why
      this step is not optional.
- [ ] Optional, family practice: install the Release build on a device and
      play a board. Zelos is paired with Developer Mode on, but its tunnel
      would not connect on 2026-08-15 (phone locked or off the network):
      `xcrun devicectl device install app --device CE8780AA-1FCE-52AF-B86D-976DE3BD57FE build/export/Shikaku.ipa`

**An empty review submission `a85832e4-bf0a-4bc5-b08b-020d14bf15ce` exists.**
It was built via API to prove the version passes review-readiness validation
(the app-version item was accepted, then deleted); the API forbids deleting
the submission itself. Adding items in the UI populates it. It was emptied on
purpose: a submission holding only the app version is exactly the shape that
cost Just Kakuro a rejection.

## 2. The thing that cost Just Kakuro a rejection

**The IAP must be an item in the review submission, not merely configured.**
`READY_TO_SUBMIT` means configured and attached to nothing; Kakuro's visionOS
1.0 was rejected under Guideline 2.1(b) in exactly that state.

Recovery if 1.0 is submitted without the IAP: cancel the submission with
`PATCH {canceled: true}`. ASC then creates a replacement submission that
already contains the IAP version (re-adding it returns
`RELATIONSHIP.INVALID.NOT_ALLOWED`); add the app version to that new
submission and submit it.

## 3. What is already done

| | |
|---|---|
| Engine + app tests | full suite green, incl. ReleaseBuildTests (privacy-manifest key spelling, DEBUG-only screenshot unlock, bundle hygiene) |
| Build | 1.0 (2), uploaded, `VALID` (id `788a9519-af0c-4078-adce-0e0d73465ee1`), **attached to the 1.0 version**. Build 1 was superseded by the Lacquered Measure icon |
| IPA inspection | no `.storekit`, no debug dylibs, `PrivacyInfo.xcprivacy` present, `ITSAppUsesNonExemptEncryption` false, `strings` clean of `ShikakuScreenshotUnlock` |
| Screenshots | 10 in ASC, all `COMPLETE`, light set leads. **A set caps at 10** — 12 were captured; dark lesson + learn were dropped. AppShip exits 1 silently at #11, which is how the cap announces itself |
| Metadata | `metadata/`: subtitle 25, promo 155, keywords 86, description ~2.2k chars, review notes |
| IAP art | `iap/shikaku-full.png` 1024² + `iap/review-screenshot-2048x2732.png`, both RGB no alpha |
| Category | Games, subcategories Puzzle and Board |
| Age rating | every question none/false → 4+ |
| Copyright | `2026 Kai Kunze` |
| Price | Free, base territory USA; IAP $4.99 |
| Review contact | Kai Kunze, kai.kunze@gmail.com, +4972544577, no demo account |
| Export compliance | answered by `ITSAppUsesNonExemptEncryption = NO` in the build |
| Content rights | `DOES_NOT_USE_THIRD_PARTY_CONTENT` |
| Availability | all 175 territories, plus new territories automatically |
| Release | `AFTER_APPROVAL` (matches Just Hashi) |
| Demo account | `demoAccountRequired = false` — required before ASC will accept the version into a review submission |
| Privacy policy | URL + full policy text + choices URL on the appInfo localization. ASC rejects the version from review without `privacyPolicyText` |
| Field audit | 23 fields re-read after every write on 2026-08-15: zero failures |

## 4. Regenerating any of it

```bash
python3 AppStore/capture_screenshots.py     # drives the sim via the app's own save
python3 AppStore/iap/generate.py            # IAP promo + review screenshot
python3 Tools/AppIcon/make_icons.py         # app icon (Lacquered Measure; check at 40pt; PHILOSOPHY.md sits beside it)
```

Metadata and screenshots go up through AppShip
(`../appstoreconnect/appship/.build/release/AppShip`), **always with
`--platform IOS`**. Verify uploads through the API, never the exit code:
screenshots carry `assetDeliveryState`, IAP images carry `state`
(`PREPARE_FOR_SUBMISSION` is healthy), builds are real only when
`GET /v1/builds?filter[app]=…` shows `processingState = VALID`.

## 5. Build and upload

```bash
ISSUER=$(grep -E "^[0-9a-f-]{36}$" ../appstoreconnect/credentials.txt)
xcodebuild archive -project Shikaku.xcodeproj -scheme Shikaku -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/JustShikaku.xcarchive \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 \
  -authenticationKeyID <KEY_ID> -authenticationKeyIssuerID "$ISSUER"
xcodebuild -exportArchive -archivePath build/JustShikaku.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates -authenticationKeyPath … -authenticationKeyID … -authenticationKeyIssuerID …
xcrun altool --validate-app -f build/export/Shikaku.ipa -t ios --apiKey <KEY_ID> --apiIssuer "$ISSUER"
xcrun altool --upload-app   -f build/export/Shikaku.ipa -t ios --apiKey <KEY_ID> --apiIssuerID "$ISSUER"
```

The archive signs with the development identity; distribution signing happens
at export via the cloud-managed certificate (there is no distribution cert in
this machine's keychain). Always validate before uploading. Inspect the .ipa
per §3's checklist before either.

`CURRENT_PROJECT_VERSION` must increase for every upload against the same
`MARKETING_VERSION`. It is **2**.

## 6. Traps inherited from the family (all pinned or scripted here)

- Privacy manifest key is `NSPrivacyAccessedAPITypeReasons` — pinned by
  `ReleaseBuildTests.privacyManifestUsesApplesKeyNames`; ITMS-91056 reports
  by email only, ~1h per round trip.
- App Store artwork must have no alpha (ITMS-90717) — both generators save RGB
  and the screenshot driver flattens.
- IAP review screenshot must be 2048×2732; IAP description caps at 55 chars.
- Review contact phone needs `+countrycode` format.
- A failed asc.py PATCH returns `{"HTTP_ERROR": …}` — print raw responses
  when a field does not change.
