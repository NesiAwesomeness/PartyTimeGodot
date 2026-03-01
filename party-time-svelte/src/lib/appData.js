import { get } from 'svelte/store';
import { readable, writable } from 'svelte/store';

export const playgrounds = writable([]);
export const requests = writable([]);
export const requestsSent = writable([])

export const currentChat = writable({
	chatName: "Playground Name",
	id: "",
	lastOpened: 0.0,
	timestamp: 0.0,
	gameArray: [],
	playerIndex: -1,
	members: { "sss": "dd" }
});

// the default is a turn based round game.
const gameDataDefaults = {
	name: "",
	key: "",

	sends: 0,
	timestamp: 0.0,

	gameState: {
		playerTurn: 0,
		round: 1,
	}
}

export const currentGame = writable({
	id: "",
	isTurnBased: false,
	gameData: gameDataDefaults,
})

// this is gameData
export const games = readable([
	{
		...gameDataDefaults,

		name: "Color Game",
		key: "ColorGame",
	},
	{
		...gameDataDefaults,
		name: "World Game",
		key: "WorldGame",
	},
	{
		...gameDataDefaults,
		name: "Go Fish",
		key: "GoFish",
	}
])

export function getGameState(gameKey) {
	switch (gameKey) {
		case "GoFish":
			return getGoFishGameState();
		case "ColorGame":
			return getColorGameState();
		default:
			return {}
	}
}

function getGoFishGameState() {
	const ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "X"]
	const suites = ["R", "G", "B", "Y"]
	const members = get(currentChat).members;

	let deck = suites.flatMap(suite =>
		ranks.map(rank => ({ rank: rank, suite: suite }))
	);

	shuffle(deck);

	let handSize = 5;
	let hands = {}
	let scores = {}

	for (let member of Object.keys(members)) {

		let hand = []
		while (hand.length < handSize) {
			hand.push(deck.pop());
		}

		hands[member] = hand

		// the starting score
		scores[member] = 0
	}


	return { playerTurn: 0, hands, scores, deck }
}

function shuffle(array) {
	let currentIndex = array.length;

	while (currentIndex != 0) {
		let randomIndex = Math.floor(
			Math.random() * currentIndex);
		currentIndex--;

		[array[currentIndex], array[randomIndex]] = [
			array[randomIndex], array[currentIndex]];
	}
}

function getColorGameState() {

	return {
		playerTurn: 0,
		round: 1,
		// generate a random color here.
		stateColor: '#ffffff'
	}
}

export function getDisplayTime(timestamp) {
	const now = new Date();
	// convert to milliseconds for now sha...
	const timestampMs = timestamp;

	const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());
	const midnightTimestamp = midnight.getTime(); // milliseconds
	const msgDate = new Date(timestampMs);

	const timeString = msgDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
	const dayString = midnightTimestamp - timestampMs < 86400000 ? 'Yesterday' : 'A while ago';
	const displayText = midnightTimestamp < timestampMs ? timeString : dayString;

	return displayText;
}