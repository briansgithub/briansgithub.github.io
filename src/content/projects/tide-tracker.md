---
title: 'Tide Tracker'
summary: 'Two solar-powered tide trackers built with a Raspberry Pi Zero, an e-ink display, and custom 3D-printed solar panel stands.'
status: complete
year: 2024
technologies:
  - Python
  - Raspberry Pi Zero
  - Matplotlib
  - SciPy
  - E-ink display
  - 3D printing
tags:
  - embedded
  - python
  - 3d-printing
  - solar
featured: true
order: 1
cover:
  image: ../../assets/images/tide-tracker/tide-tracker-1-front.webp
  alt: 'A working Tide Tracker in a sandy wood frame, displaying a tide-height chart on its e-ink screen.'
links:
  Source: 'https://github.com/briansgithub/TideTracker_repo'
draft: false
placeholder: false
---

## Problem

A friend lives directly on the water; a family member likes to go sailing on a nearby river. Both wanted an easy way to see the tide at a glance. I had roughly one month, from the idea's conception in late November 2023 to completion in early January 2024, to design and assemble two solar-powered tide trackers as gifts.

The device plots tide height versus time for a given location and displays the plot on an e-ink display. The data comes from NOAA (the National Oceanic and Atmospheric Administration), refreshed every two hours.

![Tide Tracker unit one, front view, in a sandy-toned picture-frame enclosure](../../assets/images/tide-tracker/tide-tracker-1-front.webp)
![Tide Tracker unit one, back view showing the solar panel connectors](../../assets/images/tide-tracker/tide-tracker-1-back.webp)

## Constraints

- **Monetary cost**: This constraint applies to most projects.
- **Aesthetics**: The display had to be large enough to be readable and stand out, but not so large as to be prohibitively expensive. I used a black-and-white e-ink display rather than a multicolor one for cost and simplicity, and built a frame to enclose the electronics.
- **Solar powered**: It seemed natural for a device that tracks tides to be solar powered. Being low-power also means it can run on battery alone, making it portable.
- **Time frame**: The idea came together in September 2023. I didn't have materials until Black Friday in November, with a self-imposed deadline of Christmas.

I ended up building two units rather than one:

1. The two recipients live near different rivers.
2. The picture frames ship from Amazon as a four-pack at a low unit price. To fit all the components into one enclosure, I stacked and glued two frames together. Two frames matched the lighter, sandy color scheme of my friend's house; the other two matched the darker, rustic scheme of my family member's house.
3. Nearly 80% of the total time went into designing the physical layout and writing the code, a one-time cost. The work from the first unit could be reused for free on all subsequent units, aside from parts and assembly time.

![Tide Tracker unit two, front view, in a dark rustic-toned frame enclosure](../../assets/images/tide-tracker/tide-tracker-2-front.webp)
![Tide Tracker unit two, back view showing the solar panel connectors](../../assets/images/tide-tracker/tide-tracker-2-back.webp)

## Approach

The plot below is a snapshot of the tides in Fort Myers, FL on January 5, 2024.

![E-ink display plot of tide height versus time, with sunrise and sunset markers](../../assets/images/tide-tracker/tide-tracker-plot-snapshot.webp)

A few notes on reading the chart:

- The **y-axis** is tide **height**; the **x-axis** is time.
- The **black bar** along the curve marks the section corresponding to "now."
- **Light regions** represent daytime; **dark shaded regions** represent nighttime.
- When midnight passes, the graph shifts so the center always shows noon of "today."
- **Sunrise** and **sunset** are shown in the upper-right corner and on the plot itself.
- **High tide** and **low tide** times are labeled near the corresponding peaks and valleys.

Height is measured relative to the mean lower low water (MLLW) level. That is, the average low tide over roughly the past 19 years. "Now" is represented as a sweep along the curve rather than a single point, since a continuously refreshed point would defeat the purpose of a low-power, two-hour refresh interval.

### Power

The tracker runs on a 4500mAh LiPo battery and can go several days unattended. It charges over USB-C, with five JST connectors for solar panels.

![Solar panel array wired to the Tide Tracker enclosure](../../assets/images/tide-tracker/tide-tracker-solar-panels-1.webp)
![Second angle of the solar panel array setup](../../assets/images/tide-tracker/tide-tracker-solar-panels-2.webp)

I also designed and resin-printed custom stands for the solar panels:

![Resin-printed stand holding a solar panel at an angle](../../assets/images/tide-tracker/tide-tracker-solar-stand-1.webp)
![Second resin-printed solar panel stand design](../../assets/images/tide-tracker/tide-tracker-solar-stand-2.webp)

### Extensibility: changing location or network

What if my friend moves, or changes their Wi-Fi? I built a configuration webpage hosted on the device itself, and the internals leave room to reach the setup switch without disassembling the frame.

![Internal electronics of the Tide Tracker enclosure, including the Raspberry Pi Zero and battery](../../assets/images/tide-tracker/tide-tracker-internals.webp)

If the device loses its Wi-Fi connection, an error screen appears:

![Tide Tracker display showing a no-WiFi connection error screen](../../assets/images/tide-tracker/tide-tracker-no-wifi-photo.webp)
![Close-up of the no-WiFi setup instructions shown on the e-ink display](../../assets/images/tide-tracker/tide-tracker-no-wifi-screen.webp)

Flipping the internal setup switch boots the Raspberry Pi into a mode that broadcasts its own Wi-Fi hotspot and hosts the settings page:

![Internal setup switch used to enter WiFi configuration mode](../../assets/images/tide-tracker/tide-tracker-internal-switch.webp)

From a phone, the "tide-tracker" network becomes visible:

![Mobile WiFi settings screen showing the tide-tracker network](../../assets/images/tide-tracker/tide-tracker-wifi-network.webp)

Connecting opens a configuration page for entering Wi-Fi credentials and the NOAA station to track.

![Web-based configuration page for setting WiFi credentials and the NOAA station](../../assets/images/tide-tracker/tide-tracker-settings-page.webp)
