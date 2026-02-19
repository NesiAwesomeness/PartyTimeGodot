import { readable, writable } from 'svelte/store';

export const playgrounds = writable([]);
export const requests = writable([]);

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
	isTurnBased: true,
	playerTurn: 0,

	name: "",
	key: "",

	isRoundPlay: true,
	round: 1,
	sends: 0,

	timestamp: 0.0,

	gameState: {
		dude: "chill"
	}
}

export const currentGame = writable({
	id: "",
	gameData: gameDataDefaults,
})

// this is gameData
export const games = readable([
	{
		...gameDataDefaults,

		name: "Color Game",
		key: "ColorGame",

		// this key value is how godot will recognise it.
		gameState: {
			stateColor: '#ffffff'
		}
	}
])

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