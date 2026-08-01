# Contributing

Thanks for taking the time. This document is the contract for whoever writes code here —
the `README.md` is the contract for whoever uses `overture`.

## Before you open a PR

One command has to be green:

```bash
./scripts/verify.sh
```

It is the same script the release runs, minus tag, push and publish: dependencies, README
version pin, the CHANGELOG entry, analyze (package and example app), tests, the examples
inside the `///` docs, `dart doc` with zero warnings, the publish dry-run, and a pana
score of 160/160. If it passes locally it passes in CI, because CI runs that file and
nothing else.

It needs network (it asks pub.dev which pana version to use) and a Flutter at or above the
floor declared in `pubspec.yaml`. Running it changes your globally activated pana version —
pub.dev always scores with the newest one, so the script installs exactly that.

## What CI checks

Two jobs, both on every pull request:

- **Verify** — `./scripts/verify.sh` on the current stable Flutter.
- **Floor** — analyze and test on the **lowest** Flutter `overture` supports, read straight
  from `pubspec.yaml`. It exists because nothing else catches it: the Flutter framework
  carries no `@Since` annotations, so an API added after the floor looks perfectly valid to
  an analyzer running on a newer SDK, and only breaks for the users we promised to support.

## Conventions

- **No `//` comments.** A fact that needs recording goes in the commit message, in the
  README, or in a test. Analyzer directives (`// ignore:`) are not comments and may stay.
- **`///` dartdoc is mandatory on every public member**, in English, with a runnable example.
  `public_member_api_docs` is enforced, and `scripts/verify_doc_examples.sh` compiles every
  ```dart fence found in `lib/`. Keep every fence self-contained — it is analyzed with only
  `dart:async`, `package:flutter/widgets.dart` and `package:overture/overture.dart` in scope,
  so a snippet leaning on an undeclared variable or on a third-party provider fails the gate.
- **The cache-key guarantee is the package.** `overture` resolves providers with
  `ImageConfiguration.empty` because `NetworkImage.obtainKey` (and every provider keyed the
  same way) ignores the configuration, so the key it computes is byte-for-byte the key the
  widget computes later. Break that and the package stops doing its one job — it is a major
  bump, not a patch.
- **Behavior changes ship with their test.** Bug fixes start red: write the failing test
  first, watch it fail for the right reason, then fix. Tests never assert
  `imageCache.containsKey`: when the test binding fails to decode, `NetworkImage._loadAsync`
  schedules an evict microtask that races with `await` resumption and the assertion goes
  flaky. Assert on the fake `HttpClient` request count instead.
- **A public-API change updates README, CHANGELOG and `example/lib/` in the same commit.**
- **Commits are conventional and lowercase**: `feat:`, `fix:`, `chore:`, `docs:`. No body,
  no co-author trailers.

## Deliberate gaps

These are absent by decision, not by omission — a PR adding one will be declined.

- **No disk cache.** `overture` warms RAM, and RAM is where the first frame reads from.
  Persisting bytes across sessions is a different problem with a mature answer already:
  `warmWith(CachedNetworkImageProvider.new, urls)` warms the cache *through* that package,
  so one call gets both layers. Reimplementing it here would duplicate a dependency users
  can pick for themselves.
- **No bundled image widget.** The whole premise is that warming is invisible to the render
  path: every widget reads the same global `imageCache`, so `Image.network`,
  `CachedNetworkImage` and a hand-rolled `ImageProvider` all benefit without knowing this
  package exists. Shipping a widget would create a second, narrower way in.
- **No dependencies beyond `flutter` and `flutter_test`.** Zero transitive surprises is a
  feature a 130-line utility can actually keep. Adding a third-party package is a v0.1 → v1
  conversation, not a PR.
- **No knobs** — per-item timeout, retry, concurrency cap, progress callback. Each one is a
  policy that depends on the caller's network and screen, and none has been asked for. The
  single `timeout` exists because an unbounded wait is a bug, not a preference. Open an issue
  with the case before writing the code.
- **No top-level functions.** Everything stays namespaced under `Overture.` so an
  auto-import lands on one obvious symbol and a reader grepping for the package finds every
  call site.
- **No first-class asset support yet.** `AssetImage.obtainKey` picks a DPR variant out of the
  `ImageConfiguration`, so `ImageConfiguration.empty` can resolve to a key the widget never
  computes. Single-resolution assets work today and the README says so; variant-aware
  warming needs explicit `ImageConfiguration` plumbing and a decision about where the DPR
  comes from outside a `BuildContext`.

## Releasing

Releases are cut by the maintainer, from `master`, with `./scripts/release.sh`. It refuses
to run outside `master` or with a dirty working tree — `pub publish` packs the files on
disk, not the commit — then runs the full `verify.sh` before tagging. Nothing publishes
from CI.
