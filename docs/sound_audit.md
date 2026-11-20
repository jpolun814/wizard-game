# Sound audit, 2026-11-20 (a proxy, not an ear)

Made by `python tools/audit_sounds.py`. Each owner/event's files are scored against a plain description of what the sound is meant to be (`tools/sound_descriptions.json`)
with CLAP; "better in pack" is how many of the 3,761 indexed recordings match the same words better; the last column is the best three (`NOX/` the Essentials Series, `oga/` the
OpenGameArt CC0 packs, the owner's other packs: `400 Sounds Pack`, `extra96`, TomMusic's Free Fantasy SFX Pack, Horror SFX Free (licences not recorded, owner-approved), and the Super Dialogue Audio Pack, CC BY 4.0, credit Dillon Becker). Worst fits first.
Read it as leads: the model hears real recordings of clear things (thunder, a heartbeat, a page, a geyser) well and short stylized effects poorly, so a low score means
"check by ear", not "wrong". For ice, blades, lightning and whooshes no pack has a convincing match.

| owner / event | meant to be | score | better in pack | best three |
|---|---|---|---|---|
| mob_basic / shatter | ice or bone shattering | -0.10 | 3073 | 0.56 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_10.wav; 0.56 NOX/Footsteps_Iceland_Jump_Land_Gravel_Wet_Mono_05.wav; 0.54 NOX/Footsteps_Iceland_Jump_Land_Gravel_Wet_Mono_03.wav |
| wizard / die | a person falling dead, a heavy collapse | 0.05 | 2949 | 0.57 Rock Wall 1.wav; 0.57 Rock Wall 1.ogg; 0.55 NOX/Footsteps_Walk_Grass_Mono_31.wav |
| ice_plug / shatter | ice breaking apart | -0.09 | 2930 | 0.44 oga/LEGIT_FIR_Fire_Staff 23-Audio.wav; 0.41 Light Torch with Starting Loop 1.ogg; 0.41 Light Torch with Starting Loop 1.wav |
| Frostbolt / shatter | ice shattering into pieces | -0.10 | 2780 | 0.47 oga/LEGIT_FIR_Fire_Staff 23-Audio.wav; 0.46 400 Sounds Pack/paper_tear_2.wav; 0.46 Ice Barrage 1.ogg |
| casting / misfire | a magical fizzle, a spell failing | -0.01 | 2688 | 0.60 Waterspray 2.ogg; 0.60 Waterspray 2.wav; 0.60 Waterspray 1.ogg |
| rituals / misfire | a magical fizzle, a spell failing | -0.01 | 2688 | 0.60 Waterspray 2.ogg; 0.60 Waterspray 2.wav; 0.60 Waterspray 1.ogg |
| wizard / misfire | a magical fizzle, a spell failing | -0.01 | 2688 | 0.60 Waterspray 2.ogg; 0.60 Waterspray 2.wav; 0.60 Waterspray 1.ogg |
| Supernova / explosion | a huge explosion of a dying star | -0.07 | 2619 | 0.48 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.47 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.44 400 Sounds Pack/explosion_large.wav |
| Obsidian Armor / barrier | stone armor forming around a body, a heavy hardening | -0.07 | 2561 | 0.44 oga/spell_fire_04.ogg; 0.43 oga/spell_fire_03.ogg; 0.40 extra96/stone_scrape_2.wav |
| Hailstorm / shatter | a hailstone breaking, a small ice shatter | -0.06 | 2506 | 0.56 oga/bfh1_rock_breaking_01.ogg; 0.54 oga/sfx100v2_stones_02.ogg; 0.52 oga/coldsnap.wav |
| sentinel / spark | an electric zap | -0.07 | 2212 | 0.43 NOX/Electromagnetic_Fan_Idle_Loop_Mono_Elektrousi_01.wav; 0.41 NOX/Electromagnetic_Macbook_Sequence_Mono_Elektrousi_06.wav; 0.40 NOX/Electromagnetic_Smartphone_On&Off_Mono_Elektrousi.wav |
| intro / hurt_wizard | a man grunting in pain | -0.01 | 2157 | 0.54 death_10_sean.wav; 0.54 death_2_ian.wav; 0.54 death_3_ian.wav |
| epilogue / blow_last | a heavy blow of stone hitting a surface | 0.04 | 2140 | 0.50 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.47 extra96/stone_on_stone.wav; 0.46 oga/creature_misc_05.ogg |
| Glowcap / rustle | a mushroom growing from the ground, a soft rustle | -0.12 | 2001 | 0.40 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.35 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.34 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav |
| Geyser / ice | water freezing, a hiss of cold | -0.04 | 1907 | 0.37 Gas Stove_running.wav; 0.31 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.31 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| epilogue / blow | a heavy blow of stone hitting a surface | 0.09 | 1654 | 0.50 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.47 extra96/stone_on_stone.wav; 0.46 oga/creature_misc_05.ogg |
| Liana / rustle | a vine growing, leaves rustling | -0.05 | 1625 | 0.38 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.36 Forest Day Storm.wav; 0.36 Forest Day Storm.ogg |
| Geyser / whoosh | a gush of air and steam | 0.05 | 1581 | 0.41 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.40 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.39 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav |
| swing_stair / rocks | a heavy stone staircase swinging and thudding | 0.02 | 1433 | 0.47 Cave Storm.wav; 0.47 Cave Storm.ogg; 0.46 Cave Rain.wav |
| coating / ice | a hiss of fire being put out by water | -0.02 | 1377 | 0.38 Light Torch with Starting Loop 2.wav; 0.38 Light Torch with Starting Loop 2.ogg; 0.37 oga/LEGIT_FIR_Fire_Staff 23-Audio.wav |
| mob_basic / shoot | a magical bolt being fired | 0.15 | 1349 | 0.51 oga/creature_misc_05.ogg; 0.50 oga/creature_misc_04.ogg; 0.50 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav |
| lab / book_open | a heavy book opening | 0.06 | 1338 | 0.30 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav; 0.30 oga/slime_10.ogg; 0.29 Piano_stinger_dissonent.wav |
| library / book_open | a heavy book opening | 0.06 | 1338 | 0.30 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav; 0.30 oga/slime_10.ogg; 0.29 Piano_stinger_dissonent.wav |
| spellbook / book_open | a heavy book opening | 0.06 | 1338 | 0.30 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav; 0.30 oga/slime_10.ogg; 0.29 Piano_stinger_dissonent.wav |
| Great Oak / rocks | a heavy tree trunk crashing down, wood and earth thud | 0.18 | 1318 | 0.68 Rock Wall 1.wav; 0.68 Rock Wall 1.ogg; 0.66 Ice Wall 1.wav |
| mob_basic / rocks | a heavy stone blow | 0.17 | 1315 | 0.52 Rock Meteor Swarm 1.wav; 0.52 Rock Meteor Swarm 1.ogg; 0.52 Creepy_ambience_5.wav |
| Smoke Screen / fire | smoke billowing out, a soft hiss | -0.01 | 1301 | 0.36 Gas Stove_running.wav; 0.30 Match_striking.wav; 0.29 400 Sounds Pack/white_noise_long.wav |
| Mirage / glass | a glassy shimmer fading away | -0.01 | 1295 | 0.37 Piano_stinger_dissonent.wav; 0.36 Distant Yell_Echo and Reverb_2.wav; 0.33 oga/sfx100v2_misc_12.ogg |
| lab / chant | a bright magical chime, a spell succeeding | 0.08 | 1245 | 0.53 400 Sounds Pack/steel_drums_chime_positive.wav; 0.52 400 Sounds Pack/vibraphone_chime_quick.wav; 0.51 oga/magical_1.ogg |
| rituals / chant | a bright magical chime, a spell succeeding | 0.08 | 1245 | 0.53 400 Sounds Pack/steel_drums_chime_positive.wav; 0.52 400 Sounds Pack/vibraphone_chime_quick.wav; 0.51 oga/magical_1.ogg |
| sky_cloud / spark | a small electric crackle | -0.03 | 1190 | 0.32 NOX/Electromagnetic_Router_Internet_Loop_Mono_Elektrousi_02.wav; 0.29 NOX/Electromagnetic_Macbook_Idle_Loop_Mono_Elektrousi.wav; 0.29 NOX/Electromagnetic_Fan_Idle_Loop_Mono_Elektrousi_01.wav |
| Oil Slick / mud | thick oil being poured and sloshing | -0.06 | 1157 | 0.45 400 Sounds Pack/water_dripping.wav; 0.43 oga/loop_water_01.ogg; 0.43 oga/loop_water_03.ogg |
| Stonefall / rocks | a heavy boulder thudding onto the ground | 0.23 | 1067 | 0.57 Rock Wall 1.wav; 0.57 Wood Land.ogg; 0.57 Rock Wall 1.ogg |
| intro / explosion | an explosion | 0.07 | 1058 | 0.61 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.59 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.58 400 Sounds Pack/explosion_quick.wav |
| rituals / explosion | an explosion | 0.07 | 1058 | 0.61 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.59 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.58 400 Sounds Pack/explosion_quick.wav |
| intro / blink | a quick magical teleport blink | 0.18 | 1058 | 0.49 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav; 0.47 NOX/Footsteps_Mud_Run_03.wav; 0.47 NOX/Footsteps_Iceland_Run_Grass_Mono_07.wav |
| mob_basic / die | a creature dying, a collapse and groan | 0.19 | 988 | 0.62 Zombie_8.wav; 0.62 death_3_ian.wav; 0.61 death_10_sean.wav |
| lava_ball / whoosh | a glob of lava flying through the air | 0.07 | 987 | 0.44 Creepy_ambience_5.wav; 0.43 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.41 Light Torch with Starting Loop 2.wav |
| avalanche / rumble | a rumbling avalanche of snow and rock | 0.05 | 939 | 0.67 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.60 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav; 0.59 Beach Rain.wav |
| Barbs / turned | a small whoosh of air | 0.08 | 935 | 0.35 Creepy_ambience_5.wav; 0.34 oga/hurt_03.ogg; 0.33 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav |
| Frostbolt / turned | a small whoosh of air | 0.08 | 935 | 0.35 Creepy_ambience_5.wav; 0.34 oga/hurt_03.ogg; 0.33 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav |
| Ignite / turned | a small whoosh of air | 0.08 | 935 | 0.35 Creepy_ambience_5.wav; 0.34 oga/hurt_03.ogg; 0.33 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav |
| Pebble / turned | a small whoosh of air | 0.08 | 935 | 0.35 Creepy_ambience_5.wav; 0.34 oga/hurt_03.ogg; 0.33 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav |
| Black Hole / explosion | a dull implosion collapsing | 0.14 | 917 | 0.60 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.59 400 Sounds Pack/explosion_quick.wav; 0.58 400 Sounds Pack/explosion_large.wav |
| arena / game_over | a somber low sting, game over | 0.16 | 786 | 0.48 oga/weird_05.ogg; 0.47 oga/creature_roar_03.ogg; 0.42 Piano_stinger_dissonent.wav |
| match_end / game_over | a somber low sting, game over | 0.16 | 786 | 0.48 oga/weird_05.ogg; 0.47 oga/creature_roar_03.ogg; 0.42 Piano_stinger_dissonent.wav |
| Hemorrhage / blood | a wet bloody magical pulse | 0.11 | 766 | 0.43 Creepy_ambience_5.wav; 0.42 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.42 oga/weird_03.ogg |
| level_wall / chant | a bright magical chime | 0.13 | 747 | 0.53 400 Sounds Pack/steel_drums_chime_positive.wav; 0.51 400 Sounds Pack/vibraphone_chime_quick.wav; 0.49 oga/magical_6.ogg |
| match_end / chant | a bright magical chime | 0.13 | 747 | 0.53 400 Sounds Pack/steel_drums_chime_positive.wav; 0.51 400 Sounds Pack/vibraphone_chime_quick.wav; 0.49 oga/magical_6.ogg |
| ice_block / shatter | a block of ice shattering | 0.24 | 714 | 0.60 oga/bfh1_glass_breaking_01.ogg; 0.59 oga/bfh1_rock_breaking_01.ogg; 0.57 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav |
| Obsidian Armor / glass | glass or stone crystals clinking | 0.01 | 631 | 0.39 oga/bfh1_glass_hit_01.ogg; 0.38 Liquid_stirring glass full.wav; 0.37 400 Sounds Pack/keys_jingling.wav |
| Bramble / rustle | thorny branches growing and rustling | 0.07 | 601 | 0.39 Forest Day Storm.wav; 0.38 Forest Day Storm.ogg; 0.37 Forest Day Rain.wav |
| Geyser / wind | steam hissing | 0.10 | 586 | 0.65 oga/sfx100v2_loop_ambient_01.ogg; 0.52 oga/sfx100v2_air_01.ogg; 0.51 damage_3_sean.wav |
| page_pickup / rustle | a soft rustle of a page being picked up | 0.02 | 575 | 0.25 oga/book_04.ogg; 0.23 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.21 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| enemy_bolt / whoosh | a magical bolt flying past | 0.22 | 573 | 0.46 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav; 0.46 oga/monster_01.ogg; 0.45 NOX/Voice_Male_V2_Sigh_Mono_06.wav |
| Great Oak / rustle | leaves rustling as a huge tree grows | 0.08 | 561 | 0.46 Forest Day Storm.wav; 0.46 Forest Day Storm.ogg; 0.45 Forest Day Rain.wav |
| wizard / land_gravel | a person landing on gravel after a jump | 0.30 | 548 | 0.56 NOX/Footsteps_Gravel_Walk_08.wav; 0.55 NOX/Footsteps_Gravel_Run_08.wav; 0.55 NOX/Footsteps_Sand_Walk_12.wav |
| Insect Plague / hurt | a small insect buzz | 0.04 | 539 | 0.29 oga/alien_03.ogg; 0.22 oga/spring_08.ogg; 0.22 greeting_5_ian.wav |
| Push / whoosh | a strong blast of air pushing, a heavy whoomph | 0.20 | 492 | 0.45 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav; 0.44 NOX/Ambiance_Sea_Strong_Kirkjufjara_Far_Loop_Stereo_02.wav; 0.44 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav |
| Wild Shape / hurt | a wolf claw swipe and growl | 0.21 | 477 | 0.55 Zombie_8.wav; 0.48 oga/bug_04.ogg; 0.48 NOX/Voice_Male_V2_Attack_Mono_02.wav |
| Great Oak / rumble | a deep rumble as a tree crashes to the ground | 0.19 | 456 | 0.58 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.56 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.53 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| Pebble / rocks | a small stone hitting the ground | 0.22 | 448 | 0.51 oga/sfx100v2_stones_02.ogg; 0.47 NOX/Footsteps_Gravel_Run_10.wav; 0.45 oga/bfh1_rock_falling_06.ogg |
| casting / rustle | a soft cloth rustle | 0.07 | 438 | 0.25 oga/sfx100v2_loop_ambient_03.ogg; 0.23 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.22 oga/sfx100v2_thunder_01.ogg |
| epilogue / rustle | a soft cloth rustle | 0.07 | 438 | 0.25 oga/sfx100v2_loop_ambient_03.ogg; 0.23 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.22 oga/sfx100v2_thunder_01.ogg |
| arena / ice | a fizzle, a fire hissing out in water | 0.10 | 430 | 0.56 oga/LEGIT_FIR_Fire_Staff 23-Audio.wav; 0.55 Light Torch with Starting Loop 2.wav; 0.55 Light Torch with Starting Loop 2.ogg |
| Flytrap / jaw_snap | jaws snapping shut | 0.14 | 426 | 0.50 oga/bug_04.ogg; 0.43 extra96/human_gulp_2.wav; 0.41 oga/bug_01.ogg |
| arena / rustle | a cloth rustle | 0.12 | 401 | 0.29 400 Sounds Pack/clothing_2.wav; 0.28 oga/sfx100v2_loop_ambient_03.ogg; 0.27 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| wizard / step_wood | a single footstep on a wooden floor | 0.27 | 395 | 0.49 NOX/Footsteps_Rock_Run_01.wav; 0.46 NOX/Footsteps_Tile_Run_03.wav; 0.46 NOX/Footsteps_Rock_Run_06.wav |
| tutorial / portal_enter | a magical whoosh as someone steps through a portal | 0.25 | 366 | 0.50 Creepy_ambience_5.wav; 0.48 oga/monster_01.ogg; 0.48 NOX/Voice_Male_V2_Sigh_Mono_06.wav |
| world_stages / portal_enter | a magical whoosh as someone steps through a portal | 0.25 | 366 | 0.50 Creepy_ambience_5.wav; 0.48 oga/monster_01.ogg; 0.48 NOX/Voice_Male_V2_Sigh_Mono_06.wav |
| pond / ice | water freezing over, a crackling cold | 0.11 | 354 | 0.49 Torch Loop.wav; 0.49 Torch Loop.ogg; 0.47 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav |
| wizard / step_rock | a single footstep on rock | 0.30 | 354 | 0.54 NOX/Footsteps_Gravel_Run_08.wav; 0.51 NOX/Footsteps_Gravel_Walk_05.wav; 0.51 NOX/Footsteps_Gravel_Walk_08.wav |
| Ignite / cast | a ball of fire thrown, a whoosh of flame | 0.33 | 352 | 0.71 NOX/Footsteps_Rock_Jump_Start_01.wav; 0.69 Fireball 2.wav; 0.68 Fireball 2.ogg |
| intro / volcano | a deep groan and rumble of the earth | 0.11 | 334 | 0.58 Creepy_ambience_5.wav; 0.56 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.50 NOX/Ambiance_Cave_Deep_Loop_Stereo.wav |
| wizard / land_dirt | a person landing on dirt after a jump | 0.37 | 322 | 0.54 NOX/Footsteps_Walk_Grass_Mono_05.wav; 0.52 NOX/Footsteps_Walk_Grass_Mono_33.wav; 0.51 NOX/Footsteps_Walk_Grass_Mono_01.wav |
| wizard / land_leaves | a person landing on dry leaves after a jump | 0.31 | 313 | 0.50 NOX/Footsteps_Iceland_Walk_Grass_Mono_09.wav; 0.46 NOX/Footsteps_Iceland_Run_Black_Pebble_Mono_07.wav; 0.46 NOX/Footsteps_Leaves_Run_05.wav |
| wizard / land_rock | a person landing on rock after a jump | 0.30 | 298 | 0.47 NOX/Footsteps_Walk_Grass_Mono_05.wav; 0.46 NOX/Footsteps_Gravel_Run_08.wav; 0.46 NOX/Footsteps_Walk_Grass_Mono_33.wav |
| wizard / land_snow | a person landing in snow after a jump | 0.34 | 297 | 0.51 NOX/Footsteps_Snow_Run_10.wav; 0.50 NOX/Footsteps_Snow_Walk_06.wav; 0.50 NOX/Footsteps_Walk_Grass_Mono_05.wav |
| Crimson Veil / blood | a wet magical blood swirl | 0.21 | 278 | 0.50 oga/monster_01.ogg; 0.47 Cave.wav; 0.47 Cave.ogg |
| intro / hurt | a creature grunting in pain | 0.24 | 277 | 0.44 Zombie_8.wav; 0.44 damage_7_sean.wav; 0.44 death_3_ian.wav |
| mob_basic / hurt | a creature grunting in pain | 0.24 | 277 | 0.44 Zombie_8.wav; 0.44 damage_7_sean.wav; 0.44 death_3_ian.wav |
| portal_collapse / portal_enter | a magical whoosh as someone is pulled through a portal | 0.23 | 273 | 0.55 Creepy_ambience_5.wav; 0.47 Drone_doom.wav; 0.46 Tone_Moaning_Deep_3.wav |
| Oil Slick / fire | oil igniting with a whoomph | 0.19 | 271 | 0.44 Waterspray 2.ogg; 0.44 Waterspray 2.wav; 0.41 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| Thorn Whip / whoosh | a whip cracking through the air | 0.19 | 270 | 0.46 woosh_5.wav; 0.45 Swoosh_3.wav; 0.44 extra96/beach_ball_catch.wav |
| Mudslide / mud | a squelch of a foot in thick mud | 0.32 | 269 | 0.61 400 Sounds Pack/splat_quick.wav; 0.61 Gore_Wet_4.wav; 0.60 oga/bubble_03.ogg |
| wizard / land_mud | a person landing in mud after a jump | 0.31 | 266 | 0.51 NOX/Footsteps_Mud_Run_07.wav; 0.51 oga/splash_14.ogg; 0.50 oga/splash_01.ogg |
| eruption / volcano | a volcano erupting, a deep roaring blast | 0.15 | 265 | 0.52 NOX/Ambiance_Cave_Deep_Loop_Stereo.wav; 0.50 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.47 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav |
| Barbs / whoosh | a short burst of thorns flying through the air | 0.14 | 251 | 0.46 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.45 oga/sfx100v2_thunder_01.ogg; 0.42 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| wizard / step_grass | a single footstep on grass | 0.37 | 247 | 0.51 NOX/Footsteps_Mud_Run_07.wav; 0.51 NOX/Footsteps_Mud_Run_03.wav; 0.50 NOX/Footsteps_Iceland_Walk_Grass_Mono_09.wav |
| Flytrap / chomp | a plant snapping shut with a wet chomp | 0.28 | 245 | 0.51 Gore_Wet_4.wav; 0.48 NOX/Footsteps_Mud_Walk_10.wav; 0.46 400 Sounds Pack/squelching_1.wav |
| wizard / land_wood | a person landing on a wooden floor after a jump | 0.36 | 235 | 0.57 Cabinet_shut.wav; 0.56 NOX/Footsteps_Walk_Grass_Mono_05.wav; 0.52 NOX/Footsteps_Iceland_Jump_Land_Grass_Mono_01.wav |
| wizard / step_dirt | a single footstep on dirt | 0.46 | 214 | 0.62 NOX/Footsteps_Gravel_Run_08.wav; 0.60 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_07.wav; 0.60 NOX/Footsteps_Sand_Run_09.wav |
| ice_plug / ice | water freezing solid | 0.20 | 204 | 0.56 Torch Loop.wav; 0.56 Torch Loop.ogg; 0.54 NOX/Ambiance_Hot_Spring_Furnas_Caldeiras_Loop_Stereo_04.wav |
| Sinkhole / rumble | a rumble of the ground collapsing | 0.20 | 203 | 0.50 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.46 Creepy_ambience_5.wav; 0.45 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav |
| Barrier / barrier | a magical shield bubble forming, a soft shimmer | 0.22 | 203 | 0.42 Waterspray 2.wav; 0.42 Waterspray 2.ogg; 0.40 Waterspray 1.wav |
| Leech / blood | a wet draining magical pulse | 0.20 | 201 | 0.48 Cave.wav; 0.48 Cave.ogg; 0.46 Creepy_ambience_5.wav |
| mob_basic / summon | a magical arrival, a creature appearing in a swirl of magic | 0.31 | 199 | 0.45 400 Sounds Pack/steel_drums_chime_positive.wav; 0.44 400 Sounds Pack/sitar_chime_positive.wav; 0.44 NOX/Voice_Male_V2_Sigh_Mono_06.wav |
| wizard / summon | a person arriving through a magic portal, a gentle magical arrival | 0.28 | 193 | 0.49 400 Sounds Pack/steel_drums_chime_positive.wav; 0.47 oga/magical_1_0.ogg; 0.47 oga/magical_1.ogg |
| falling_rock / rocks | a rock falling and hitting the ground | 0.30 | 168 | 0.49 NOX/Footsteps_Gravel_Run_10.wav; 0.49 oga/sfx100v2_stones_02.ogg; 0.47 oga/bfh1_rock_breaking_01.ogg |
| Earthquake / rumble | a deep earthquake rumble shaking the ground | 0.23 | 166 | 0.53 NOX/Ambiance_Cave_Deep_Loop_Stereo.wav; 0.50 Creepy_ambience_5.wav; 0.49 NOX/Ambiance_Hot_Spring_Furnas_Caldeiras_Loop_Stereo_04.wav |
| Sinkhole / rocks | earth and rocks crumbling into a pit | 0.24 | 163 | 0.44 Ice Wall 2.ogg; 0.44 Ice Wall 2.wav; 0.44 Rock Wall 2.wav |
| Frostbolt / cast | a shard of ice thrown through the air, a cold whoosh | 0.43 | 158 | 0.67 Swoosh_3.wav; 0.66 extra96/land_in_sand.wav; 0.65 woosh.wav |
| Thunderclap / rumble | a rumble of thunder | 0.14 | 149 | 0.51 oga/sfx100v2_thunder_01.ogg; 0.45 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.45 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| Stone Wall / rumble | a deep rumble as the ground heaves | 0.19 | 138 | 0.50 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.50 NOX/Ambiance_Cave_Deep_Loop_Stereo.wav; 0.46 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav |
| Hailstorm / barrage | a barrage of ice hailing down | 0.27 | 130 | 0.57 NOX/Ambiance_Rain_Calm_Loop_Stereo.wav; 0.55 Forest Night Rain.wav; 0.55 Forest Night Rain.ogg |
| Hex / dark_whoosh | a dark curse, a low sinister whoosh | 0.28 | 128 | 0.50 oga/creature_monster_03.ogg; 0.47 oga/monster_01.ogg; 0.46 Creepy_ambience_5.wav |
| Ignite / fire | a fireball exploding on impact, a burst of flame | 0.42 | 126 | 0.68 Fireball 3.wav; 0.68 Fireball 3.ogg; 0.68 Fireball 2.wav |
| Updraft / whirl | a column of rising wind | 0.16 | 117 | 0.54 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.52 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.52 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav |
| Insect Plague / summon | a swarm of insects buzzing | 0.11 | 111 | 0.34 NOX/Ambiance_Night_Loop_Stereo.wav; 0.27 Forest Night.wav; 0.27 Forest Night.ogg |
| wizard / land_tile | a person landing on a stone floor after a jump | 0.42 | 108 | 0.57 NOX/Footsteps_Walk_Grass_Mono_05.wav; 0.55 NOX/Footsteps_Gravel_Run_10.wav; 0.54 NOX/Footsteps_Gravel_Run_08.wav |
| rock_wall / rumble | a deep rumble of a wall collapsing | 0.24 | 105 | 0.57 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.56 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.48 400 Sounds Pack/explosion_quick.wav |
| Wild Shape / summon | a person turning into a wolf, a growl and a howl | 0.27 | 99 | 0.56 Crying_moaning_ambience_3.wav; 0.51 Monster_Mech.wav; 0.50 Distant Yell_Echo and Reverb_2.wav |
| Crimson Veil / glass | a glassy crack as a blow is negated | 0.24 | 95 | 0.40 oga/bfh1_rock_breaking_01.ogg; 0.37 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.36 oga/LEGIT_FIR_Fire_Staff 8-Audio.wav |
| epilogue / summon | a slow eerie magical summoning | 0.20 | 94 | 0.59 Crying_moaning_ambience_2.wav; 0.56 oga/sfx100v2_loop_ambient_04.ogg; 0.55 Creepy_ambience_5.wav |
| Eldritch Blast / blast | a crackling beam of dark magical energy | 0.31 | 79 | 0.46 oga/alien_01.ogg; 0.44 NOX/Footsteps_Mud_Walk_05.wav; 0.42 oga/alien_03.ogg |
| coating / fire | a body bursting into flame, a whoosh of fire | 0.36 | 78 | 0.59 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.58 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.55 Fireball 3.wav |
| Stalagmite / rocks | stone spikes thrusting up from the ground, rock cracking | 0.28 | 74 | 0.47 Rock Wall 2.wav; 0.47 Rock Wall 2.ogg; 0.45 oga/stones_03.ogg |
| gas_bank / fire | gas igniting with a whoomph | 0.36 | 74 | 0.64 oga/sfx100v2_air_01.ogg; 0.62 oga/LEGIT_FIR_Fire_Staff 8-Audio.wav; 0.62 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| Tornado / whirl | a howling tornado, a whirling roaring wind | 0.28 | 72 | 0.68 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.62 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav; 0.58 NOX/Ambiance_Sea_Strong_Kirkjufjara_Far_Loop_Stereo_01.wav |
| Vacuum / dark_whoosh | air being sucked out, a low draining whoosh | 0.36 | 67 | 0.56 oga/sfx100v2_air_01.ogg; 0.54 Hiss.wav; 0.53 oga/sfx100v2_loop_ambient_01.ogg |
| Silence / dark_whoosh | a hush, a low muffling whoosh | 0.21 | 62 | 0.42 Creepy_ambience_5.wav; 0.36 woosh.wav; 0.34 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav |
| Ice Prison / ice | water freezing solid into a block of ice, a cold crystallizing | 0.31 | 59 | 0.50 Ice Wall 2.wav; 0.50 Ice Wall 2.ogg; 0.48 oga/stones_03.ogg |
| lava_ball / fire | a ball of molten lava splashing, a hiss and burst of fire | 0.36 | 57 | 0.51 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav; 0.51 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.50 Light Torch with Starting Loop 2.wav |
| Water Jet / jet | a hard jet of water spraying from a hose | 0.32 | 55 | 0.52 NOX/Ambiance_Waterfall_Big_Skógafoss_Far_Loop_Stereo_02.wav; 0.51 NOX/Ambiance_Waterfall_Moihnos_Cascata_do_Limbo_Loop_Stereo.wav; 0.51 NOX/Ambiance_Waterfall_Big_Skógafoss_Far_Loop_Stereo_01.wav |
| wizard / step_leaves | a single footstep on dry leaves | 0.45 | 50 | 0.51 NOX/Footsteps_Iceland_Walk_Grass_Mono_09.wav; 0.51 NOX/Footsteps_Leaves_Run_01.wav; 0.51 NOX/Footsteps_Mud_Walk_07.wav |
| wizard / step_snow | a single footstep in snow | 0.51 | 50 | 0.59 NOX/Footsteps_Iceland_Walk_Snow_Hard_Mono_04.wav; 0.57 NOX/Footsteps_Sand_Walk_08.wav; 0.57 NOX/Footsteps_Iceland_Run_Gravel_Frozen_Mono_06.wav |
| wizard / step_tile | a single footstep on a stone tile floor | 0.45 | 48 | 0.56 NOX/Footsteps_Gravel_Run_08.wav; 0.55 NOX/Footsteps_Tile_Run_03.wav; 0.55 NOX/Footsteps_Gravel_Run_10.wav |
| Gust / whoosh | a strong gust of wind blowing past | 0.32 | 43 | 0.61 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.54 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav; 0.50 NOX/Ambiance_Ocean_Ribeira_Grande_Loop_Stereo_02.wav |
| Blizzard / wind | a cold howling snowstorm wind | 0.33 | 43 | 0.63 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.56 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav; 0.55 NOX/Ambiance_Sea_Strong_Kirkjufjara_Far_Loop_Stereo_01.wav |
| wizard / fade | a wizard fading from sight, a soft dark whoosh | 0.33 | 42 | 0.48 Creepy_ambience_5.wav; 0.48 oga/creature_monster_03.ogg; 0.47 Drone_doom.wav |
| Golem / rocks | heavy rocks grinding and stacking | 0.36 | 41 | 0.51 oga/stones_03.ogg; 0.48 Rock Wall 2.wav; 0.48 Rock Wall 2.ogg |
| arrival_portal / portal_open | a magical portal opening, a swirling hum | 0.30 | 39 | 0.54 Distant Yell_Echo and Reverb_2.wav; 0.53 Creepy_ambience_5.wav; 0.50 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav |
| Pebble / whoosh | a stone thrown through the air | 0.39 | 38 | 0.49 NOX/Footsteps_Iceland_Run_Grass_Mono_07.wav; 0.49 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav; 0.47 NOX/Footsteps_Gravel_Run_01.wav |
| Spore Puff / wind | a person exhaling a puff of breath | 0.31 | 37 | 0.39 extra96/human_sigh.wav; 0.39 miscellaneous_17_sean.wav; 0.39 miscellaneous_17_meghan.wav |
| Golem / rumble | a deep rumble of earth as a stone giant rises | 0.38 | 34 | 0.64 Creepy_ambience_5.wav; 0.56 NOX/Ambiance_Cave_Deep_Loop_Stereo.wav; 0.56 NOX/Ambiance_Cave_Dark_Loop_Stereo.wav |
| Icicles / shatter | icicles cracking and breaking off, ice shards | 0.32 | 33 | 0.44 oga/stones_03.ogg; 0.44 oga/LEGIT_FIR_Fire_Staff 21-Audio.wav; 0.43 oga/coldsnap.wav |
| Stonefall / rumble | a deep rumble of a boulder landing | 0.35 | 29 | 0.55 Creepy_ambience_5.wav; 0.53 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.49 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav |
| field_portal / portal_open | a magical portal humming open | 0.37 | 29 | 0.59 Distant Yell_Echo and Reverb_2.wav; 0.59 Drone_doom.wav; 0.57 Creepy_ambience_5.wav |
| portal_collapse / portal_open | a magical portal opening, a swirling hum | 0.34 | 28 | 0.54 Distant Yell_Echo and Reverb_2.wav; 0.53 Creepy_ambience_5.wav; 0.50 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav |
| Fire Breath / breath | a roaring jet of flame from a flamethrower | 0.45 | 27 | 0.52 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.51 oga/LEGIT_FIR_Fire_Staff 3-Audio.wav; 0.51 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav |
| hud / click | a short soft interface click | 0.33 | 26 | 0.50 400 Sounds Pack/select_2.wav; 0.49 oga/creature_misc_02.ogg; 0.48 400 Sounds Pack/wobble.wav |
| library / click | a short soft interface click | 0.33 | 26 | 0.50 400 Sounds Pack/select_2.wav; 0.49 oga/creature_misc_02.ogg; 0.48 400 Sounds Pack/wobble.wav |
| likeness_panel / click | a short soft interface click | 0.33 | 26 | 0.50 400 Sounds Pack/select_2.wav; 0.49 oga/creature_misc_02.ogg; 0.48 400 Sounds Pack/wobble.wav |
| menu / click | a short soft interface click | 0.33 | 26 | 0.50 400 Sounds Pack/select_2.wav; 0.49 oga/creature_misc_02.ogg; 0.48 400 Sounds Pack/wobble.wav |
| settings / click | a short soft interface click | 0.33 | 26 | 0.50 400 Sounds Pack/select_2.wav; 0.49 oga/creature_misc_02.ogg; 0.48 400 Sounds Pack/wobble.wav |
| Scythe / swing | a scythe blade swinging through the air with a slicing swish | 0.44 | 26 | 0.66 Swoosh_3.wav; 0.65 400 Sounds Pack/whoosh_2.wav; 0.61 oga/LEGIT_FIR_Fire_Staff 14-Audio.wav |
| Featherfall / whoosh | a gentle soft breeze, feathers drifting | 0.18 | 25 | 0.31 oga/sfx100v2_loop_ambient_03.ogg; 0.28 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.28 oga/sfx100v2_thunder_01.ogg |
| Tide Surf / sea | ocean waves rolling and surging | 0.40 | 25 | 0.67 NOX/Ambiance_Ocean_Praia_dos_Moinhos_Loop_Stereo_01.wav; 0.66 NOX/Ambiance_Sea_Strong_Vik_Close_Loop_Stereo_01.wav; 0.66 NOX/Ambiance_Sea_Strong_Vik_Far_Loop_Stereo_02.wav |
| mob_basic / whoosh | a whoosh of a blow through the air | 0.37 | 23 | 0.57 woosh.wav; 0.55 400 Sounds Pack/whoosh_2.wav; 0.53 Swoosh_3.wav |
| Rocket Jump / breath | a roaring rocket blast of flame lifting off | 0.38 | 23 | 0.61 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.57 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.50 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| wizard / land_grass | a person landing on grass after a jump | 0.42 | 22 | 0.47 NOX/Footsteps_Walk_Grass_Mono_01.wav; 0.47 NOX/Footsteps_Walk_Grass_Mono_05.wav; 0.47 NOX/Footsteps_Iceland_Walk_Grass_Mono_09.wav |
| library / page | a paper page turning | 0.23 | 19 | 0.41 oga/book_04.ogg; 0.37 oga/book_01.ogg; 0.33 extra96/page_turn.wav |
| spellbook / page | a paper page turning | 0.23 | 19 | 0.41 oga/book_04.ogg; 0.37 oga/book_01.ogg; 0.33 extra96/page_turn.wav |
| intro / whoosh | a heavy whoosh of air pushing someone | 0.37 | 19 | 0.48 miscellaneous_14_meghan.wav; 0.45 Hiss.wav; 0.45 NOX/Voice_Female_V1_Sigh_Mono_11.wav |
| Black Hole / dark_whoosh | a deep dark whoosh being sucked inward | 0.43 | 19 | 0.64 Creepy_ambience_5.wav; 0.63 oga/creature_monster_03.ogg; 0.55 oga/monster_04.ogg |
| Decoy / dark_whoosh | a ghostly shadow figure appearing, a dark whispering whoosh | 0.41 | 18 | 0.57 oga/sfx100v2_misc_37.ogg; 0.54 Distant Yell_Echo and Reverb_2.wav; 0.53 Crying_moaning_ambience_2.wav |
| rock_wall / rocks | rocks crumbling and falling apart | 0.45 | 17 | 0.58 Ice Wall 2.ogg; 0.58 Ice Wall 2.wav; 0.54 oga/stones_03.ogg |
| Eclipse / dark_whoosh | a vast darkness falling over the world, a deep low drone | 0.32 | 16 | 0.61 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.57 NOX/Ambiance_Cave_Dark_Loop_Stereo.wav; 0.52 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav |
| Lily Pads / fire | leaves catching fire | 0.38 | 13 | 0.60 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.58 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.54 Light Torch with Starting Loop 2.wav |
| intro / page | a paper page turning | 0.25 | 12 | 0.41 oga/book_04.ogg; 0.37 oga/book_01.ogg; 0.33 extra96/page_turn.wav |
| epilogue / book_close | a heavy book closing | 0.31 | 12 | 0.37 oga/creature_misc_05.ogg; 0.36 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_10.wav; 0.35 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| library / book_close | a heavy book closing | 0.31 | 12 | 0.37 oga/creature_misc_05.ogg; 0.36 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_10.wav; 0.35 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| spellbook / book_close | a heavy book closing | 0.31 | 12 | 0.37 oga/creature_misc_05.ogg; 0.36 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_10.wav; 0.35 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| Bramble / fire | dry branches catching fire, crackling | 0.42 | 12 | 0.64 Light Torch with Starting Loop 2.wav; 0.64 Light Torch with Starting Loop 2.ogg; 0.63 Light Torch with Starting Loop 1.wav |
| Liana / fire | a vine catching fire | 0.43 | 12 | 0.56 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.54 Light Torch with Starting Loop 2.wav; 0.54 Light Torch with Starting Loop 2.ogg |
| Ice Prison / shatter | a block of ice shattering | 0.52 | 12 | 0.60 oga/bfh1_glass_breaking_01.ogg; 0.59 oga/bfh1_rock_breaking_01.ogg; 0.57 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav |
| Firewall / burn | a wall of fire roaring and crackling | 0.47 | 11 | 0.64 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav; 0.63 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.60 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav |
| rituals / dark_whoosh | a deep dark whoosh, a low sinister sound | 0.37 | 10 | 0.54 oga/creature_monster_03.ogg; 0.53 Creepy_ambience_5.wav; 0.48 Drone_doom.wav |
| Flaming Sphere / fire | a ball of fire rolling and burning | 0.52 | 10 | 0.66 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.62 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav; 0.60 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav |
| wizard / step_mud | a single footstep squelching in mud | 0.61 | 10 | 0.68 NOX/Footsteps_Mud_Walk_01.wav; 0.67 NOX/Footsteps_Mud_Walk_08.wav; 0.64 400 Sounds Pack/splat_quick.wav |
| Flytrap / fire | a plant catching fire | 0.48 | 9 | 0.59 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.59 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.55 Light Torch with Starting Loop 2.wav |
| Supernova / fire | a roaring blaze of burning fire | 0.52 | 9 | 0.61 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.59 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav; 0.58 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav |
| Invincible Snail / summon | a slow snail appearing, a slimy wet sound | 0.49 | 7 | 0.55 Gore_mushy.wav; 0.54 400 Sounds Pack/splat_quick.wav; 0.53 oga/bug_04.ogg |
| Great Oak / fire | a tree catching fire | 0.52 | 6 | 0.59 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.58 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.54 Light Torch with Starting Loop 2.wav |
| intro / dark_whoosh | a deep dark whoosh, a low sinister sound | 0.42 | 5 | 0.54 oga/creature_monster_03.ogg; 0.53 Creepy_ambience_5.wav; 0.48 Drone_doom.wav |
| Firewall / fire | fire igniting with a whoomph | 0.58 | 4 | 0.61 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.60 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.59 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| Stone Wall / rocks | a heavy slab of stone rising from the ground, a rock wall | 0.64 | 4 | 0.66 Rock Wall 2.wav; 0.66 Rock Wall 2.ogg; 0.64 Rock Wall 1.wav |
| Moonbeam / dark_whoosh | a soft glowing beam of moonlight, an ethereal shimmer | 0.31 | 2 | 0.32 Distant Yell_Echo and Reverb_2.wav; 0.32 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.31 Piano_stinger_dissonent.wav |
| Hunter's Mark / heartbeat | a slow heartbeat | 0.34 | 2 | 0.41 Creepy_ambience_5.wav; 0.38 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.33 oga/monster_04.ogg |
| Raise Dead / rise | earth cracking open as something rises from the grave, rumble and creaking | 0.45 | 2 | 0.56 Creepy_ambience_5.wav; 0.51 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.45 Portcullis Gate.ogg |
| wizard / step_gravel | a single footstep on gravel | 0.62 | 2 | 0.63 NOX/Footsteps_Gravel_Run_07.wav; 0.62 NOX/Footsteps_Gravel_Run_08.wav; 0.62 NOX/Footsteps_Gravel_Walk_05.wav |
| Spark / spark | a lightning strike, a sharp crack of thunder | 0.47 | 1 | 0.50 oga/sfx100v2_thunder_01.ogg; 0.45 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.43 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav |
| Flare / fire | a small flame igniting, a lighter flicking on | 0.48 | 1 | 0.50 400 Sounds Pack/light_match.wav; 0.47 Gas Stove_lighting.wav; 0.44 NOX/Electromagnetic_Fan_Idle_Loop_Mono_Elektrousi_01.wav |
| Geyser / geyser | a jet of scalding water bursting up from the ground | 0.51 | 1 | 0.51 Waterspray 2.ogg; 0.51 Waterspray 2.wav; 0.47 Wave Attack 2.wav |
| Lily Pads / wind | a leaf landing on water, a soft splash | 0.59 | 1 | 0.59 oga/splash_14.ogg; 0.54 oga/splash_01.ogg; 0.54 NOX/Footsteps_WaterV1_Walk_09.wav |
| Adrenaline / heartbeat | a fast pounding heartbeat | 0.46 | 0 | 0.39 Inside Night Rain.ogg; 0.39 Inside Night Rain.wav; 0.36 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav |
| Fight or Flight / heartbeat | a fast pounding heartbeat | 0.46 | 0 | 0.39 Inside Night Rain.ogg; 0.39 Inside Night Rain.wav; 0.36 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav |
| intro / thunder | a rumble and crack of thunder | 0.50 | 0 | 0.50 oga/sfx100v2_thunder_01.ogg; 0.44 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.43 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav |
| portal_collapse / thunder | distant thunder | 0.50 | 0 | 0.50 oga/sfx100v2_thunder_01.ogg; 0.38 oga/sfx100v2_loop_ambient_03.ogg; 0.36 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| Thunderclap / thunder | a loud clap of thunder | 0.51 | 0 | 0.51 oga/sfx100v2_thunder_01.ogg; 0.47 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.47 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav |
| sky_cloud / thunder | a crack of thunder | 0.52 | 0 | 0.52 oga/sfx100v2_thunder_01.ogg; 0.44 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.44 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| world_stages / thunder | a crack of thunder | 0.52 | 0 | 0.52 oga/sfx100v2_thunder_01.ogg; 0.44 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.44 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| Shadow Step / dark_whoosh | a quick shadowy teleport, a short dark whoosh | 0.52 | 0 | 0.52 oga/monster_01.ogg; 0.50 Water Land.ogg; 0.50 Water Land.wav |
