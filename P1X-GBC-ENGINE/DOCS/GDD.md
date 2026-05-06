# Dawn of the Garden
Game Design Overview

## Concept
A Game Boy Color garden-simulation game with turn-based day/night cycles. Players plant, water, and strategically manage a garden.

## Core Gameplay

- Each in-game day lasts a few minutes where players plant, water, and manage sunlight/shade for plants.
- Night is for inventory upgrades and planning.
- A week of cycles determines the final outcome of the garden.

## Mechanics

- Plants thrive differently in sun or shade.
- Tall grass hides snakes—cutting grass removes hazards and allows placing stone paths.
- Stone paths speed up player movement.
- Enemies include bees and snakes, adding challenge.
- Weather or random events may impact watering.

## Goals

- Optimize plant placement, balance resources, and thrive over time.
- Evaluate garden success at the end of each week.

## Extra Features

- Players can add garden decorations.

## Progression System
- Players earn Garden Points based on plant health, growth, and survival.
- Points can be spent on:
- New seed types (flowers, vegetables, rare plants)
- Tool upgrades (watering can range, faster grass cutting)
- Garden expansions (unlock new plots)
- Special plants unlock after meeting certain conditions (e.g., perfect week, no damage taken).

## Controls (Game Boy Color)

- D-Pad: Move character
- A Button: Interact (plant, water, cut grass)
- B Button: Use equipped tool
- Start: Open menu (inventory, map, stats)
- Select: Switch tools

## Art Style

Bright, colorful pixel art inspired by classic Game Boy Color games.

## Simple animations

- Plants growing through stages
- Water sparkle effect
- Bees buzzing, snakes slithering
- Distinct visual indicators for:
- Dry soil
- Healthy plants
- Dangerous areas (tall grass)

## Sound Design

- Relaxing background music during the day
- Calm, slower tones at night

## Sound effects:
- Water pouring
- Grass cutting
- Bee buzzing (warning cue)
- Snake hiss (danger cue)

## Game Loop

- Start day
- Tend garden (plant, water, clear hazards)
- Avoid enemies and optimize layout
- End day → transition to night
- Upgrade and plan
- Repeat for 7 days → weekly evaluation

## Win / Lose Conditions

- Win: Achieve a thriving garden score by the end of the week.
- Lose: Too many plants die or player health reaches zero from hazards.

## Future Ideas
- Seasonal changes (spring, summer, autumn)
- Different garden themes (forest, desert, magical garden)
- NPC visitors who give quests or bonuses
- Rare events (rainstorm = free watering, drought = challenge mode)
- Mini-games (pollination challenge, pest control)

## Technical Notes
