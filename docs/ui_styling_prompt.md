# Helium Hustle — UI Styling Pass

## Goal
Replace the current monospace/default font styling with a clean, readable sci-fi 
aesthetic. The game is about an AI managing a lunar helium-3 mining operation. The 
UI should feel like a mission control dashboard — functional, information-dense, 
but polished. Think Factorio's UI clarity meets Stellaris's sci-fi tone.

## Font Strategy
Use Google Fonts that are freely available. Download the .ttf files into 
res://assets/fonts/ and create Godot FontFile resources.

- **Headers / titles**: Rajdhani Bold — geometric, techy, good at larger sizes.
  https://fonts.google.com/specimen/Rajdhani
- **Body / data / labels**: Exo 2 Regular and Exo 2 SemiBold — highly readable at 
  small sizes, sci-fi without being gimmicky.
  https://fonts.google.com/specimen/Exo+2
- **Numbers / resource values**: Exo 2 SemiBold or Exo 2 Medium — numbers should 
  feel slightly heavier than labels so they pop.

Download the TTF files for these fonts from Google Fonts and place them in 
res://assets/fonts/.

## Where to Apply

### Left Sidebar
- "Helium Hustle" title: Rajdhani Bold, ~24px
- Nav button labels (Commands, Buildings, etc.): Exo 2 SemiBold, ~13px
- "Speed up time" / "Resources" section headers: Rajdhani Bold, ~16px
- Speed buttons (||, 1x, 3x...): Exo 2 SemiBold, ~13px
- Resource names (Energy, Credits...): Exo 2 Regular, ~14px
- Resource values (100 / 100): Exo 2 SemiBold, ~14px
- Resource rates (+2.0/s): Exo 2 Regular, ~13px

### Center Panel (Buildings)
- "Buildings" header: Rajdhani Bold, ~22px
- Building names (Solar Panel, Refinery...): Rajdhani Bold, ~17px
- Building descriptions: Exo 2 Regular, ~13px
- Production/upkeep lines (+4.0 eng  -2.0 reg): Exo 2 SemiBold, ~13px
- Cost lines: Exo 2 Regular, ~13px
- Count (x2) and Buy button: Exo 2 SemiBold, ~14px

### Right Panel
- "Programs" / "Events" headers: Rajdhani Bold, ~18px
- Program slot buttons (1-5): Exo 2 SemiBold
- Placeholder text: Exo 2 Regular, ~13px

### Bottom Bar
- System uptime: Exo 2 Regular, ~13px

## Color Hints (optional, only if easy)
If you have time, lightly color-code the resource rate numbers:
- Positive rates: soft green (#7FBF7F)
- Negative rates: soft red (#BF7F7F)  
- Zero rates: dim gray (#808080)

Production numbers in building cards could use the same convention:
- Production values: soft green
- Upkeep values: soft red

Don't overhaul the color scheme beyond this. Keep the existing dark background.

## Implementation
- Create a Godot Theme resource (res://assets/theme.tres or set it up in code) 
  that sets the default fonts, or apply fonts directly to the relevant controls.
- Whichever approach is simpler given the current code structure is fine.

## What NOT to Do
- Don't change the layout or add/remove any UI elements
- Don't change any game logic
- Don't add custom shaders or complex visual effects
- Don't use pixel fonts or overly stylized fonts — readability comes first
