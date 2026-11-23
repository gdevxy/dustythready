# Publishing DustyThready

Players install addons from **CurseForge** (through the CurseForge app) and, more and more, from
**Wago Addons**. Both just want a zip that contains the `DustyThready` folder. Start with CurseForge;
add Wago later if you like.

## 1. Build the zip

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File tools\package.ps1
```

This creates `dist\DustyThready-<version>.zip` (version from `## Version:` in the toc). Open it once
and check it contains a single `DustyThready` folder with `DustyThready.toc` inside.

Pushing a tag (`git tag v1.0.1; git push --follow-tags`) also builds the same zip on GitHub and
attaches it to a GitHub Release (`.github/workflows/release.yml`).

## 2. First release on CurseForge (one time, by hand)

1. Create an account at **https://www.curseforge.com** and open **https://authors.curseforge.com**
   (the author console). Accept the author terms.
2. **Create a project**: Game = *World of Warcraft*, Class = *Addons*.
   - Name: `DustyThready`
   - Summary (one line): *Tailoring + Enchanting, woven together: what to craft next, what it
     disenchants into, where to train, and how to make gold.*
   - Description: paste the *Why* and *Features* sections of the README.
   - Category: *Professions* (add *Auction & Economy* as a secondary one).
   - Logo/avatar: `DustyThready/Media/icon-source.jpg` (CurseForge wants a square image, 400x400 or
     bigger works best, so you may want to upscale it).
   - License: MIT. Source: link your GitHub repository.
3. New projects go through a **moderation review** (usually hours to a couple of days). You can
   upload the first file while it's pending.
4. **Upload a file**: Files → Upload File → pick the zip.
   - Display name: `DustyThready v1.0.0`
   - Release type: *Release* (or *Beta* for the first public test)
   - Game version: tick the **WoW Forever** version that matches Interface **16001**. If you can't
     find a Forever entry, check how another Forever addon you use (Auctionator, Questie) lists its
     files and pick the same game version.
   - Changelog: paste the version's section of `CHANGELOG.md`.
5. Add **screenshots** in the project's *Images* tab (Today, Roadmap, Disenchant). They matter a
   lot for downloads.

## 3. Later releases

Option A (simple): build the zip, upload it by hand as above.

Option B (automatic): let GitHub upload to CurseForge on every tag with the BigWigs packager.

1. In the CurseForge project, note the **Project ID** (right side of the project page).
2. Create an API token: https://authors.curseforge.com/account/api-tokens
3. In GitHub: repository → Settings → Secrets and variables → Actions → New secret
   `CF_API_KEY` = the token.
4. Add `## X-Curse-Project-ID: <your id>` to `DustyThready/DustyThready.toc`.
5. Add a `.pkgmeta` and a packager step to the workflow. Because the addon sits in a subfolder of
   this repository, the simplest is to point the packager at it:

   ```yaml
   - uses: BigWigsMods/packager@v2
     with:
       args: -t DustyThready -o
     env:
       CF_API_KEY: ${{ secrets.CF_API_KEY }}
       GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
   ```

   The packager maps the toc's Interface number to CurseForge game versions. If it does not know
   16001 yet, keep uploading by hand until it does.

## 4. Wago Addons (optional)

https://addons.wago.io → Developers → create the project, upload the same zip. Wago also supports
the BigWigs packager with a `WAGO_API_TOKEN` secret and `## X-Wago-ID:` in the toc.

## Checklist before every release

- [ ] `## Version:` bumped in `DustyThready.toc`, `CHANGELOG.md` updated
- [ ] Manual test checklist in `docs/DEVELOPMENT.md` done, BugSack empty
- [ ] Zip contains one `DustyThready` folder, no `icon-source.jpg`
- [ ] Tag pushed (`git tag vX.Y.Z; git push --follow-tags`)
