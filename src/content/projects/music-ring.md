---
title: 'Music Ring'
summary: 'A music theory engine that reverse-engineers Hooktheory chord data into correct piano voicings and Roman numeral analysis, with a web player and an ear-training quiz built on ~39,000 real songs.'
status: active
year: 2026
technologies:
  - Python
  - JavaScript
tags:
  - music-theory
  - python
  - ear-training
featured: false
order: 4
links:
  Source: 'https://github.com/briansgithub/diatonic_ring'
draft: false
placeholder: false
---

## Problem

Hooktheory's TheoryTab data encodes chords as compact JSON, not as musically meaningful voicings or scale-degree analysis. I wanted a tool that could take that raw chord data for any of thousands of real songs and reconstruct correct piano voicings and Roman numeral symbols from it, then turn that into ear-training practice grounded in music people actually know.

## Approach

The engine reverse-engineers TheoryTab chord JSON into piano voicings and Roman numeral symbols, validated with a closed-loop oracle harness rather than by manual spot-checking. A catalog database indexes roughly 39,000 scraped songs — artist, title, and complexity/frequency statistics — while the actual chord and melody data for each song lives in a separate playback cache. Both live outside the git-tracked codebase in a portable data directory, keeping the repository itself small.

An interactive web player serves the catalog and voicings directly from that cache, with a quiz mode layered on top for ear training against real chord progressions rather than synthetic examples.

## Result

A working local web player with catalog search across ~39k songs and an integrated quiz mode, backed by chord-voicing reconstruction that's checked by an automated validation harness rather than assumed correct.

## Reflection

Separating the bulky catalog and playback data from the codebase — rather than committing a 39,000-song database to git — kept the repository itself fast to clone and easy to reason about, at the cost of needing a documented handoff process for anyone (including future me) setting up the data directory from scratch.
