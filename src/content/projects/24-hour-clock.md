---
title: '24-Hour Clock'
summary: 'A 24-hour analog clock — an Android live wallpaper and a Python desktop widget — that visualizes circadian rhythm using a research-backed two-process model of alertness.'
status: active
year: 2026
technologies:
  - Python
  - Kotlin
  - Android
  - Fitbit API
tags:
  - python
  - android
  - biometrics
featured: true
order: 3
links:
  GitHub: 'https://github.com/briansgithub/24-hr_clock_widget'
draft: false
placeholder: false
---

## Problem

A 12-hour clock face hides more than it shows about a day: it can't represent a full day's rhythm without lapping itself, and it says nothing about where you actually are in your own energy curve. I wanted a clock that plots the day as a single loop and layers real circadian and biometric data onto it.

## Approach

The clock is a monorepo with two implementations sharing the same underlying model — an Android live wallpaper (Kotlin/Compose) and a Python desktop widget:

- A two-process model of alertness (homeostatic sleep pressure plus circadian drive) renders as an energy curve around the dial, using research-standard time constants.
- Heart-rate-nadir detection, fit with a parabolic vertex model, anchors the circadian phase with sub-hour accuracy.
- Both apps scan the personalized curve to find and display true peak alertness (acrophase).
- Google Calendar events render as arcs on the dial, and past sleep sessions — including naps — render as arcs showing when sleep actually happened.
- The Android version tracks the real angular position of the sun and moon and renders them on the dial, with an OLED-optimized black background.

Fitbit and calendar integration both run through local configuration files that are git-ignored, so credentials and health data never enter version control.

## Result

Both the Android live wallpaper and the Python widget are actively maintained and run on my own devices day to day, sharing one unified circadian model rather than drifting into two separate implementations.

## Reflection

Keeping the Android and Python versions in one repository, sharing the same model constants, turned out to matter more than I expected — the two platforms make it obvious when a formula is inconsistent between them, which a single-platform version would have hidden.
