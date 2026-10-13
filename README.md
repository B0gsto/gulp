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

Pre-production. No code yet.

- **Next step:** Sprint 0, a one-week spike starting 19 October 2026 that proves the no-avatar character and the Blender-to-Roblox pipeline in Roblox Studio, ending in a go, change or stop decision.
- **Decisions needed first:** weekly hours available, cash budget, acceptance of the reduced soft-launch build, who owns the game on Roblox (a personal account or a group, which is hard to change later), and how the publishing requirement is met. See [chapter 14](docs/14-risks-and-open-questions.md).
- **Schedule:** depends on those hours. [Chapter 13](docs/13-sprint-plan.md) gives dates for 15, 30 and 45 hours a week.

Nothing here has been tested in Roblox Studio yet. Platform facts are marked verified or unverified in each chapter, and chapter 14 collects the unverified ones.
