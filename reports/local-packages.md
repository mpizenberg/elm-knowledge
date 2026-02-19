# Elm Local / Unpublished Packages: Tools & Approaches

This report catalogs all known tools and techniques for using Elm packages
that are **not published** to the official `package.elm-lang.org` registry.
This includes local development of packages, private/internal packages,
patched core packages, and custom package registries.

Last updated: 2026-02-19

---

## Table of Contents

- [Overview](#overview)
- [Active Tools](#active-tools)
  - [zokka-compiler](#zokka-compiler)
  - [elm-wrap](#elm-wrap)
  - [elm-janitor/apply-patches](#elm-janitorapply-patches)
- [Unmaintained Tools](#unmaintained-tools)
  - [elm-git-install](#elm-git-install)
  - [shelm](#shelm)
  - [elm-package-proxy](#elm-package-proxy)
  - [Eco / eco-server](#eco--eco-server)
- [Manual Approaches (No Dedicated Tool)](#manual-approaches-no-dedicated-tool)
  - [source-directories trick](#source-directories-trick)
  - [Git submodules / subtrees + source-directories](#git-submodules--subtrees--source-directories)
  - [Private NPM packages + source-directories](#private-npm-packages--source-directories)
  - [ELM_HOME manipulation](#elm_home-manipulation)
- [Comparison Matrix](#comparison-matrix)

---

## Overview

The Elm compiler hard-codes `package.elm-lang.org` as the sole package registry
and provides no built-in mechanism for local or private packages.
This has led to a long history of community tools and workarounds,
each with different trade-offs.

The approaches fall into four categories:

1. **Compiler forks** that add custom registry / override support (zokka).
2. **Wrapper/proxy tools** that intercept the compiler's network requests (elm-wrap, shelm, elm-package-proxy, eco).
3. **Source-directory injection** tools that clone/link code and add paths to `elm.json` (elm-git-install).
4. **Manual patterns** using standard Git and Elm features (source-directories, submodules, ELM_HOME).

Several earlier tools targeted Elm 0.18 and were never updated for 0.19:
[elm-grove](https://github.com/panosoft/elm-grove) (symlink-based package manager),
[elm-github-install](https://github.com/gdotdesign/elm-github-install) (Ruby-based, supported local dirs and private repos),
[elm-proper-install](https://github.com/eeue56/elm-proper-install),
and [elm-vendor](https://github.com/KevinMGranger/elm-vendor) (never reached a working state).
None of these are usable with current Elm.

---

## Active Tools

### zokka-compiler

|                    |                                             |
| ------------------ | ------------------------------------------- |
| **Repo**           | https://github.com/Zokka-Dev/zokka-compiler |
| **Author**         | changlinli                                  |
| **Language**       | Haskell (fork of the Elm compiler)          |
| **Latest release** | 0.191.0-beta.0 (May 2024)                   |
| **Commits**        | Active as of Jan 2026                       |
| **Stars**          | ~105                                        |
| **License**        | BSD-3-Clause                                |
| **Install**        | `npx zokka` or binary from GitHub releases  |

A conservative fork of the Elm 0.19.1 compiler.
Zokka commits to **bidirectional compatibility** with Elm 0.19.1 through end of 2026:
any code that compiles with `elm` compiles with `zokka`, and vice versa.
It is a drop-in replacement (`zokka make`, `zokka install`, etc.).

**Local/private package features:**

- **Custom package repositories** configured in `$ELM_HOME/0.19.1/zokka/custom-package-repository-config.json`.
  Three repository types are supported:
  1. Standard Elm package server API (any compatible server).
  2. Zokka-specific custom server with API token auth
     (source: [zokka-custom-package-server](https://github.com/Zokka-Dev/zokka-custom-package-server);
     hosted instance at `zokka-custom-repos.igneousworkshop.com`).
  3. Local directory of packages (read-only mirror, for offline use).

- **Single-package locations** for one-off packages:
  point to a zipfile URL with a SHA-1 hash, no server needed.

- **Dependency overrides** via a `zokka-package-overrides` field in `elm.json`:

  ```json
  {
    "zokka-package-overrides": [
      {
        "original-package-name": "elm/core",
        "original-package-version": "1.0.5",
        "override-package-name": "zokka/elm-core-1-0-override",
        "override-package-version": "1.0.0"
      }
    ]
  }
  ```

  Overrides must be API-identical to the original package.
  This is the mechanism for applying bug fixes to `elm/core`, `elm/json`, etc.

- **Publishing** with `zokka publish <url>` targets a specific custom repository.
  Publishing to `package.elm-lang.org` is hard-coded to be disallowed
  (to prevent publishing code that relies on compiler bugfixes absent in upstream elm).

**Bug fixes included:**
Zokka merges community-reported Elm compiler bugs, notably several TCO (tail call optimization)
corner cases. Override packages for `elm/core`, `elm/json`, `elm/random`, `elm/parser` are
published by the Zokka-Dev organization.

**Maturity:**
Still in beta after ~2 years. 12 releases total (all pre-releases).
Single primary developer (changlinli, 234 commits).
Active recent commits (Jan 2026) around publishing fixes and local mirrors.
Ecosystem repos (custom package server, elm-mirror-server) are also maintained.

**Known issues:**

- `elm bump` may delete Zokka-specific fields from `elm.json` (issue #15).
- `elm-reactor` has an undiagnosed CI failure (issue #4).
- IDE tools do not understand `zokka-package-overrides` for click-to-definition.
- The TCO fix introduces one extra function call per loop iteration (no ES6 `let`).

---

### elm-wrap

|                    |                                                                               |
| ------------------ | ----------------------------------------------------------------------------- |
| **Website**        | https://elm-wrap.dev/                                                         |
| **Repo**           | https://github.com/dsimunic/elm-wrap                                          |
| **Author**         | Damir Simunic (dsimunic)                                                      |
| **Language**       | C                                                                             |
| **Latest release** | 0.6.1 (Jan 2026)                                                              |
| **Commits**        | 250+ (last: Feb 2026)                                                         |
| **Stars**          | ~18                                                                           |
| **License**        | BSD-3-Clause (free, open source)                                              |
| **Install**        | `brew tap dsimunic/elm-wrap && brew install elm-wrap` or binary from releases |

A CLI wrapper around the standard Elm compiler.
You type `wrap make src/Main.elm` instead of `elm make src/Main.elm`.
elm-wrap runs `elm` as a subprocess but intercepts all package-related operations.
It resolves dependencies with its own PubGrub solver,
populates `ELM_HOME`, then forces the compiler offline
(by injecting `https_proxy=http://1` into the subprocess environment)
so the compiler uses only what elm-wrap has prepared.

No compiler fork needed; works with the unmodified Elm binary (and Lamdera via `WRAP_ELM_COMPILER_PATH`).

**Local package development:**

```bash
wrap package install me/mypackage --local-dev --from-path ../../mypackage-src
```

This creates a symlink in `ELM_HOME` so the compiler believes the package is cached,
but it actually reads from your local directory.
Symlinks are repaired on every `wrap make` and `wrap install`.
No `source-directories` editing, no risk of shipping private paths.

**Other features:**

- Install packages from GitHub URLs (`--from-url`).
- Custom registry URL via `ELM_PACKAGE_REGISTRY_URL` env var.
- Fully offline mode (`WRAP_OFFLINE_MODE`).
- `cache download-all` can mirror all packages from GitHub.
- Package publishing (`wrap package publish`, v0.6.0+).
- Blacklist file (`WRAP_HOME/blacklist.txt`) to skip specific packages.

**Roadmap (not yet implemented):**

- v0.7.0: Private repositories (local storage, private publishing).
- v0.9.0: Multi-level repositories (team/org registries, hierarchical).
- v1.3.0+: Hosted services, enterprise features.

**Maturity:**
Very young project (created Nov 2025, ~3 months old).
Rapid release cadence: 11 releases in 6 weeks.
Single primary developer (250/254 commits).
Minor contributions from well-known Elm community members (jfmengels, miniBill, rupertlssmith).

**Limitations:**

- macOS ARM64 and Linux only (no Windows, no macOS Intel).
- Pre-1.0, many planned features not yet implemented.
- Solo maintainer risk.
- The proxy trick could theoretically interact with corporate proxy environments.
- Written in C (harder for typical Elm developers to contribute).

---

### elm-janitor/apply-patches

|                    |                                              |
| ------------------ | -------------------------------------------- |
| **Repo**           | https://github.com/elm-janitor/apply-patches |
| **Manifesto**      | https://github.com/elm-janitor/manifesto     |
| **Latest release** | 1.0.0 (Mar 2025)                             |
| **Install**        | Deno script or Node.js CLI                   |

A script that replaces official Elm core packages in `ELM_HOME`
with community-maintained patched versions from elm-janitor forks.
Not a general-purpose local package tool, but specifically targets
patching `elm/core`, `elm/json`, `elm/parser`, etc.

```bash
elm-janitor-apply-patches --all
# or specific packages:
elm-janitor-apply-patches parser json
```

Requires deleting `elm-stuff` afterward to clear cached compiled artifacts.
Patches are applied on top of the latest official release.
An `elm-janitor-commit.json` file tracks applied patches.

Actively maintained. Self-described as a "hacky script"
intended as a temporary solution. Compatible with zokka's override packages.

**Blog post:** [Using patched Elm core packages vetted by elm-janitor](https://marc136.de/posts/2023-05-23_elm-janitor-apply-patches/)

---

## Unmaintained Tools

### elm-git-install

|                            |                                                   |
| -------------------------- | ------------------------------------------------- |
| **Repo**                   | https://github.com/robinheghan/elm-git-install    |
| **Author**                 | Robin Heggelund Hansen (now focused on Gren)      |
| **Language**               | Node.js                                           |
| **Latest version**         | 0.1.4 (npm)                                       |
| **Last meaningful commit** | Mar 2022                                          |
| **Stars**                  | ~121                                              |
| **Status**                 | Self-described "alpha". Effectively unmaintained. |

Installs Elm packages from any git remote (GitHub, GitLab, private servers).
Clones repos into `elm-stuff/` and adds their `src/` to `source-directories` in `elm.json`.

**Configuration (`elm-git.json`):**

```json
{
  "git-dependencies": {
    "direct": {
      "git@github.com:user/repo.git": "1.0.0"
    },
    "indirect": {}
  }
}
```

Supports semver-formatted git tags, SHAs, and version ranges for packages.
Branches are explicitly not supported (moving targets).

**Limitations:**

- Source-directory injection, not real packages (no native dependency resolution).
- Cannot run in package context (Elm only allows `source-directories` in applications).
- Modifies `elm.json` (potential merge conflicts).
- No lockfile mechanism.
- 14 forks exist, none have become active successors.

---

### shelm

|                   |                                 |
| ----------------- | ------------------------------- |
| **Repo**          | https://github.com/robx/shelm   |
| **Language**      | Bash                            |
| **Last activity** | 2019                            |
| **Status**        | Proof-of-concept, unmaintained. |

A bash-script package manager that maintains its own `registry.dat`
in a local `elm-stuff/home/.elm`, redirects `$HOME`, and blocks networking
via an invalid `$HTTP_PROXY`. Supports unpublished packages and kernel code.
Self-described: "works for me, might eat your files."

**Blog post:** [Subverting Elm packaging for fun and profit](https://vllmrt.net/spam/subverting-elm.html)

---

### elm-package-proxy

|              |                                                     |
| ------------ | --------------------------------------------------- |
| **Repo**     | https://github.com/MichaelCombs28/elm-package-proxy |
| **Language** | Go                                                  |
| **Created**  | May 2021                                            |
| **Commits**  | 7                                                   |
| **Status**   | Not production ready.                               |

A Go-based HTTPS MITM proxy that intercepts Elm compiler requests to `package.elm-lang.org`.
Supports uploading private packages via ZIP files. Requires SSL certificate setup.
Many TODOs in docs; no releases published.

---

### Eco / eco-server

|               |                                                                                                 |
| ------------- | ----------------------------------------------------------------------------------------------- |
| **Spec**      | [Gist by rupertlssmith](https://gist.github.com/rupertlssmith/d0671157ca30d272970de00864512236) |
| **Discourse** | [Private Package Tool Spec](https://discourse.elm-lang.org/t/private-package-tool-spec/6779)    |
| **Status**    | Prototype only.                                                                                 |

A proposed alternative package server implementing the same HTTP API as `package.elm-lang.org`,
with upstream mirroring, private packages, quality screening on upload, and multi-level caching.
Required `mitmdump` (mitmproxy) to redirect compiler traffic.
A live mirror ran briefly at `https://package.eco-elm.org/v1/` on minimal AWS infrastructure.

---

## Manual Approaches (No Dedicated Tool)

### source-directories trick

Add the local package's `src/` to the consuming application's `elm.json`:

```json
{
  "type": "application",
  "source-directories": ["src", "../my-local-package/src"]
}
```

**Caveats:**

- Must manually add all transitive dependencies of the package to the application's `elm.json`.
- Only works in applications (`"type": "application"`), not packages.
- Must clean up before committing/publishing.
- No version resolution or constraint checking.

**This is the simplest approach and often sufficient for local development.**

---

### Git submodules / subtrees + source-directories

Use Git's built-in mechanisms to embed external repos, then reference via source-directories.

```bash
# Submodule approach:
git submodule add <url> lib/my-package

# Subtree approach (preferred -- no special init/update for collaborators):
git subtree add --prefix=lib/my-package <url> main
```

Then add `lib/my-package/src` to `source-directories`.

Evan Czaplicki recommended git subtrees in the
[About Private Packages](https://discourse.elm-lang.org/t/about-private-packages/1872) Discourse thread.
He also suggested a `multi-repo.json` + setup script pattern for companies.

---

### Private NPM packages + source-directories

Distribute private Elm code via a private npm registry
(npm Enterprise, Verdaccio, GitHub Packages, etc.):

```bash
npm install @company/elm-shared
```

Then add `node_modules/@company/elm-shared/src` to `source-directories`.
In use by some companies. Same caveats as the basic source-directories trick
(manual transitive dependency management).

---

### ELM_HOME manipulation

Set `ELM_HOME` to a project-local directory and manually place package source
into the cache structure (`$ELM_HOME/0.19.1/packages/author/package/version/`).
This is what `elm-safe-virtual-dom` uses for kernel patches.

**Fragile and not recommended for general use.**
The cache structure is undocumented and may change.

---

## Comparison Matrix

| Tool                          | Mechanism                    | Maintained      | Local Dev                   | Private Registry     | No Compiler Fork |
| ----------------------------- | ---------------------------- | --------------- | --------------------------- | -------------------- | ---------------- |
| **zokka**                     | Compiler fork                | Yes (beta)      | Yes (overrides, single-pkg) | Yes (custom servers) | No               |
| **elm-wrap**                  | Proxy/wrapper                | Yes (pre-1.0)   | Yes (symlinks)              | Partial (custom URL) | Yes              |
| **elm-janitor**               | ELM_HOME patching            | Yes (v1.0.0)    | No (patches only)           | No                   | Yes              |
| **elm-git-install**           | source-dirs injection        | No (since 2022) | Partial (git repos)         | No                   | Yes              |
| **shelm**                     | HOME redirect + registry.dat | No (since 2019) | Yes                         | No                   | Yes              |
| **elm-package-proxy**         | HTTPS MITM proxy             | No              | Yes                         | Yes                  | Yes              |
| **Eco**                       | Alt server + mitmdump        | No (prototype)  | Yes                         | Yes                  | Yes              |
| **source-directories**        | Manual elm.json edit         | N/A (pattern)   | Yes                         | N/A                  | Yes              |
| **Git sub{module,tree}**      | Git + source-dirs            | N/A (pattern)   | Yes                         | N/A                  | Yes              |
| **NPM private + source-dirs** | npm + source-dirs            | N/A (pattern)   | Yes                         | Via npm              | Yes              |
| **ELM_HOME manipulation**     | Manual cache injection       | N/A (pattern)   | Yes                         | N/A                  | Yes              |

### Recommendations by Use Case

**Developing a package locally alongside an app:**

- Simplest: [source-directories trick](#source-directories-trick)
- Cleaner: [elm-wrap `--local-dev`](#elm-wrap) (if on macOS ARM64 or Linux)

**Private packages within a company:**

- Most mature: [zokka custom repositories](#zokka-compiler)
- Lightest weight: [Git subtrees + source-directories](#git-submodules--subtrees--source-directories)
- npm-familiar: [Private NPM + source-directories](#private-npm-packages--source-directories)

**Patching elm/core or other core packages:**

- Recommended: [elm-janitor/apply-patches](#elm-janitorapply-patches) or [zokka overrides](#zokka-compiler)

**Offline / air-gapped builds:**

- [zokka local directory mirror](#zokka-compiler) or [elm-wrap offline mode](#elm-wrap) or [vendoring into version control](#elm_home-manipulation)
