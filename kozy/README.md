# KozySupport

KozySupport is [RustDesk](https://github.com/rustdesk/rustdesk) with Kozy Operations' branding and server compiled in. It connects only to `rustdesk.kozyops.com`, and it updates itself from `cdn.kozyops.com`, not from RustDesk.

The source is AGPL-3.0, like upstream. Each release publishes its full patched source as `kozysupport-<version>-source.tar.gz`, next to the installers at `https://cdn.kozyops.com/public/remote-support/releases/<version>/`.

## What differs from upstream

Every change sits on the `kozy` branch, as a few commits on top of the upstream tag named in `kozy/BASE`.

| Change | Where |
|---|---|
| App name, ID server, key and locked server settings are compiled in, replacing RustDesk's signed `custom.txt`. Upstream's custom-client code applies them. | `kozy/custom.json`, `src/kozy.rs`, hook in `common::load_custom_client` |
| The updater reads `cdn.kozyops.com/public/remote-support/latest.json`. It downloads from `.../releases/<version>/` and trusts only our ed25519 update key. | `common.rs` (`do_check_software_update`, `release_id_from_update_url`), `src/updater/artifact.rs`, `src/update_metadata.rs` |
| Auto-update is on by default. It also works on macOS, which upstream disables for custom clients. | `kozy/custom.json`, `src/updater.rs`, `desktop_setting_page.dart` |
| Bundle, package and binary names: `KozySupport.app`, `kozysupport.deb` / `.rpm`, `kozysupport.service`. These are rewritten at build time, not committed. | `kozy/rebrand.py` |

The client can't be pointed at RustDesk's public server, and it ignores a `custom.txt` file.

## Releases

`.github/workflows/kozysupport.yml` runs every day:

1. **plan:** picks the latest upstream release and skips the run if `cdn.kozyops.com` already serves it. It applies this branch's commits onto that tag with `kozy/apply.sh`, or opens an issue if they don't apply cleanly.
2. **bridge, windows, macos, linux:** build the installers. You can download them from the run page to test.
3. **publish:** waits for approval on the `release` environment, then:
   - signs `rustdesk-update.json`
   - uploads everything to `releases/<version>/`
   - updates the stable links (`KozySupport.exe`, `KozySupport-mac-apple-silicon.dmg`, `kozysupport.deb`, `kozysupport.rpm`)
   - rewrites `latest.json` last

**Approving `publish` updates every installed client within a day.** Before you approve, install the build on one Windows machine and one Mac and confirm it connects.

To rebuild after changing this branch, start the workflow by hand with the upstream tag.

### Secrets

| Name | Where | What |
|---|---|---|
| `RUSTDESK_UPDATE_ED25519_SEED` | `release` environment secret | Update signing key. The client has the matching public key compiled in, so losing the seed means a manual reinstall on every machine. Keep the offline copy. |
| `RUSTDESK_UPDATE_ED25519_PUBLIC_KEY` | `release` environment variable | Checked against `src/update_metadata.rs` before signing |
| `MACOS_P12_BASE64`, `MACOS_P12_PASSWORD`, `MACOS_CODESIGN_IDENTITY`, `MACOS_NOTARIZE_JSON` | repository secrets | Developer ID signing and notarization for team `99LNC5NDAJ`. Without them the dmg is built unsigned. |

AWS access is the `kozy-prod-kozysupport-publish` role (`terraform/prod/cdn.tf` in `KozyOps/infrastructure-aws`). Only this repository's `release` environment can assume it.

## When upstream changes

If the scheduled run opens a "Rebase the kozy branch" issue, do this by hand:

```bash
git fetch https://github.com/rustdesk/rustdesk.git tag <new>
git rebase --onto <new> "$(cat kozy/BASE)" kozy
echo <new> > kozy/BASE
git commit -am "kozy: base on <new>"
git push --force-with-lease origin kozy
```

Then start the workflow by hand.

Known limit: a client only updates when the version number goes up. A rebuild of the same upstream version with a kozy-branch fix reaches new installs through the stable links, but installed clients don't pick it up.
