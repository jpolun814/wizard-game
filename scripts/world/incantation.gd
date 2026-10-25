class_name Incantation
extends RefCounted

## A world's seed, spoken as four Latin-sounding words. Every seed has exactly one incantation and every incantation
## is exactly one seed, so a player can share a world by its words. Anything else typed is turned into a seed too, so
## nothing typed is refused, and typing nothing gives a random world.

const WORDS := [
	"aqua", "umbra", "lux", "ignis", "terra", "ventus", "nox", "luna",
	"sol", "stella", "mare", "mons", "silva", "flos", "lapis", "ferrum",
	"aurum", "sanguis", "ossa", "cinis", "fumus", "glacies", "nebula", "tonitrus",
	"fulgur", "umbrae", "somnus", "vox", "umbo", "turris", "pons", "porta",
	"via", "iter", "specus", "antrum", "fons", "rivus", "lacus", "palus",
	"arbor", "radix", "folium", "spina", "corvus", "lupus", "ursus", "draco",
	"serpens", "noctua", "aranea", "vesper", "aurora", "tenebrae", "silentium", "memoria",
	"oblivio", "fatum", "vigil", "custos", "rex", "regina", "magus", "umbrarum",
]
const COUNT := 4  # words in an incantation

static func seed_count() -> int:
	return int(pow(WORDS.size(), COUNT))


## True when the text is exactly four of the words, which is how a world is named.
static func is_world_name(text: String) -> bool:
	var words := text.strip_edges().to_lower().split(" ", false)
	if words.size() != COUNT:
		return false
	for word in words:
		if not WORDS.has(word):
			return false
	return true


## The seed a typed incantation means. Four known words are decoded exactly; any other text is hashed to a seed; blank
## text is a random seed.
static func seed_of(text: String) -> int:
	var cleaned := text.strip_edges().to_lower()
	if cleaned.is_empty():
		return randi() % seed_count()
	var words := cleaned.split(" ", false)
	if words.size() == COUNT:
		var value := 0
		var known := true
		for word in words:
			var at := WORDS.find(word)
			if at < 0:
				known = false
				break
			value = value * WORDS.size() + at
		if known:
			return value
	return absi(cleaned.hash()) % seed_count()


## The four words of a seed.
static func words_for(seed_value: int) -> String:
	var rest := seed_value % seed_count()
	var out: Array[String] = []
	for i in COUNT:
		out.push_front(WORDS[rest % WORDS.size()])
		rest /= WORDS.size()
	return " ".join(out)
