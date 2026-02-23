# Elm Knowledge

This repository aims to provide a knowledge base to develop Elm applications.
It contains both generic information, and some of my preferences.

## Architecture

- Modules focused on a data structure
- Always expose the minimum required api from modules
- Avoid `Browser.Application` as a main, and prefer `Browser.Element` with routing handled via ports

## Design Patterns

- Extensible record phantom builder pattern (https://www.youtube.com/watch?v=Trp3tmpMb-o)
- https://sporto.github.io/elm-patterns/index.html
- Send bytes through a port: https://github.com/lue-bird/elm-bytes-ports-benchmark
- XHRHttpRequest monkeypatch to send bytes at zero cost: https://github.com/mpizenberg/elm-http-monkeys

## Some GOATs 🐐

These are the GitHub handles of some Elm developers (or orgs) that IMO have greatly contributed to the Elm community and impacted how I write Elm code, and the tools I use.
In no particular order:

evancz, wolfadex, miniBill, lydell, jfmengels, dillonkearns, lue-bird, mdgriffith, dmy, andrewMacmurray, zwilias, avh4, rtfeldman, supermario, MartinSStewart, janiczek, dwayne, jxxcarlson, krisajenkins, ryannhg, robinhegan, ianmackenzie, ...

## Tooling

TODO: fill with bullet points, presenting in one short sentence each tool in KNOWLEDGE_TOOLING.md

## Packages

TODO: fill with bullet points, presenting in one short sentence each package in KNOWLEDGE_PACKAGES.md
