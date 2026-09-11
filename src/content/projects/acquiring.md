---
title: 'Acquiring Ear Trainer'
summary: 'A three-platform ear-training app that reconstructs Hooktheory chord data into piano voicings and Roman analysis, with a web player, Android app, and iOS port over a catalog of roughly 41,000 songs.'
status: active
year: 2026
technologies:
  - Kotlin
  - Swift
  - JavaScript
  - Python
  - Tone.js
tags:
  - music-theory
  - ear-training
  - android
featured: false
order: 4
cover:
  image: ../../assets/images/acquiring/acquiring-icon.webp
  alt: 'Acquiring app icon: eight glossy colored spheres arranged in a circle on a black field'
gallery:
  - image: ../../assets/images/acquiring/library.webp
    alt: 'iPhone library with playlists, catalog search, Hooktheory search, All Songs browse, and the interval singing tool'
  - image: ../../assets/images/acquiring/introduction.webp
    alt: 'iPhone introduction screen describing interval and harmony practice, with a Continue button'
  - image: ../../assets/images/acquiring/quiz-pollyanna-g-major.webp
    alt: 'iPhone quiz for Earthbound Zero Pollyanna in G major, showing a V6 chord and Full and Verse section pickers'
  - image: ../../assets/images/acquiring/quiz-pollyanna-roots.webp
    alt: 'iPhone root-only quiz for Earthbound Zero Pollyanna, with previous root, current root, and a P4 interval'
  - image: ../../assets/images/acquiring/quiz-symphony-7-a-minor.webp
    alt: 'iPhone quiz for Symphony 7 Allegretto in A minor, with melody and chord-tone cards, transport knobs, and the interval singing tool'
  - image: ../../assets/images/acquiring/quiz-symphony-7-instrumental.webp
    alt: 'iPhone quiz for Symphony 7 Allegretto in A minor on the tonic, with the Instrumental section selected'
  - image: ../../assets/images/acquiring/quiz-gladiolus-rag.webp
    alt: 'iPhone quiz for Gladiolus Rag in A-flat major, showing a diminished seventh of V and interval singing slots'
  - image: ../../assets/images/acquiring/play-store-listing.webp
    alt: 'Google Play listing for Acquiring by bellsworth, showing the colored-sphere app icon and an Install button'
  - image: ../../assets/images/acquiring/play-store-screens.webp
    alt: 'Google Play phone previews of Acquiring: song library search, an A-minor quiz, Symphony 7 Allegretto, and All Songs'
links:
  GitHub: 'https://github.com/briansgithub/acquiring'
draft: false
placeholder: false
---

## Problem

Hooktheory's TheoryTab data encodes chords as compact JSON, not as voicings, scale-degree analysis, or something you can practice against. I wanted ear training on real songs: reconstruct those chords correctly, then play and quiz them in the browser and on phones.

## Approach

Acquiring is a monorepo with three native applications that share catalog and behavioral contracts, not runtime code:

- Web: JavaScript, HTML, CSS, and Tone.js
- Android: Kotlin and Jetpack Compose
- iOS: Swift and SwiftUI

A chord interpreter turns TheoryTab JSON into piano voicings, scale degrees, and Roman numeral symbols. A closed-loop oracle scrapes Hooktheory ground truth and scores the engine per chord instead of relying on manual spot checks.

Catalog tooling harvests that data into a gzip-compressed SQLite database with a published minimum of about 41,000 browseable songs. The archive is a replaceable release artifact. User data such as playlists lives in a separate store so a catalog swap cannot erase it. Bulky catalog, playback, and harvest files stay outside Git.

The quiz plays melody and chords from a chosen song section, with tempo, transposition, instrument, and arpeggiation controls. Android also captures pitch through the microphone for sing-back and interval practice. iOS is being brought to the same feature inventory against those shared contracts.

## Result

The web player and Android app run against the full catalog: search and browse, reconstructed voicings, and a quiz loop on real progressions. iOS implements the same catalog and quiz contracts and is still catching up to Android's completed surface.

## Reflection

Keeping three native codebases honest through contracts and fixtures, rather than one shared UI layer, made platform-specific audio and persistence straightforward, at the cost of reimplementing the same behavior three times. Parking the catalog outside Git kept the repository cloneable; it also means a documented data-root setup is part of making the product run at all.
