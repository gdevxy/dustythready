# Publishing DustyThready

Releases are driven by **git tags**. Push a tag like `v1.0.1` and:

- **CurseForge** builds the zip from that tag and publishes it (project setting below).
- **GitHub Actions** (`.github/workflows/release.yml`) builds the same zip and attaches it to a
  GitHub Release.

Both follow `.pkgmeta`: the zip has one `DustyThready` folder, without `docs/`, `tools/`,
`README.md`, `CLAUDE.md` or the source artwork. `@project-version@` in the toc becomes the tag name,
and `CHANGELOG.md` becomes the release notes.

## One-time CurseForge setup

1. Account at https://www.curseforge.com, then the author console at https://authors.curseforge.com.
2. **Create project**: World of Warcraft → Addons. Name `DustyThready`, category *Professions*
   (secondary *Auction & Economy*), license MIT, logo `Media/icon-source.jpg`. The summary and
   description are in the section below.
3. **Source** tab of the project:
   - Source host: GitHub, URL `https://github.com/gdevxy/dustythready`
     (the repository must stay **public** for CurseForge to read it).
   - Package name: `DustyThready`
   - **Automatic Packaging**: *The packager will package any new tagged commits it sees when code is pushed.*
4. GitHub has to tell CurseForge when you push. If the Source page shows a **webhook URL**, add it in
   GitHub: repository → Settings → Webhooks → Add webhook, paste the URL, content type
   `application/json`, *Just the push event*. (If CurseForge connects to GitHub for you, skip this.)
5. Images tab: add screenshots of Today, Roadmap and Disenchant.

The webhook is in place (added after v1.0.0). If CurseForge ever misses a tag, any new push to
`main` makes it look again; as a last resort, re-push the tag
(`git push origin :refs/tags/vX.Y.Z` then `git push origin refs/tags/vX.Y.Z`). That also re-runs
the GitHub release workflow, which updates the existing GitHub Release.

New projects go through moderation (hours to a couple of days) before they're public.

### Game version

CurseForge picks the game version from `## Interface: 16001` in the toc. If a packaged file shows
the wrong game version, fix it on the file's page (Files → the file → Edit) and choose the
WoW Forever version.

## Releasing a version

```powershell
git tag v1.0.1
git push origin main --tags
```

Before tagging:

- [ ] Top section of `CHANGELOG.md` is the new version
- [ ] Manual test checklist in `docs/DEVELOPMENT.md` done, BugSack empty
- [ ] Interface number still right for the current client

Tag names decide the release type on CurseForge: `v1.0.1` is a *Release*, `v1.1.0-beta1` a *Beta*,
`v1.1.0-alpha1` an *Alpha*.

To check the zip locally before tagging: `powershell -ExecutionPolicy Bypass -File tools\package.ps1`
(creates `dist\DustyThready-<version>.zip`).

## Project texts

Summary:

> Tailoring + Enchanting, woven together: what to craft next, what it disenchants into, where to train, and how to turn it into gold.

Description (Markdown):

```markdown
## Tailoring + Enchanting, woven together

Tailoring turns the cloth you loot into greens. Enchanting turns those greens into the dust it levels with. **DustyThready** runs that loop for you, based on your skill, bags and level. Five tabs, almost no settings.

- **Today:** your next craft, crafts left, materials you have vs need, and alerts like *Train Expert now*. A **Thread & Dust** card shows how each profession feeds the other.
- **Roadmap:** the full WoW Forever 1-300 path for both professions. One click turns it into an **Auctionator** shopping list.
- **Disenchant:** every green, blue and purple in your bags, with what it turns into and whether it beats the vendor. **One-click disenchant.**
- **Where:** trainers, recipe vendors and cloth drops for your faction and level.
- **Gold:** money ideas for low-budget players, with live profit estimates.

Item tooltips show disenchant results and value. Minimap button included. Type `/dusty` to open.

*Optional: Auctionator for AH prices. Leveling paths follow wow-professions.com's Forever guides.*
```

## Wago Addons (optional)

https://addons.wago.io → Developers → create the project. To publish there from the same tag, add
`## X-Wago-ID: <id>` to the toc and a `WAGO_API_TOKEN` secret in GitHub; the BigWigs packager in the
workflow then uploads to Wago too.
