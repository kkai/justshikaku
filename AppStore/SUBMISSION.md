# Just Shikaku — App Store submission runbook

State as of 2026-08-14: everything is prepared and in App Store Connect on
build 1; the version sits in `PREPARE_FOR_SUBMISSION`. **The final steps are yours and they are in §1.**

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

## 1. What is left — both yours

- [ ] **App Privacy → "Data Not Collected".** The only field with no public
      API. It is the only answer consistent with `PrivacyInfo.xcprivacy`
      (UserDefaults / CA92.1) and the published privacy policy.
- [ ] **Add the IAP to the version, then press "Add for Review".** On the
      1.0 version page, section "In-App Purchases and Subscriptions", add
      **Shikaku Full** BEFORE submitting. See §2 — this exact omission cost
      Just Kakuro a rejection.
- [ ] Recommended first: install the Release build on a real device and
      play one board (family practice before every submit).
- [ ] Host the web pages: upload `AppStore/index.html` and
      `AppStore/justshikaku-privacy.html` to
      `https://kaikunze.de/justshikaku/` (path is case-sensitive on this
      host). The listing's support/marketing/privacy URLs point there.

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
| Build | 1.0 (1), uploaded, `VALID` (id `289a3006-c305-468a-ad03-fc4fabafb723`), **attached to the 1.0 version** |
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

## 4. Regenerating any of it

```bash
python3 AppStore/capture_screenshots.py     # drives the sim via the app's own save
python3 AppStore/iap/generate.py            # IAP promo + review screenshot
python3 Tools/AppIcon/make_icons.py         # app icon (check at 40pt)
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
`MARKETING_VERSION`. It is **1**.

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
