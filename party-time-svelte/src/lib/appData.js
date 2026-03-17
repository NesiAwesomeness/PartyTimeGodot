// this is games
export const games = [
	{
		name: "Go Fish",
		key: "GoFish",
		isTurnBased: true,
	}
]

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
