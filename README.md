# GULP

**Eat. Grow. Get home.**

GULP is a Roblox game where you are never a Roblox avatar. You are a tiny sea creature: eat what is smaller, flee what is bigger, become what you eat, and get home to your cove before something gulps you.

This repository currently holds the design bible. Code and art will be added as the sprints in [`docs/13-sprint-plan.md`](docs/13-sprint-plan.md) are worked through.

## The design bible

Start with the canon. Every other chapter expands one part of it, and the canon wins any disagreement.

| # | Chapter | What it answers |
|---|---|---|
| 01 | [Game canon](docs/01-game-canon.md) | What the game is: name, pillars, loops, rules, species, traits, events, currencies, scope |
| 02 | [Mechanics](docs/02-mechanics.md) | Exactly how every system behaves, with edge cases |
| 03 | [Content catalog](docs/03-content-catalog.md) | Every species, prey, predator, trait, zone, event, goal, badge and decoration |
| 04 | [First two minutes](docs/04-first-two-minutes.md) | The scripted first-time experience, second by second |
| 05 | [Economy and monetization](docs/05-economy-and-monetization.md) | Every price and balance number, the 30-day progression model, how the game earns |
| 06 | [Art bible](docs/06-art-bible.md) | The visual and animation style, with references, palettes and budgets |
| 07 | [Asset list](docs/07-asset-list.md) | Every model, texture, animation, effect, sound and music track to produce |
| 08 | [Interface](docs/08-ui-ux.md) | Every screen, element, image and text string |
| 09 | [Technical architecture](docs/09-technical-architecture.md) | Toolchain, code structure, networking, saves, security, performance |
| 10 | [Analytics and funnels](docs/10-analytics-and-funnels.md) | Every funnel and event, the measures we track and how we decide |
| 11 | [Store page and marketing](docs/11-store-page-and-marketing.md) | Name, icon, thumbnails, trailer, page text, marketing plan |
| 12 | [Launch, live operations and compliance](docs/12-launch-liveops-and-compliance.md) | Release stages, update calendar, policy checklist, costs |
| 13 | [Sprint plan](docs/13-sprint-plan.md) | The build, sprint by sprint, with tasks and acceptance criteria |
| 14 | [Risks and open questions](docs/14-risks-and-open-questions.md) | What could go wrong, what is still unverified, and decisions still to make |
| 15 | [Platforms](docs/15-platforms.md) | How the game looks, controls and performs on phone, tablet, PC, console and every other device Roblox supports |

Background research that led to this concept is in [`docs/research/`](docs/research/).

## How to use these documents

- **Changing a rule, name or number:** change it in the canon first, then in the chapter that owns the detail.
- **Prices and balance numbers** live in chapter 05 only. Other chapters refer to it.
- **Scope tags** mark when something ships: `[MVP]` the core game (soft launch starts with a smaller slice of it), `[L]` public launch, `[P1]` first quarter after launch, `[P2]` later.
- **`(tune)`** marks a starting value we expect to change from playtest data.
- **If it is not in the asset list or the interface image list, it does not get built.** Add it there first.

## Status

Pre-production. The repository scaffold, the headless gate and CI are in place (sprint tasks S1-C1 to S1-C3); there is no game code yet.

- **Next step:** Sprint 0, a one-week spike starting 19 October 2026 that proves the no-avatar character and the Blender-to-Roblox pipeline in Roblox Studio, ending in a go, change or stop decision.
- **Decisions needed first:** weekly hours available, cash budget, acceptance of the reduced soft-launch build, who owns the game on Roblox (a personal account or a group, which is hard to change later), and how the publishing requirement is met. See [chapter 14](docs/14-risks-and-open-questions.md).
- **Schedule:** depends on those hours. [Chapter 13](docs/13-sprint-plan.md) gives dates for 15, 30 and 45 hours a week.

Nothing here has been tested in Roblox Studio yet. Platform facts are marked verified or unverified in each chapter, and chapter 14 collects the unverified ones.

## Development

The toolchain is pinned in `rokit.toml` ([chapter 09](docs/09-technical-architecture.md), section 2). Install it once, then run the headless gate before every commit:

```sh
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
fish_add_path -p ~/.rokit/bin     # Rokit's shims must come first in PATH
rokit install                     # Rojo, Wally, luau-lsp, Selene, StyLua, Lune

lune run tools/check              # the gate: lint, types, gen, unit, sim, build
lune run tools/check -- unit      # one step (or several: -- lint types)
```

The gate needs no Studio. It stops at the first failing step and exits non-zero. `rojo serve default.project.json` syncs `src/` into the world place in Studio.

### CI/CD

GitHub Actions on `B0gsto/gulp`:

| Trigger | Workflow | What runs |
|---|---|---|
| Pull request; push to `main`; Actions > CI > **Run workflow** | `ci.yml` (CI) | One job per gate step: `lint`, `types`, `gen`, `unit`, `sim`, `build`. `build` uploads `build/ci.rbxl` as artifact `ci-place-<sha>` (14 days). A newer push to a pull request cancels its running check. |
| The same, on `main` only, after those jobs pass | `ci.yml`, job `engine` | `tools/cloud/publish_ci` publishes `build/ci.rbxl` to the GULP CI place through Open Cloud, then `tools/cloud/run_engine_tests` runs `Tests/RunAll` there. One at a time. |
| CI finished green for a pull request | `automerge.yml` (Auto-merge) | Merges the PR into `main` with a merge commit (`Merge pull request #N: <title>`) and dispatches CI on `main`, because a merge made by the Actions token does not fire the push trigger. Leaves drafts, PRs with conflicts, PRs not based on `main`, PRs from forks and PRs whose head moved on since the checked commit. |

- Every pull request merges itself once CI is green. To hold one back, open it as a draft.
- **The world place is never published by CI.** It is published by hand from Studio (chapter 09, section 17.2); Open Cloud publishing is for the CI place only.
- The GULP CI experience does not exist yet: `tools/cloud/target.json` holds `0` for both IDs, and until they are filled in the `engine` job prints "GULP CI place not configured yet" and passes.

### The one secret

```sh
gh secret set ROBLOX_API_KEY --repo B0gsto/gulp < ~/RobloxProjects/.roblox-api-key
```

The key needs `universe-places` write and `universe.place.luau-execution-session:write` on the GULP CI experience. It reaches only the two Open Cloud steps of the `engine` job, as the environment variable `ROBLOX_API_KEY`; the tools never print it. Without the secret the `engine` job fails with "Repository secret ROBLOX_API_KEY is not set"; the other jobs do not need it.
