extends RefCounted

# Fixed visual anchors and connected-floor approaches for optional hauntings.
const LANDMARKS := [
	{
		"id":"portrait", "name":"The Watching Portrait", "prompt":"Study the watching portrait",
		"pos":Vector2(1040, 175), "reach":90.0, "marker_anchor":Vector2(1024, 109),
		"approach":Vector2(1040, 197),
		"lines":[
			"The lady in the frame sighs. 'Do straighten your hat. We have standards, even after death.'",
			"Her eyes follow you. 'Of course I stare, dear. Nobody brings me a book.'",
			"A painted hand points toward the foyer. 'Four keepsakes. One brew. Then kindly let us sleep.'",
		],
	},
	{
		"id":"piano", "name":"The Phantom Piano", "prompt":"Listen to the phantom piano",
		"pos":Vector2(1090, 487), "reach":92.0, "marker_anchor":Vector2(1128, 439),
		"approach":Vector2(1030, 500),
		"lines":[
			"One key plays by itself. The next note is a tiny, offended sneeze.",
			"A ghostly pianist whispers: 'Requests cost a shilling. Complaints cost two.'",
			"The sheet music is titled A Minor Inconvenience. Every note is a boo.",
		],
	},
	{
		"id":"clock", "name":"The Thirteenth-Hour Clock", "prompt":"Inspect the haunted clock",
		"pos":Vector2(1408, 490), "reach":88.0, "marker_anchor":Vector2(1408, 439),
		"approach":Vector2(1340, 495),
		"lines":[
			"It strikes thirteen. A voice inside mutters: 'Daylight haunting time. Terrible business.'",
			"The pendulum swings backward. 'You are not late,' says the clock. 'Yesterday is early.'",
			"A little brass plaque reads: Winding optional. Existential dread included.",
		],
	},
	{
		"id":"oven", "name":"The Haunted Hearth", "prompt":"Warm your hands by the haunted hearth",
		"pos":Vector2(198, 697), "reach":88.0, "marker_anchor":Vector2(186, 664),
		"approach":Vector2(230, 730),
		"lines":[
			"Something in the chimney asks for toast. 'Lightly frightened, please.'",
			"The kettle whistles a funeral march, then apologizes. It meant to make tea.",
			"A recipe card says: Add one pinch of salt. Do not add the cook. Again.",
		],
	},
	# Additional hauntings throughout the manor.
	{
		"id":"supper_table", "name":"The Eternal Supper", "prompt":"Inspect the eternal supper",
		"pos":Vector2(300, 242), "reach":94.0, "marker_anchor":Vector2(315, 219),
		"approach":Vector2(306, 308),
		"lines":[
			"The flowers look fresh, which is rude of them at this hour.",
			"Four candles burn bravely; none recalls who set the table.",
			"Dinner is late again. The ghosts blame the soup, naturally.",
		],
	},
	{
		"id":"sideboard", "name":"The Midnight Sideboard", "prompt":"Inspect the midnight sideboard",
		"pos":Vector2(295, 144), "reach":86.0, "marker_anchor":Vector2(290, 116),
		"approach":Vector2(370, 166),
		"lines":[
			"The crockery has survived three hauntings and one dreadful potluck.",
			"Pumpkins on parade, each grinning like it knows the punchline.",
			"A plate whispers that porcelain is simply crockery with ambitions.",
		],
	},
	{
		"id":"mirror", "name":"The Looking-Back Glass", "prompt":"Peer into the haunted mirror",
		"pos":Vector2(1380, 183), "reach":100.0, "marker_anchor":Vector2(1388, 163),
		"approach":Vector2(1310, 218),
		"lines":[
			"The oval shows a ghostly guest who insists she is your better side.",
			"Its glow is flattering, though it makes every eyebrow look haunted.",
			"A very pale reflection bows first. Good manners are not dead.",
		],
	},
	{
		"id":"bookshelf", "name":"The Forbidden Books", "prompt":"Browse the forbidden books",
		"pos":Vector2(390, 410), "reach":87.0, "marker_anchor":Vector2(390, 377),
		"approach":Vector2(399, 449),
		"lines":[
			"The forbidden books are shelved by danger, then alphabetically.",
			"One dusty volume warns, 'Do not open.' How refreshingly clear.",
			"Even the spines look nervous when the librarian is nearby.",
		],
	},
	{
		"id":"writing_desk", "name":"The Unfinished Letter", "prompt":"Read the unfinished letter",
		"pos":Vector2(204, 445), "reach":81.0, "marker_anchor":Vector2(210, 413),
		"approach":Vector2(201, 495),
		"lines":[
			"The abandoned notes end mid-sentence, then resume with better penmanship.",
			"Someone wrote, 'Dear diary,' and immediately lost their nerve.",
			"Ink stains gather like tiny ghosts with unfinished business.",
		],
	},
	{
		"id":"globe", "name":"The Wandering Globe", "prompt":"Inspect the wandering globe",
		"pos":Vector2(279, 449), "reach":75.0, "marker_anchor":Vector2(278, 429),
		"approach":Vector2(302, 495),
		"lines":[
			"The globe marks every place the manor has never been invited.",
			"Its oceans look calm; the continents are plainly plotting something.",
			"A careful spin reveals no country named Somewhere Sensible.",
		],
	},
	{
		"id":"fireplace", "name":"The Parlor Fireplace", "prompt":"Listen to the parlor fireplace",
		"pos":Vector2(1300, 428), "reach":83.0, "marker_anchor":Vector2(1300, 425),
		"approach":Vector2(1265, 474),
		"lines":[
			"The flames keep a warm little secret and refuse to share it.",
			"Ash settles like gray snow, very cozy and slightly judgmental.",
			"The hearth has heard every parlor tale and still wants one more.",
		],
	},
	{
		"id":"armchair", "name":"The Vacant Armchair", "prompt":"Inspect the vacant armchair",
		"pos":Vector2(1375, 563), "reach":70.0, "marker_anchor":Vector2(1364, 530),
		"approach":Vector2(1330, 516),
		"lines":[
			"The green cushions sag as if someone invisible has just stood up.",
			"Apparently empty, though the upholstery has excellent posture.",
			"A chair this dignified must be hiding a very small aristocrat.",
		],
	},
	{
		"id":"dollhouse", "name":"The Little Haunted House", "prompt":"Peek inside the dollhouse",
		"pos":Vector2(1006, 690), "reach":76.0, "marker_anchor":Vector2(1005, 654),
		"approach":Vector2(1030, 735),
		"lines":[
			"The tiny house has a tiny foyer, for tiny guests with tiny secrets.",
			"Every window is dark, which is sensible for a house this small.",
			"The miniature parlor is tidier than ours. No one likes a show-off.",
		],
	},
	{
		"id":"toy_chest", "name":"The Restless Toy Chest", "prompt":"Inspect the restless toy chest",
		"pos":Vector2(1362, 692), "reach":88.0, "marker_anchor":Vector2(1354, 657),
		"approach":Vector2(1295, 729),
		"lines":[
			"Toys spill out like a cheerful rebellion against sensible storage.",
			"A wooden drum hides beneath the heap, pretending innocence.",
			"The chest contains enough playthings to occupy one ghost for centuries.",
		],
	},
	{
		"id":"rocking_horse", "name":"The Midnight Rocking Horse", "prompt":"Inspect the midnight rocking horse",
		"pos":Vector2(1319, 824), "reach":65.0, "marker_anchor":Vector2(1301, 808),
		"approach":Vector2(1279, 830),
		"lines":[
			"The painted horse waits patiently for a rider with impeccable balance.",
			"Its wooden smile says it has crossed stranger rooms than this.",
			"A gallant steed, though its idea of galloping is gently rocking.",
		],
	},
	{
		"id":"bed", "name":"The Sleepy Bed", "prompt":"Inspect the sleepy bed",
		"pos":Vector2(1395, 785), "reach":85.0, "marker_anchor":Vector2(1390, 754),
		"approach":Vector2(1347, 782),
		"lines":[
			"The plush rabbit keeps watch with the solemnity of a tiny guard.",
			"The blankets are tucked in neatly; even nightmares must knock first.",
			"A cozy bed, made for dreams and one very long-eared chaperone.",
		],
	},
	{
		"id":"stag", "name":"The Antlered Host", "prompt":"Greet the antlered host",
		"pos":Vector2(768, 139), "reach":96.0, "marker_anchor":Vector2(768, 90),
		"approach":Vector2(768, 194),
		"lines":[
			"The antlers crown the foyer like nature's most opinionated chandelier.",
			"This noble stag has witnessed every entrance and judged most of them.",
			"Dust rests on its brow, giving the old monarch a silver crown.",
		],
	},
	{
		"id":"pantry", "name":"The Potion Pantry", "prompt":"Inspect the potion pantry",
		"pos":Vector2(362, 684), "reach":86.0, "marker_anchor":Vector2(360, 658),
		"approach":Vector2(358, 738),
		"lines":[
			"The jars stand in ranks, each guarding a mystery with a label.",
			"Crockery crowds the shelves like gossiping aunts at a village feast.",
			"Some preserves are older than the house and considerably less chatty.",
		],
	},
]
