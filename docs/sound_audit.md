# Sound audit, 2026-11-20 (a proxy, not an ear)

Made by `python tools/audit_sounds.py`. Each owner/event's files are scored against a plain description of what the sound is meant to be (`tools/sound_descriptions.json`)
with CLAP; "better in pack" is how many of the 2,658 indexed recordings match the same words better; the last column is the best three (`NOX/` the Essentials Series, `oga/` the
OpenGameArt CC0 packs, `400 Sounds Pack/` and `extra96/` two packs in the owner's Downloads whose licence is NOT KNOWN: do not use a sound from them until it is). Worst fits first.
Read it as leads: the model hears real recordings of clear things (thunder, a heartbeat, a page, a geyser) well and short stylized effects poorly, so a low score means
"check by ear", not "wrong". For ice, blades, lightning and whooshes no pack has a convincing match.

| owner / event | meant to be | score | better in pack | best three |
|---|---|---|---|---|
| Featherfall / whoosh | a gentle soft breeze, feathers drifting | -0.27 | 2631 | 0.31 oga/sfx100v2_loop_ambient_03.ogg; 0.28 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.28 oga/sfx100v2_thunder_01.ogg |
| Insect Plague / summon | a swarm of insects buzzing | -0.31 | 2592 | 0.34 NOX/Ambiance_Night_Loop_Stereo.wav; 0.22 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav; 0.22 oga/LEGIT_FIR_Fire_Staff 24-Audio.wav |
| Silence / dark_whoosh | a hush, a low muffling whoosh | -0.19 | 2521 | 0.34 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.34 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.33 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav |
| Hailstorm / shatter | hailstones hitting and shattering on the ground | -0.24 | 2519 | 0.54 NOX/Ambiance_Rain_Strong_Loop_Stereo.wav; 0.53 NOX/Ambiance_Rain_Calm_Loop_Stereo.wav; 0.53 NOX/Ambiance_Nature_Rain_Calm_Leaves_Loop_Stereo.wav |
| Black Hole / dark_whoosh | a deep dark whoosh being sucked inward | -0.14 | 2460 | 0.63 oga/creature_monster_03.ogg; 0.55 oga/monster_04.ogg; 0.54 oga/LEGIT_FIR_Fire_Staff 13-Audio.wav |
| Eclipse / dark_whoosh | a vast low dark whoosh as the world goes dark | -0.11 | 2450 | 0.55 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.54 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.53 NOX/Ambiance_Cave_Dark_Loop_Stereo.wav |
| Vacuum / dark_whoosh | air being sucked out, a low draining whoosh | -0.12 | 2441 | 0.56 oga/sfx100v2_air_01.ogg; 0.53 oga/sfx100v2_loop_ambient_01.ogg; 0.52 NOX/Voice_Female_V1_Sigh_Mono_11.wav |
| Moonbeam / dark_whoosh | a soft ethereal beam of light humming | -0.17 | 2432 | 0.33 400 Sounds Pack/controller_button_press_2.wav; 0.33 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.31 NOX/Atmosphere_Scifi_Bunker_Loop_Stereo.wav |
| Barbs / turned | a small whoosh of air | -0.12 | 2383 | 0.34 oga/hurt_03.ogg; 0.33 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.33 400 Sounds Pack/whoosh_2.wav |
| Frostbolt / turned | a small whoosh of air | -0.12 | 2383 | 0.34 oga/hurt_03.ogg; 0.33 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.33 400 Sounds Pack/whoosh_2.wav |
| Ignite / turned | a small whoosh of air | -0.12 | 2383 | 0.34 oga/hurt_03.ogg; 0.33 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.33 400 Sounds Pack/whoosh_2.wav |
| Pebble / turned | a small whoosh of air | -0.12 | 2383 | 0.34 oga/hurt_03.ogg; 0.33 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.33 400 Sounds Pack/whoosh_2.wav |
| intro / dark_whoosh | a deep dark whoosh, a low sinister sound | -0.11 | 2345 | 0.54 oga/creature_monster_03.ogg; 0.48 oga/monster_04.ogg; 0.43 oga/creature_monster_04.ogg |
| rituals / dark_whoosh | a deep dark whoosh, a low sinister sound | -0.11 | 2345 | 0.54 oga/creature_monster_03.ogg; 0.48 oga/monster_04.ogg; 0.43 oga/creature_monster_04.ogg |
| Hex / dark_whoosh | a dark curse, a low sinister whoosh | -0.05 | 2254 | 0.50 oga/creature_monster_03.ogg; 0.47 oga/monster_01.ogg; 0.45 oga/sfx100v2_misc_37.ogg |
| Decoy / dark_whoosh | a ghostly dark whoosh as a shadow appears | -0.06 | 2217 | 0.52 oga/creature_monster_03.ogg; 0.48 oga/monster_04.ogg; 0.48 oga/sfx100v2_misc_37.ogg |
| Faint / faint | a soft magical sleep spell, someone slumping | -0.10 | 2125 | 0.42 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.34 oga/sfx100v2_loop_ambient_04.ogg; 0.32 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav |
| wizard / faint | a soft magical sleep spell, someone slumping | -0.10 | 2125 | 0.42 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.34 oga/sfx100v2_loop_ambient_04.ogg; 0.32 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav |
| ice_plug / shatter | ice breaking apart | -0.11 | 2101 | 0.44 oga/LEGIT_FIR_Fire_Staff 23-Audio.wav; 0.40 oga/LEGIT_FIR_Fire_Staff 24-Audio.wav; 0.39 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| mob_basic / shatter | ice or bone shattering | -0.10 | 2073 | 0.56 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_10.wav; 0.56 NOX/Footsteps_Iceland_Jump_Land_Gravel_Wet_Mono_05.wav; 0.54 NOX/Footsteps_Iceland_Jump_Land_Gravel_Wet_Mono_03.wav |
| wizard / die | a person falling dead, a heavy collapse | 0.05 | 2037 | 0.55 NOX/Footsteps_Walk_Grass_Mono_31.wav; 0.54 NOX/Footsteps_Walk_Grass_Mono_06.wav; 0.54 NOX/Footsteps_Iceland_Walk_Snow_Grass_Mono_08.wav |
| Frostbolt / cast | a shard of ice thrown through the air, a cold whoosh | -0.00 | 1972 | 0.66 extra96/land_in_sand.wav; 0.64 NOX/Footsteps_Gravel_Run_01.wav; 0.61 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav |
| casting / misfire | a magical fizzle, a spell failing | -0.01 | 1968 | 0.47 NOX/Footsteps_Iceland_Jump_Land_Snow_Grass_Mono_03.wav; 0.45 NOX/Footsteps_Walk_Grass_Mono_43.wav; 0.44 NOX/Footsteps_Iceland_Jump_Land_Snow_Grass_Mono_02.wav |
| rituals / misfire | a magical fizzle, a spell failing | -0.01 | 1968 | 0.47 NOX/Footsteps_Iceland_Jump_Land_Snow_Grass_Mono_03.wav; 0.45 NOX/Footsteps_Walk_Grass_Mono_43.wav; 0.44 NOX/Footsteps_Iceland_Jump_Land_Snow_Grass_Mono_02.wav |
| wizard / misfire | a magical fizzle, a spell failing | -0.01 | 1968 | 0.47 NOX/Footsteps_Iceland_Jump_Land_Snow_Grass_Mono_03.wav; 0.45 NOX/Footsteps_Walk_Grass_Mono_43.wav; 0.44 NOX/Footsteps_Iceland_Jump_Land_Snow_Grass_Mono_02.wav |
| Icicles / shatter | icicles cracking and breaking off, ice shards | -0.20 | 1960 | 0.44 oga/stones_03.ogg; 0.44 oga/LEGIT_FIR_Fire_Staff 21-Audio.wav; 0.43 oga/coldsnap.wav |
| Barbs / whoosh | a short burst of thorns flying through the air | -0.06 | 1930 | 0.46 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.45 oga/sfx100v2_thunder_01.ogg; 0.42 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| Shadow Step / dark_whoosh | a quick dark teleport whoosh | 0.05 | 1904 | 0.65 oga/creature_monster_03.ogg; 0.57 oga/monster_01.ogg; 0.57 oga/creature_monster_04.ogg |
| Frostbolt / shatter | ice shattering into pieces | -0.10 | 1842 | 0.47 oga/LEGIT_FIR_Fire_Staff 23-Audio.wav; 0.46 400 Sounds Pack/paper_tear_2.wav; 0.45 oga/LEGIT_FIR_Fire_Staff 21-Audio.wav |
| lava_ball / whoosh | a glob of lava flying through the air | -0.09 | 1805 | 0.43 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.41 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.39 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav |
| Obsidian Armor / barrier | stone armor forming around a body, a heavy hardening | -0.07 | 1804 | 0.44 oga/spell_fire_04.ogg; 0.43 oga/spell_fire_03.ogg; 0.40 extra96/stone_scrape_2.wav |
| Supernova / explosion | a huge explosion of a dying star | -0.07 | 1754 | 0.48 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.47 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.44 400 Sounds Pack/explosion_large.wav |
| Ice Prison / shatter | a block of ice shattering | 0.04 | 1599 | 0.60 oga/bfh1_glass_breaking_01.ogg; 0.59 oga/bfh1_rock_breaking_01.ogg; 0.57 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav |
| ice_block / shatter | a block of ice shattering | 0.04 | 1599 | 0.60 oga/bfh1_glass_breaking_01.ogg; 0.59 oga/bfh1_rock_breaking_01.ogg; 0.57 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav |
| epilogue / blow_last | a heavy blow of stone hitting a surface | 0.04 | 1528 | 0.50 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.47 extra96/stone_on_stone.wav; 0.46 oga/creature_misc_05.ogg |
| sentinel / spark | an electric zap | -0.07 | 1495 | 0.43 NOX/Electromagnetic_Fan_Idle_Loop_Mono_Elektrousi_01.wav; 0.41 NOX/Electromagnetic_Macbook_Sequence_Mono_Elektrousi_06.wav; 0.40 NOX/Electromagnetic_Smartphone_On&Off_Mono_Elektrousi.wav |
| intro / hurt_wizard | a man grunting in pain | -0.01 | 1444 | 0.48 NOX/Voice_Male_V1_Effort_Mono_07.wav; 0.43 NOX/Voice_Male_V2_Effort_Mono_04.wav; 0.43 NOX/Voice_Male_V1_Effort_Mono_05.wav |
| Glowcap / rustle | a mushroom growing from the ground, a soft rustle | -0.12 | 1402 | 0.40 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.35 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.34 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav |
| Geyser / ice | water freezing, a hiss of cold | -0.04 | 1355 | 0.31 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.31 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.30 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav |
| Bramble / fire | dry branches catching fire, crackling | -0.04 | 1244 | 0.61 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.59 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav; 0.56 NOX/Ambiance_Fire_Big_Loop_Mono.wav |
| arrival_portal / portal_open | a magical portal opening, a swirling hum | 0.03 | 1227 | 0.50 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.48 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.45 NOX/Ambiance_Cave_Dark_Loop_Stereo.wav |
| portal_collapse / portal_open | a magical portal opening, a swirling hum | 0.03 | 1227 | 0.50 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.48 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.45 NOX/Ambiance_Cave_Dark_Loop_Stereo.wav |
| enemy_bolt / whoosh | a magical bolt flying past | 0.10 | 1221 | 0.46 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav; 0.46 oga/monster_01.ogg; 0.45 NOX/Voice_Male_V2_Sigh_Mono_06.wav |
| epilogue / blow | a heavy blow of stone hitting a surface | 0.09 | 1195 | 0.50 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.47 extra96/stone_on_stone.wav; 0.46 oga/creature_misc_05.ogg |
| Geyser / whoosh | a gush of air and steam | 0.05 | 1194 | 0.41 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.40 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.39 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav |
| Gust / whoosh | a strong gust of wind blowing past | 0.01 | 1129 | 0.61 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.54 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav; 0.50 NOX/Ambiance_Ocean_Ribeira_Grande_Loop_Stereo_02.wav |
| Liana / rustle | a vine growing, leaves rustling | -0.05 | 1092 | 0.38 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.35 oga/LEGIT_FIR_Fire_Staff 24-Audio.wav; 0.34 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav |
| Pebble / whoosh | a stone thrown through the air | 0.12 | 1066 | 0.49 NOX/Footsteps_Iceland_Run_Grass_Mono_07.wav; 0.49 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav; 0.47 NOX/Footsteps_Gravel_Run_01.wav |
| Lily Pads / fire | leaves catching fire | -0.01 | 1055 | 0.60 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.58 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.51 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav |
| Smoke Screen / fire | smoke billowing out, a soft hiss | -0.01 | 1051 | 0.29 400 Sounds Pack/white_noise_long.wav; 0.29 400 Sounds Pack/light_match.wav; 0.28 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav |
| lab / book_open | a heavy book opening | 0.06 | 1041 | 0.30 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav; 0.30 oga/slime_10.ogg; 0.28 400 Sounds Pack/cardboard_box_close.wav |
| library / book_open | a heavy book opening | 0.06 | 1041 | 0.30 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav; 0.30 oga/slime_10.ogg; 0.28 400 Sounds Pack/cardboard_box_close.wav |
| spellbook / book_open | a heavy book opening | 0.06 | 1041 | 0.30 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav; 0.30 oga/slime_10.ogg; 0.28 400 Sounds Pack/cardboard_box_close.wav |
| Great Oak / fire | a tree catching fire | 0.01 | 1033 | 0.59 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.58 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.50 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav |
| Mirage / glass | a glassy shimmer fading away | -0.01 | 1012 | 0.33 oga/sfx100v2_misc_12.ogg; 0.28 oga/sfx100v2_loop_ambient_04.ogg; 0.27 400 Sounds Pack/steel_drums_level_complete.wav |
| swing_stair / rocks | a heavy stone staircase swinging and thudding | 0.02 | 991 | 0.38 oga/creature_misc_05.ogg; 0.35 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.32 NOX/Footsteps_MetalV2_Jump_Land_02.wav |
| mob_basic / shoot | a magical bolt being fired | 0.15 | 981 | 0.51 oga/creature_misc_05.ogg; 0.50 oga/creature_misc_04.ogg; 0.50 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav |
| mob_basic / rocks | a heavy stone blow | 0.17 | 966 | 0.49 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav; 0.48 extra96/bricks_place.wav; 0.48 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav |
| Great Oak / rocks | a heavy tree trunk crashing down, wood and earth thud | 0.18 | 952 | 0.62 NOX/Footsteps_Walk_Grass_Mono_33.wav; 0.60 NOX/Footsteps_Walk_Grass_Mono_31.wav; 0.59 NOX/Footsteps_Iceland_Jump_Land_Grass_Mono_02.wav |
| lab / chant | a bright magical chime, a spell succeeding | 0.08 | 927 | 0.53 400 Sounds Pack/steel_drums_chime_positive.wav; 0.52 400 Sounds Pack/vibraphone_chime_quick.wav; 0.51 oga/magical_1.ogg |
| rituals / chant | a bright magical chime, a spell succeeding | 0.08 | 927 | 0.53 400 Sounds Pack/steel_drums_chime_positive.wav; 0.52 400 Sounds Pack/vibraphone_chime_quick.wav; 0.51 oga/magical_1.ogg |
| Flare / fire | a small flame igniting, a lighter flicking on | -0.02 | 922 | 0.50 400 Sounds Pack/light_match.wav; 0.44 NOX/Electromagnetic_Fan_Idle_Loop_Mono_Elektrousi_01.wav; 0.42 oga/bfh1_wood_breaking_02.ogg |
| Liana / fire | a vine catching fire | 0.04 | 920 | 0.56 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.53 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.46 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav |
| coating / ice | a hiss of fire being put out by water | -0.02 | 919 | 0.37 oga/LEGIT_FIR_Fire_Staff 23-Audio.wav; 0.37 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.36 NOX/Ambiance_Fire_Big_Loop_Mono.wav |
| sky_cloud / spark | a small electric crackle | -0.03 | 914 | 0.32 NOX/Electromagnetic_Router_Internet_Loop_Mono_Elektrousi_02.wav; 0.29 NOX/Electromagnetic_Macbook_Idle_Loop_Mono_Elektrousi.wav; 0.29 NOX/Electromagnetic_Fan_Idle_Loop_Mono_Elektrousi_01.wav |
| intro / blink | a quick magical teleport blink | 0.18 | 877 | 0.49 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_04.wav; 0.47 NOX/Footsteps_Mud_Run_03.wav; 0.47 NOX/Footsteps_Iceland_Run_Grass_Mono_07.wav |
| Thorn Whip / whoosh | a whip cracking through the air | 0.08 | 848 | 0.44 extra96/beach_ball_catch.wav; 0.39 extra96/land_in_sand.wav; 0.38 NOX/Footsteps_Iceland_Run_Grass_Mono_07.wav |
| Oil Slick / mud | thick oil being poured and sloshing | -0.06 | 844 | 0.45 400 Sounds Pack/water_dripping.wav; 0.43 oga/loop_water_01.ogg; 0.43 oga/loop_water_03.ogg |
| Spore Puff / wind | a soft puff of air blowing spores | 0.04 | 794 | 0.32 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.32 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.29 oga/slime_01.ogg |
| Stonefall / rocks | a heavy boulder thudding onto the ground | 0.23 | 778 | 0.55 NOX/Footsteps_Walk_Grass_Mono_33.wav; 0.55 NOX/Footsteps_Gravel_Run_02.wav; 0.54 NOX/Footsteps_Walk_Grass_Mono_31.wav |
| intro / explosion | an explosion | 0.07 | 736 | 0.61 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.59 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.58 400 Sounds Pack/explosion_quick.wav |
| rituals / explosion | an explosion | 0.07 | 736 | 0.61 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.59 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.58 400 Sounds Pack/explosion_quick.wav |
| Flytrap / fire | a plant catching fire | 0.10 | 717 | 0.59 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.59 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.48 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav |
| avalanche / rumble | a rumbling avalanche of snow and rock | 0.05 | 683 | 0.67 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.60 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav; 0.58 NOX/Ambiance_Ocean_Ribeira_Grande_Loop_Stereo_02.wav |
| Black Hole / explosion | a dull implosion collapsing | 0.14 | 675 | 0.60 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.59 400 Sounds Pack/explosion_quick.wav; 0.58 400 Sounds Pack/explosion_large.wav |
| mob_basic / die | a creature dying, a collapse and groan | 0.19 | 658 | 0.46 NOX/Voice_Male_V1_Effort_Mono_05.wav; 0.45 extra96/human_gulp_2.wav; 0.45 NOX/Voice_Male_V2_Hit_Mono_08.wav |
| level_wall / chant | a bright magical chime | 0.13 | 628 | 0.53 400 Sounds Pack/steel_drums_chime_positive.wav; 0.51 400 Sounds Pack/vibraphone_chime_quick.wav; 0.49 oga/magical_6.ogg |
| match_end / chant | a bright magical chime | 0.13 | 628 | 0.53 400 Sounds Pack/steel_drums_chime_positive.wav; 0.51 400 Sounds Pack/vibraphone_chime_quick.wav; 0.49 oga/magical_6.ogg |
| arena / game_over | a somber low sting, game over | 0.16 | 619 | 0.48 oga/weird_05.ogg; 0.47 oga/creature_roar_03.ogg; 0.41 oga/creature_hurt_01.ogg |
| match_end / game_over | a somber low sting, game over | 0.16 | 619 | 0.48 oga/weird_05.ogg; 0.47 oga/creature_roar_03.ogg; 0.41 oga/creature_hurt_01.ogg |
| Supernova / fire | a roaring blaze of burning fire | 0.03 | 618 | 0.61 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.59 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav; 0.58 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav |
| Hemorrhage / blood | a wet bloody magical pulse | 0.11 | 573 | 0.42 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.42 oga/weird_03.ogg; 0.41 oga/monster_04.ogg |
| Wild Shape / summon | a magical transformation, a wild animal change | 0.18 | 536 | 0.47 400 Sounds Pack/ghost_long.wav; 0.46 oga/sfx100v2_misc_22.ogg; 0.44 400 Sounds Pack/grow_big.wav |
| mob_basic / whoosh | a whoosh of a blow through the air | 0.20 | 535 | 0.55 400 Sounds Pack/whoosh_2.wav; 0.49 oga/creature_monster_03.ogg; 0.47 oga/LEGIT_FIR_Fire_Staff 14-Audio.wav |
| page_pickup / rustle | a soft rustle of a page being picked up | 0.02 | 522 | 0.25 oga/book_04.ogg; 0.23 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.21 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| Bramble / rustle | thorny branches growing and rustling | 0.07 | 466 | 0.35 extra96/leaf_scrunch_2.wav; 0.33 NOX/Footsteps_Leaves_Run_05.wav; 0.30 extra96/football_hit_net.wav |
| Great Oak / rustle | leaves rustling as a huge tree grows | 0.08 | 452 | 0.41 oga/LEGIT_FIR_Fire_Staff 24-Audio.wav; 0.39 NOX/Ambiance_Wind_Forest_Loop_Stereo.wav; 0.38 400 Sounds Pack/ambient_wind.wav |
| Geyser / wind | steam hissing | 0.10 | 438 | 0.65 oga/sfx100v2_loop_ambient_01.ogg; 0.52 oga/sfx100v2_air_01.ogg; 0.44 oga/sfx100v2_air_03.ogg |
| wizard / land_gravel | a person landing on gravel after a jump | 0.30 | 423 | 0.56 NOX/Footsteps_Gravel_Walk_08.wav; 0.55 NOX/Footsteps_Gravel_Run_08.wav; 0.55 NOX/Footsteps_Sand_Walk_12.wav |
| Obsidian Armor / glass | glass or stone crystals clinking | 0.01 | 420 | 0.39 oga/bfh1_glass_hit_01.ogg; 0.37 400 Sounds Pack/keys_jingling.wav; 0.36 oga/glass_05.ogg |
| Insect Plague / hurt | a small insect buzz | 0.04 | 420 | 0.29 oga/alien_03.ogg; 0.22 oga/spring_08.ogg; 0.21 400 Sounds Pack/controller_button_press_2.wav |
| field_portal / portal_open | a magical portal humming open | 0.11 | 406 | 0.54 oga/sfx100v2_loop_ambient_04.ogg; 0.52 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.50 NOX/Ambiance_Cave_Dark_Loop_Stereo.wav |
| casting / rustle | a soft cloth rustle | 0.07 | 392 | 0.25 oga/sfx100v2_loop_ambient_03.ogg; 0.23 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.22 oga/sfx100v2_thunder_01.ogg |
| epilogue / rustle | a soft cloth rustle | 0.07 | 392 | 0.25 oga/sfx100v2_loop_ambient_03.ogg; 0.23 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.22 oga/sfx100v2_thunder_01.ogg |
| Pebble / rocks | a small stone hitting the ground | 0.22 | 391 | 0.51 oga/sfx100v2_stones_02.ogg; 0.47 NOX/Footsteps_Gravel_Run_10.wav; 0.45 oga/bfh1_rock_falling_06.ogg |
| wizard / step_wood | a single footstep on a wooden floor | 0.27 | 382 | 0.49 NOX/Footsteps_Rock_Run_01.wav; 0.46 NOX/Footsteps_Tile_Run_03.wav; 0.46 NOX/Footsteps_Rock_Run_06.wav |
| arena / rustle | a cloth rustle | 0.12 | 380 | 0.29 400 Sounds Pack/clothing_2.wav; 0.28 oga/sfx100v2_loop_ambient_03.ogg; 0.27 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| Oil Slick / fire | oil igniting with a whoomph | 0.14 | 371 | 0.41 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav; 0.40 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.39 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav |
| Push / whoosh | a strong blast of air pushing, a heavy whoomph | 0.20 | 344 | 0.45 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav; 0.44 NOX/Ambiance_Sea_Strong_Kirkjufjara_Far_Loop_Stereo_02.wav; 0.44 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav |
| Flytrap / jaw_snap | jaws snapping shut | 0.14 | 337 | 0.50 oga/bug_04.ogg; 0.43 extra96/human_gulp_2.wav; 0.41 oga/bug_01.ogg |
| Firewall / fire | fire igniting with a whoomph | 0.18 | 331 | 0.61 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.60 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.59 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| Wild Shape / hurt | a wolf claw swipe and growl | 0.21 | 330 | 0.48 oga/bug_04.ogg; 0.48 NOX/Voice_Male_V2_Attack_Mono_02.wav; 0.47 extra96/human_gulp_2.wav |
| Great Oak / rumble | a deep rumble as a tree crashes to the ground | 0.19 | 327 | 0.58 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.56 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.53 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| wizard / step_rock | a single footstep on rock | 0.30 | 324 | 0.54 NOX/Footsteps_Gravel_Run_08.wav; 0.51 NOX/Footsteps_Gravel_Walk_05.wav; 0.51 NOX/Footsteps_Gravel_Walk_08.wav |
| tutorial / portal_enter | a magical whoosh as someone steps through a portal | 0.25 | 309 | 0.48 oga/monster_01.ogg; 0.48 NOX/Voice_Male_V2_Sigh_Mono_06.wav; 0.44 oga/creature_monster_03.ogg |
| world_stages / portal_enter | a magical whoosh as someone steps through a portal | 0.25 | 309 | 0.48 oga/monster_01.ogg; 0.48 NOX/Voice_Male_V2_Sigh_Mono_06.wav; 0.44 oga/creature_monster_03.ogg |
| Scythe / blood | a scythe blade swinging through the air with a slicing swish | 0.25 | 288 | 0.65 400 Sounds Pack/whoosh_2.wav; 0.61 oga/LEGIT_FIR_Fire_Staff 14-Audio.wav; 0.61 oga/eat_03.ogg |
| arena / ice | a fizzle, a fire hissing out in water | 0.10 | 282 | 0.56 oga/LEGIT_FIR_Fire_Staff 23-Audio.wav; 0.52 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.50 NOX/Ambiance_Fire_Big_Loop_Mono.wav |
| wizard / land_leaves | a person landing on dry leaves after a jump | 0.31 | 282 | 0.50 NOX/Footsteps_Iceland_Walk_Grass_Mono_09.wav; 0.46 NOX/Footsteps_Iceland_Run_Black_Pebble_Mono_07.wav; 0.46 NOX/Footsteps_Leaves_Run_05.wav |
| intro / whoosh | a heavy whoosh of air pushing someone | 0.23 | 272 | 0.45 NOX/Voice_Female_V1_Sigh_Mono_11.wav; 0.41 oga/LEGIT_FIR_Fire_Staff 16-Audio.wav; 0.41 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav |
| Ignite / cast | a ball of fire thrown, a whoosh of flame | 0.33 | 270 | 0.71 NOX/Footsteps_Rock_Jump_Start_01.wav; 0.66 NOX/Footsteps_Iceland_Jump_Land_Snow_Grass_Mono_02.wav; 0.66 oga/LEGIT_FIR_Fire_Staff 13-Audio.wav |
| wizard / land_dirt | a person landing on dirt after a jump | 0.37 | 270 | 0.54 NOX/Footsteps_Walk_Grass_Mono_05.wav; 0.52 NOX/Footsteps_Walk_Grass_Mono_33.wav; 0.51 NOX/Footsteps_Walk_Grass_Mono_01.wav |
| coating / fire | a body bursting into flame, a whoosh of fire | 0.23 | 259 | 0.59 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.58 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.53 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| Flaming Sphere / fire | a ball of fire rolling and burning | 0.10 | 256 | 0.66 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.62 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav; 0.60 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav |
| wizard / land_snow | a person landing in snow after a jump | 0.34 | 256 | 0.51 NOX/Footsteps_Snow_Run_10.wav; 0.50 NOX/Footsteps_Snow_Walk_06.wav; 0.50 NOX/Footsteps_Walk_Grass_Mono_05.wav |
| wizard / land_rock | a person landing on rock after a jump | 0.30 | 239 | 0.47 NOX/Footsteps_Walk_Grass_Mono_05.wav; 0.46 NOX/Footsteps_Gravel_Run_08.wav; 0.46 NOX/Footsteps_Walk_Grass_Mono_33.wav |
| wizard / step_grass | a single footstep on grass | 0.37 | 238 | 0.51 NOX/Footsteps_Mud_Run_07.wav; 0.51 NOX/Footsteps_Mud_Run_03.wav; 0.50 NOX/Footsteps_Iceland_Walk_Grass_Mono_09.wav |
| pond / ice | water freezing over, a crackling cold | 0.11 | 229 | 0.47 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav; 0.44 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.44 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav |
| portal_collapse / portal_enter | a magical whoosh as someone is pulled through a portal | 0.23 | 225 | 0.44 oga/creature_monster_03.ogg; 0.43 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.43 oga/sfx100v2_misc_37.ogg |
| Crimson Veil / blood | a wet magical blood swirl | 0.21 | 221 | 0.50 oga/monster_01.ogg; 0.46 oga/misc_07.ogg; 0.45 oga/monster_02.ogg |
| intro / volcano | a deep groan and rumble of the earth | 0.11 | 218 | 0.56 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.50 NOX/Ambiance_Cave_Deep_Loop_Stereo.wav; 0.50 NOX/Ambiance_Cave_Dark_Loop_Stereo.wav |
| wizard / land_mud | a person landing in mud after a jump | 0.31 | 215 | 0.51 NOX/Footsteps_Mud_Run_07.wav; 0.51 oga/splash_14.ogg; 0.50 oga/splash_01.ogg |
| wizard / land_wood | a person landing on a wooden floor after a jump | 0.36 | 215 | 0.56 NOX/Footsteps_Walk_Grass_Mono_05.wav; 0.52 NOX/Footsteps_Iceland_Jump_Land_Grass_Mono_01.wav; 0.50 NOX/Footsteps_MetalV1_Walk_13.wav |
| Mudslide / mud | a squelch of a foot in thick mud | 0.32 | 211 | 0.61 400 Sounds Pack/splat_quick.wav; 0.60 oga/bubble_03.ogg; 0.58 NOX/Footsteps_Mud_Walk_01.wav |
| wizard / step_dirt | a single footstep on dirt | 0.46 | 206 | 0.62 NOX/Footsteps_Gravel_Run_08.wav; 0.60 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_07.wav; 0.60 NOX/Footsteps_Sand_Run_09.wav |
| Flytrap / chomp | a plant snapping shut with a wet chomp | 0.28 | 195 | 0.48 NOX/Footsteps_Mud_Walk_10.wav; 0.46 400 Sounds Pack/squelching_1.wav; 0.46 NOX/Footsteps_Mud_Walk_01.wav |
| lava_ball / fire | a ball of molten lava splashing, a hiss and burst of fire | 0.16 | 187 | 0.51 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav; 0.51 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.49 NOX/Ambiance_Hot_Spring_Furnas_Caldeiras_Loop_Stereo_04.wav |
| mob_basic / summon | a magical arrival, a creature appearing in a swirl of magic | 0.31 | 178 | 0.45 400 Sounds Pack/steel_drums_chime_positive.wav; 0.44 400 Sounds Pack/sitar_chime_positive.wav; 0.44 NOX/Voice_Male_V2_Sigh_Mono_06.wav |
| intro / hurt | a creature grunting in pain | 0.24 | 174 | 0.39 oga/monster_07.ogg; 0.38 NOX/Voice_Male_V1_Effort_Mono_05.wav; 0.38 oga/misc_08.ogg |
| mob_basic / hurt | a creature grunting in pain | 0.24 | 174 | 0.39 oga/monster_07.ogg; 0.38 NOX/Voice_Male_V1_Effort_Mono_05.wav; 0.38 oga/misc_08.ogg |
| Barrier / barrier | a magical shield bubble forming, a soft shimmer | 0.22 | 169 | 0.36 oga/bubble_01.ogg; 0.35 400 Sounds Pack/pop_3.wav; 0.35 400 Sounds Pack/pop_1.wav |
| Leech / blood | a wet draining magical pulse | 0.20 | 157 | 0.43 oga/monster_04.ogg; 0.40 oga/creature_misc_03.ogg; 0.40 oga/alien_01.ogg |
| Stone Wall / rocks | a heavy slab of stone grinding up from the ground | 0.23 | 151 | 0.55 extra96/stone_scrape_2.wav; 0.51 oga/spell_fire_03.ogg; 0.49 400 Sounds Pack/stone_push_long.wav |
| falling_rock / rocks | a rock falling and hitting the ground | 0.30 | 147 | 0.49 NOX/Footsteps_Gravel_Run_10.wav; 0.49 oga/sfx100v2_stones_02.ogg; 0.47 oga/bfh1_rock_breaking_01.ogg |
| Sinkhole / rumble | a rumble of the ground collapsing | 0.20 | 126 | 0.50 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.45 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.42 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| eruption / volcano | a volcano erupting, a deep roaring blast | 0.15 | 124 | 0.52 NOX/Ambiance_Cave_Deep_Loop_Stereo.wav; 0.50 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.47 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav |
| Lily Pads / wind | a soft breeze over water | 0.11 | 114 | 0.24 oga/sfx100v2_thunder_01.ogg; 0.24 oga/sfx100v2_loop_ambient_03.ogg; 0.23 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| ice_plug / ice | water freezing solid | 0.20 | 103 | 0.54 NOX/Ambiance_Hot_Spring_Furnas_Caldeiras_Loop_Stereo_04.wav; 0.52 NOX/Ambiance_Hot_Spring_Furnas_Caldeiras_Loop_Stereo_03.wav; 0.49 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav |
| wizard / land_tile | a person landing on a stone floor after a jump | 0.42 | 101 | 0.57 NOX/Footsteps_Walk_Grass_Mono_05.wav; 0.55 NOX/Footsteps_Gravel_Run_10.wav; 0.54 NOX/Footsteps_Gravel_Run_08.wav |
| Earthquake / rumble | a deep earthquake rumble shaking the ground | 0.23 | 95 | 0.53 NOX/Ambiance_Cave_Deep_Loop_Stereo.wav; 0.49 NOX/Ambiance_Hot_Spring_Furnas_Caldeiras_Loop_Stereo_04.wav; 0.48 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav |
| Stone Wall / rumble | a deep rumble as the ground heaves | 0.19 | 89 | 0.50 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.50 NOX/Ambiance_Cave_Deep_Loop_Stereo.wav; 0.46 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav |
| Sinkhole / rocks | earth and rocks crumbling into a pit | 0.24 | 88 | 0.43 NOX/Ambiance_Hot_Spring_Furnas_Caldeiras_Loop_Stereo_04.wav; 0.41 oga/stones_03.ogg; 0.40 NOX/Ambiance_Hot_Spring_Furnas_Caldeiras_Loop_Stereo_03.wav |
| Thunderclap / rumble | a rumble of thunder | 0.14 | 80 | 0.51 oga/sfx100v2_thunder_01.ogg; 0.45 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.45 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| Ignite / fire | a fireball exploding on impact, a burst of flame | 0.42 | 80 | 0.65 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.63 NOX/Footsteps_Iceland_Jump_Land_Snow_Grass_Mono_03.wav; 0.62 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| Updraft / whirl | a column of rising wind | 0.16 | 79 | 0.54 NOX/Atmosphere_Drone_Hum_Eerie_Loop_Stereo.wav; 0.52 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.52 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav |
| Crimson Veil / glass | a glassy crack as a blow is negated | 0.24 | 78 | 0.40 oga/bfh1_rock_breaking_01.ogg; 0.37 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.36 oga/LEGIT_FIR_Fire_Staff 8-Audio.wav |
| gas_bank / fire | gas igniting with a whoomph | 0.30 | 74 | 0.64 oga/sfx100v2_air_01.ogg; 0.62 oga/LEGIT_FIR_Fire_Staff 8-Audio.wav; 0.62 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| Eldritch Blast / blast | a crackling beam of dark magical energy | 0.31 | 65 | 0.46 oga/alien_01.ogg; 0.44 NOX/Footsteps_Mud_Walk_05.wav; 0.42 oga/alien_03.ogg |
| rock_wall / rumble | a deep rumble of a wall collapsing | 0.24 | 59 | 0.57 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.56 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.48 400 Sounds Pack/explosion_quick.wav |
| Invincible Snail / summon | a slow eerie magical summoning | 0.20 | 56 | 0.56 oga/sfx100v2_loop_ambient_04.ogg; 0.46 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.42 oga/sfx100v2_misc_37.ogg |
| epilogue / summon | a slow eerie magical summoning | 0.20 | 56 | 0.56 oga/sfx100v2_loop_ambient_04.ogg; 0.46 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.42 oga/sfx100v2_misc_37.ogg |
| wizard / step_snow | a single footstep in snow | 0.51 | 50 | 0.59 NOX/Footsteps_Iceland_Walk_Snow_Hard_Mono_04.wav; 0.57 NOX/Footsteps_Sand_Walk_08.wav; 0.57 NOX/Footsteps_Iceland_Run_Gravel_Frozen_Mono_06.wav |
| wizard / step_leaves | a single footstep on dry leaves | 0.45 | 49 | 0.51 NOX/Footsteps_Iceland_Walk_Grass_Mono_09.wav; 0.51 NOX/Footsteps_Leaves_Run_01.wav; 0.51 NOX/Footsteps_Mud_Walk_07.wav |
| wizard / step_tile | a single footstep on a stone tile floor | 0.45 | 48 | 0.56 NOX/Footsteps_Gravel_Run_08.wav; 0.55 NOX/Footsteps_Tile_Run_03.wav; 0.55 NOX/Footsteps_Gravel_Run_10.wav |
| Stalagmite / rocks | stone spikes thrusting up from the ground, rock cracking | 0.28 | 43 | 0.45 oga/stones_03.ogg; 0.45 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav; 0.44 400 Sounds Pack/drink_slurp.wav |
| Tornado / whirl | a howling tornado, a whirling roaring wind | 0.28 | 38 | 0.68 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.62 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav; 0.58 NOX/Ambiance_Sea_Strong_Kirkjufjara_Far_Loop_Stereo_01.wav |
| wizard / summon | a magical arrival, a person appearing in a swirl of magic | 0.37 | 38 | 0.49 400 Sounds Pack/steel_drums_chime_positive.wav; 0.48 400 Sounds Pack/sitar_chime_positive.wav; 0.46 oga/magical_1.ogg |
| Water Jet / jet | a hard jet of water spraying from a hose | 0.32 | 31 | 0.52 NOX/Ambiance_Waterfall_Big_Skógafoss_Far_Loop_Stereo_02.wav; 0.51 NOX/Ambiance_Waterfall_Moihnos_Cascata_do_Limbo_Loop_Stereo.wav; 0.51 NOX/Ambiance_Waterfall_Big_Skógafoss_Far_Loop_Stereo_01.wav |
| hud / click | a short soft interface click | 0.33 | 26 | 0.50 400 Sounds Pack/select_2.wav; 0.49 oga/creature_misc_02.ogg; 0.48 400 Sounds Pack/wobble.wav |
| library / click | a short soft interface click | 0.33 | 26 | 0.50 400 Sounds Pack/select_2.wav; 0.49 oga/creature_misc_02.ogg; 0.48 400 Sounds Pack/wobble.wav |
| likeness_panel / click | a short soft interface click | 0.33 | 26 | 0.50 400 Sounds Pack/select_2.wav; 0.49 oga/creature_misc_02.ogg; 0.48 400 Sounds Pack/wobble.wav |
| menu / click | a short soft interface click | 0.33 | 26 | 0.50 400 Sounds Pack/select_2.wav; 0.49 oga/creature_misc_02.ogg; 0.48 400 Sounds Pack/wobble.wav |
| settings / click | a short soft interface click | 0.33 | 26 | 0.50 400 Sounds Pack/select_2.wav; 0.49 oga/creature_misc_02.ogg; 0.48 400 Sounds Pack/wobble.wav |
| Blizzard / wind | a cold howling snowstorm wind | 0.33 | 25 | 0.63 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.56 NOX/Ambiance_Sea_Strong_Reynisdrangar_Loop_Stereo.wav; 0.55 NOX/Ambiance_Sea_Strong_Kirkjufjara_Far_Loop_Stereo_01.wav |
| wizard / land_grass | a person landing on grass after a jump | 0.42 | 22 | 0.47 NOX/Footsteps_Walk_Grass_Mono_01.wav; 0.47 NOX/Footsteps_Walk_Grass_Mono_05.wav; 0.47 NOX/Footsteps_Iceland_Walk_Grass_Mono_09.wav |
| Golem / rocks | heavy rocks grinding and stacking | 0.36 | 20 | 0.51 oga/stones_03.ogg; 0.43 extra96/bricks_crunchy.wav; 0.43 extra96/stone_on_stone.wav |
| library / page | a paper page turning | 0.23 | 18 | 0.41 oga/book_04.ogg; 0.37 oga/book_01.ogg; 0.33 extra96/page_turn.wav |
| spellbook / page | a paper page turning | 0.23 | 18 | 0.41 oga/book_04.ogg; 0.37 oga/book_01.ogg; 0.33 extra96/page_turn.wav |
| Stonefall / rumble | a deep rumble of a boulder landing | 0.35 | 17 | 0.53 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.49 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.43 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| Tide Surf / sea | ocean waves rolling and surging | 0.40 | 17 | 0.67 NOX/Ambiance_Ocean_Praia_dos_Moinhos_Loop_Stereo_01.wav; 0.66 NOX/Ambiance_Sea_Strong_Vik_Close_Loop_Stereo_01.wav; 0.66 NOX/Ambiance_Sea_Strong_Vik_Far_Loop_Stereo_02.wav |
| Fire Breath / breath | a roaring jet of flame from a flamethrower | 0.45 | 17 | 0.52 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.51 oga/LEGIT_FIR_Fire_Staff 3-Audio.wav; 0.51 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav |
| Rocket Jump / breath | a roaring rocket blast of flame lifting off | 0.38 | 16 | 0.61 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.57 oga/LEGIT_FIR_Fire_Staff 19-Audio.wav; 0.50 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| Golem / rumble | a deep rumble of earth as a stone giant rises | 0.38 | 15 | 0.56 NOX/Ambiance_Cave_Deep_Loop_Stereo.wav; 0.56 NOX/Ambiance_Cave_Dark_Loop_Stereo.wav; 0.52 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav |
| intro / page | a paper page turning | 0.25 | 11 | 0.41 oga/book_04.ogg; 0.37 oga/book_01.ogg; 0.33 extra96/page_turn.wav |
| epilogue / book_close | a heavy book closing | 0.31 | 11 | 0.37 oga/creature_misc_05.ogg; 0.36 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_10.wav; 0.35 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| library / book_close | a heavy book closing | 0.31 | 11 | 0.37 oga/creature_misc_05.ogg; 0.36 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_10.wav; 0.35 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| spellbook / book_close | a heavy book closing | 0.31 | 11 | 0.37 oga/creature_misc_05.ogg; 0.36 NOX/Footsteps_Iceland_Walk_Gravel_Wet_Mono_10.wav; 0.35 oga/LEGIT_FIR_Fire_Staff 1-Audio.wav |
| wizard / step_mud | a single footstep squelching in mud | 0.61 | 9 | 0.68 NOX/Footsteps_Mud_Walk_01.wav; 0.67 NOX/Footsteps_Mud_Walk_08.wav; 0.64 400 Sounds Pack/splat_quick.wav |
| rock_wall / rocks | rocks crumbling and falling apart | 0.45 | 5 | 0.54 oga/stones_03.ogg; 0.47 oga/stones_01.ogg; 0.47 oga/coldsnap.wav |
| Firewall / burn | a wall of fire roaring and crackling | 0.47 | 5 | 0.64 NOX/Ambiance_Firecamp_Medium_Loop_Mono.wav; 0.63 NOX/Ambiance_Fire_Big_Loop_Mono.wav; 0.60 NOX/Ambiance_Firecamp_Small_Loop_Mono.wav |
| wizard / step_gravel | a single footstep on gravel | 0.62 | 2 | 0.63 NOX/Footsteps_Gravel_Run_07.wav; 0.62 NOX/Footsteps_Gravel_Run_08.wav; 0.62 NOX/Footsteps_Gravel_Walk_05.wav |
| Hunter's Mark / heartbeat | a slow heartbeat | 0.34 | 1 | 0.38 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.33 oga/monster_04.ogg; 0.29 oga/monster_07.ogg |
| Raise Dead / rise | earth cracking open as something rises from the grave, rumble and creaking | 0.45 | 1 | 0.51 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.45 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav; 0.41 oga/sfx100v2_loop_ambient_03.ogg |
| Spark / spark | a lightning strike, a sharp crack of thunder | 0.47 | 1 | 0.50 oga/sfx100v2_thunder_01.ogg; 0.45 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.43 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav |
| Ice Prison / ice | water freezing solid into a block of ice, a cold crystallizing | 0.47 | 1 | 0.48 oga/stones_03.ogg; 0.47 oga/freeze.wav; 0.46 oga/LEGIT_FIR_Fire_Staff 23-Audio.wav |
| Adrenaline / heartbeat | a fast pounding heartbeat | 0.46 | 0 | 0.36 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.34 NOX/Ambiance_Cave_Dark_Loop_Stereo.wav; 0.28 400 Sounds Pack/toggle_on.wav |
| Fight or Flight / heartbeat | a fast pounding heartbeat | 0.46 | 0 | 0.36 NOX/Ambiance_Cave_Drips_Loop_Stereo.wav; 0.34 NOX/Ambiance_Cave_Dark_Loop_Stereo.wav; 0.28 400 Sounds Pack/toggle_on.wav |
| intro / thunder | a rumble and crack of thunder | 0.50 | 0 | 0.50 oga/sfx100v2_thunder_01.ogg; 0.44 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.43 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav |
| Hailstorm / thunder | a rumble of storm thunder | 0.50 | 0 | 0.50 oga/sfx100v2_thunder_01.ogg; 0.44 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.44 NOX/Ambiance_Wind_Calm_Loop_Stereo.wav |
| portal_collapse / thunder | distant thunder | 0.50 | 0 | 0.50 oga/sfx100v2_thunder_01.ogg; 0.38 oga/sfx100v2_loop_ambient_03.ogg; 0.36 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| Geyser / geyser | a jet of scalding water bursting up from the ground | 0.51 | 0 | 0.43 NOX/Ambiance_Waterfall_Moihnos_Cascata_do_Limbo_Loop_Stereo.wav; 0.42 NOX/Ambiance_Waterfall_Ribeira_dos_CaldeirΣes_Loop_Stereo.wav; 0.42 NOX/Ambiance_Ocean_Ribeira_Grande_Loop_Stereo_01.wav |
| Thunderclap / thunder | a loud clap of thunder | 0.51 | 0 | 0.51 oga/sfx100v2_thunder_01.ogg; 0.47 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav; 0.47 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav |
| sky_cloud / thunder | a crack of thunder | 0.52 | 0 | 0.52 oga/sfx100v2_thunder_01.ogg; 0.44 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.44 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
| world_stages / thunder | a crack of thunder | 0.52 | 0 | 0.52 oga/sfx100v2_thunder_01.ogg; 0.44 oga/LEGIT_FIR_Fire_Staff 17-Audio.wav; 0.44 oga/LEGIT_FIR_Fire_Staff 18-Audio.wav |
