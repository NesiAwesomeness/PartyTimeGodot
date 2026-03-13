import { get } from 'svelte/store';
import { readable, writable } from 'svelte/store';

// the game select sends to godot
export const gameRequest = writable(null);

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

export const currentGame = writable({
	id: "",
	isTurnBased: false,
	gameData: {},
})

// this is gameData
export const games = readable([
	{
		name: "Go Fish",
		key: "GoFish",
	}
])

export function toDisplayName(name) {
	return name.charAt(0).toUpperCase() + name.slice(1);
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