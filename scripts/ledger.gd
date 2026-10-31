class_name Ledger
extends RefCounted

## What one wizard has in their spellbook: the pages they hold. A spell or chant can only be cast once its page is here. In the waiting
## room the ledger is everything: every page is known. A page is a spell's name, or "chant:" and a chant's id (the Mark and the Return
## share one page, the Mark's).

var everything := false  # the waiting room: no page is missing
var pages := {}          # page -> true
var settled := {}        # chant id -> true, for the chants that, once said, hold for the rest of the match (see Ledger.LASTING)

## The chants that are said once: the gift stays, through every world of the match.
const LASTING := ["minimap", "insight", "double_jump", "haste"]


## A ledger that holds every page, for the waiting room.
static func complete() -> Ledger:
	var ledger := Ledger.new()
	ledger.everything = true
	return ledger


## A ledger that holds only these pages.
static func of(starters: Array) -> Ledger:
	var ledger := Ledger.new()
	for page in starters:
		ledger.pages[page] = true
	return ledger


func knows(page: String) -> bool:
	return everything or pages.has(page)


## A spell, by its name.
func knows_spell(spell: String) -> bool:
	return knows(spell)


## A chant, by its id.
func knows_chant(ritual_id: String) -> bool:
	return knows("chant:" + ("mark" if ritual_id == "recall" else ritual_id))


## A chant of the LASTING kind has been said: its gift stays from now on.
func settle(ritual_id: String) -> void:
	if LASTING.has(ritual_id):
		settled[ritual_id] = true


func is_settled(ritual_id: String) -> bool:
	return settled.has(ritual_id)


func learn(page: String) -> void:
	pages[page] = true


func learn_all() -> void:
	for page in Pages.every():
		pages[page] = true


## How many pages are held.
func count() -> int:
	return Pages.every().size() if everything else pages.size()
