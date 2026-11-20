class_name Damage
extends RefCounted

## What KIND of harm a blow is, and the laws about it. A spell has a school (the color of its magic), but what a blow DOES to a body comes from its kind:
##   heat       sets a body alight (unless it is wet)
##   lightning  strikes a wet body harder
##   force      shatters a body that is frozen
##   cold, piercing, dark and blood harm and nothing more (their effects are the spell's own: a chill, a bleed)
## The laws read the kind and never the school or the spell. A school gives its blows a kind here and nowhere else (`OF_SCHOOL`); a blow that is of another kind
## than its school's (a bolt of lightning, which is Fire's) says so by being in the group "lightning".

const HEAT := "heat"
const COLD := "cold"
const FORCE := "force"
const LIGHTNING := "lightning"
const PIERCING := "piercing"
const DARK := "dark"
const BLOOD := "blood"

const OF_SCHOOL := {"Fire": HEAT, "Water": COLD, "Air": FORCE, "Earth": FORCE, "Flora": PIERCING, "Shadow": DARK, "Blood": BLOOD}
const SHATTER := 1.5   # how much harder a frozen body is struck by force, as it breaks out of the ice


## The kind of a blow struck by something (a spell, a creature) of a school.
static func kind_of(school: String, by: Node = null) -> String:
	if is_instance_valid(by) and by.is_in_group("lightning"):
		return LIGHTNING
	return OF_SCHOOL.get(school, "")


## What a blow of this kind does to a body besides its harm, before the harm is dealt: the damage left to deal. Works on any body, a wizard or a creature.
static func laws(body: Node, amount: int, kind: String, by: Node = null) -> int:
	match kind:
		LIGHTNING:
			amount = Substances.shocked(body, amount)
		HEAT:
			Substances.ignite(body, Substances.BURN_SECONDS, by)
	return amount


## Whether a blow of this kind breaks a body out of the ice.
static func shatters(kind: String) -> bool:
	return kind == FORCE
