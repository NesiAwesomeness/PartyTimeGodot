import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';

export async function GET() {
	const apiKey = env.METERED_API_KEY;

	try {
		const response = await fetch(`https://party-time.metered.live/api/v1/turn/credentials?apiKey=${apiKey}`);

		if (!response.ok) {
			throw new Error('Failed to fetch TURN credentials');
		}

		const allServers = await response.json();

		// --- THE FIX: Filter the servers ---
		let stunCount = 0;
		let turnCount = 0;

		const optimizedServers = allServers.filter(server => {
			// Check if this specific server entry is a STUN server
			const urlsString = JSON.stringify(server.urls);

			if (urlsString.includes('stun:')) {
				if (stunCount >= 2) return false; // Only keep ONE STUN
				stunCount++;
				return true;
			}

			if (urlsString.includes('turn:') || urlsString.includes('turns:')) {
				if (turnCount >= 0) return false; // Only keep ONE TURN
				turnCount++;
				return true;
			}

			return false;
		});

		// Send the smaller, optimized list to the frontend
		return json(optimizedServers);

	} catch (error) {
		console.error("TURN Server Error:", error);
		return json([
			{ urls: ['stun:stun1.l.google.com:19302', 'stun:stun2.l.google.com:19302'] }
		]);
	}
}