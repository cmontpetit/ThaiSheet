# Releasing ThaiSheet

Releases use `release/current.json` as the single source of truth for the public
version, build number, date, and release notes.

## One-time setup

Create an App Store Connect team API key with permission to upload the app and
access Certificates, Identifiers & Profiles. Save these three secrets in the
GitHub `app-store-production` environment:

- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY` (the complete contents of the downloaded
  `AuthKey_….p8` file)

The private key can only be downloaded once. Keep an offline backup; do not add
it to the repository.

The release workflow gives its `GITHUB_TOKEN` `contents: write` permission so it
can push the annotated tag and create the GitHub release. Repository Actions
settings must allow that workflow permission.

## Prepare a release

1. Edit `release/current.json`. Increment the build even when the public version
   changes, and write short user-facing notes.
2. Synchronize every release surface:

   ```bash
   python3 scripts/sync_release_metadata.py
   ```

3. Review and test the generated changes:

   ```bash
   python3 scripts/sync_release_metadata.py --check
   python3 -m unittest discover -s scripts -p 'test_*.py'
   python3 scripts/generate_sound_catalog.py --check
   xcodebuild -project ThaiSheet.xcodeproj -scheme ThaiSheet \
     -destination 'generic/platform=iOS Simulator' build
   ```

4. Commit the release preparation, open a pull request, and merge it to `main`.

## Publish

In GitHub, open **Actions → Release → Run workflow**, select `main`, keep
**Build, sign, and upload to App Store Connect** enabled, and run it.

The workflow:

1. verifies that all release surfaces match `release/current.json`;
2. runs the data checks and iOS tests on Xcode 26;
3. uses the App Store Connect API key for automatic signing;
4. creates and validates a signed `.xcarchive`;
5. retains the archive as a private Actions artifact for 14 days;
6. uploads the build to App Store Connect;
7. creates an annotated `v<version>-build<build>` tag and GitHub release using
   the curated notes.

The website is updated by the release-preparation commit because GitHub Pages
serves `docs/` from `main`.

Apple processes uploaded builds asynchronously. Once processing finishes,
select the build for the App Store version, complete any required compliance or
review answers, test it through TestFlight, and submit it for App Review. Those
approval decisions intentionally remain manual.

If App Store upload succeeded but GitHub release publication failed, rerun the
workflow with **Build, sign, and upload to App Store Connect** disabled. This
avoids attempting to upload the same build number twice.
