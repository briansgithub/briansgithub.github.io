---
title: 'Back to Base 6'
description: 'How a lazy walk to class led to a surprisingly practical base-6 counting system for calculating RPMs.'
publishedAt: 2024-09-30
tags:
  - math
  - number-systems
featured: true
draft: false
placeholder: false
---

## How it happened

Why base 6? To make a long story short, it's easy to count to high numbers, and it's good for calculating RPMs.

I was walking to a college class at the Allison Road Classrooms — probably something generic like general chemistry, I don't remember. I was tired and delirious, and started counting my steps in my head: "one," "two," "three"… At some point I was walking faster than I could count, because the numbers were multisyllabic and I kept forgetting what number I was on.

So I decided to offload some of the effort onto the only convenient placeholders I had: my fingers. I forgot what number I was on and started over.

I counted ten steps and got lazy, so on my left hand I used one finger to represent those ten and started counting aloud from one again. I repeated this until all five fingers were up on my left hand.\* I had counted to ten but run out of fingers on that hand, so on the next restart I raised one finger on my right hand and closed my left. (When raising fingers one at a time starting from the thumb, I struggle once I reach the ring and pinky fingers — so now I start with the pinky.)

\*Initially I wasn't paying attention to detail, and when my fifth finger went up, I immediately closed my left hand and carried the one over to my right — rather than raising the fifth finger _and_ counting to ten aloud again before carrying. This error had me counting in base 5 on my left hand.

## The RPM trick

Base 6 lets me count quickly and record accurately.

With a stopwatch, this is especially good for counting RPM. Once the watch hits 60 seconds, stop counting. Take the number in base 6 and divide by 60 seconds. What is 60? It factors into 6×10 — so we can divide by these two factors one at a time.

Take the base-6 number and divide by 6 — that is, move the decimal point one place to the left. The number is now an order of magnitude smaller, and slightly easier to work with.

Now convert this smaller number to base 10: multiply by the 1/6ths place, the 6ths place, and the 36ths place, and sum them. Take the new base-10 number and divide by 10, the second factor — move the decimal point one place to the left again.

One place value is auditory. The second is the left hand. The third is the right hand. The fourth is a number held in your head.

You've now almost mindlessly calculated an RPM with up to four significant figures of precision, using nothing but a minute and a stopwatch. Truncate after the decimal if you don't need the precision.

Why don't we count in base 11?
