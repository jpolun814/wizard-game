class_name MobKind
extends Resource

## One kind of enemy, as data: how tough, fast and hard-hitting it is, its school and weakness, its art and what it shoots. Each
## lives in its own file in res://mobs/ and Mob.KINDS finds them by scanning that folder.

@export var id := ""                 ## the name the game summons it by
@export var sort_order := 0          ## where it comes in the summon menu
@export var display_name := ""
@export_multiline var desc := ""     ## what the debug panel and Insight say about it
@export_enum("melee", "ranged", "flyer", "wizard") var role := "melee"
@export var art := "skeleton"        ## the folder of frames in art/chars or art/mobs
@export var scale := 1.0
@export var hp := 30
@export var school := ""
@export var weak := ""    ## the school it takes extra damage from, if any
@export var resist := ""  ## and the one it takes none from, if any
@export var damage := 0
@export var speed := 1.0
@export var effect := ""             ## the special behaviour: burning, explode, smash, dummy...
@export var shot := {}               ## what a ranged or flying one fires: interval, damage and the flags it needs
