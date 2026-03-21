import { ref, runTransaction, onChildAdded, push, get, onDisconnect, remove } from "firebase/database";
import { rtdb } from "$lib/firebase";
import { app } from "./app.svelte";

import Peer from "peerjs";

export const meshState = {
	myGodotId: null,
	peer: null,
	iceServers: [],
	connections: {},
};

// --- 1. JOIN SESSION & GRAB TICKET ---
export async function joinSession() {
	if (!app.uid) return;
	if (!app.currentGame.id) return

	const response = await fetch('/api/turn');
	meshState.iceServers = await response.json();

	// console.log('Joining Session...');

	const playersRef = ref(
		rtdb,
		`chats/${app.currentChat.id}/games/${app.currentGame.id}/active_players`
	);

	// The "Ticket Booth" - securely claim a slot from 1 to 32
	const result = await runTransaction(playersRef, (currentData) => {
		if (currentData === null) {
			return { '1': app.uid }; // Room is empty, I am Player 1
		}

		for (let i = 1; i <= 32; i++) {
			const slotKey = i.toString();
			if (!currentData.hasOwnProperty(slotKey)) {
				currentData[slotKey] = app.uid;
				return currentData; // Claim the first empty slot
			}
			if (currentData[slotKey] === app.uid) {
				return undefined; // Abort, I am already in the room
			}
		}
		return currentData; // Room is full
	});

	if (result.committed) {
		const data = result.snapshot.val();
		finalizeJoin(data);
	} else {
		const snapshot = await get(playersRef);
		const data = snapshot.val();
		if (data) finalizeJoin(data);
	}
}

// Helper to set up disconnection logic and start the mesh
function finalizeJoin(existingPlayersData) {
	const mySlot = Object.keys(existingPlayersData).find((key) => existingPlayersData[key] === app.uid);

	if (mySlot) {
		meshState.myGodotId = parseInt(mySlot);
		// console.log(`Acquired Player ID: ${meshState.myGodotId}`);

		// If I close the tab, free up my chair in Firebase
		const sessionRef = ref(
			rtdb,
			`chats/${app.currentChat.id}/games/${app.currentGame.id}/active_players/${meshState.myGodotId}`
		);

		onDisconnect(sessionRef).remove();
		meshState.peer = new Peer(app.uid, {
			config: {
				iceServers: meshState.iceServers
			},
		});

		meshState.peer.on('open', (id) => {
			// console.log('My PeerJS ID is: ' + id);
			setupMesh(existingPlayersData);
		});

		meshState.peer.on('connection', (conn) => {
			conn.on('open', () => {
				// Read the Godot ID directly from the newcomer's metadata!
				const senderGodotId = conn.metadata.godotId;

				if (senderGodotId) {
					setupDataChannelEvents(parseInt(senderGodotId), conn);
				} else {
					console.error("The Thing says: Connection missing metadata!");
				}
			});
		});

		meshState.peer.on('error', (err) => {
			console.error('PeerJS Error:', err);
		});
	}
}

function setupMesh(existingPlayersData) {
	// Say hello to everyone who is ALREADY in the room
	for (const peerIdStr in existingPlayersData) {
		const godotId = parseInt(peerIdStr);
		const targetPeerJsId = existingPlayersData[peerIdStr];

		if (godotId !== meshState.myGodotId) {
			// I am the newcomer, so I initiate connection to them
			const conn = meshState.peer.connect(targetPeerJsId, {
				metadata: { godotId: meshState.myGodotId }
			});

			conn.on('open', () => {
				setupDataChannelEvents(godotId, conn);
			});
		}
	}
}

function setupDataChannelEvents(godotId, channel) {
	if (!godotId || isNaN(godotId)) return;

	meshState.connections[godotId] = channel;
	// console.log(`✅ WebRTC Mesh Connected to Player ${godotId}!`);

	const godotIframe = document.getElementById("godot-iframe");
	if (godotIframe && godotIframe.contentWindow.GodotReceiveData) {
		godotIframe.contentWindow.networkUpdate("peer_connected", godotId);
	}

	channel.on('data', (data) => {
		if (godotIframe && godotIframe.contentWindow.GodotReceiveData) {
			godotIframe.contentWindow.GodotReceiveData(godotId, data);
		}
	});

	channel.on('close', () => {
		// console.log(`❌ Player ${godotId} disconnected.`);
		delete meshState.connections[godotId];

		if (godotIframe && godotIframe.contentWindow.GodotReceiveData) {
			godotIframe.contentWindow.networkUpdate("peer_disconnected", godotId);
		}
	});
}

export function broadcast(data) {
	for (const godotId in meshState.connections) {
		const conn = meshState.connections[godotId];
		if (conn && conn.open) {
			conn.send(data);
		}
	}
}

// Send data to a specific player
export function sendTo(targetGodotId, data) {
	const conn = meshState.connections[targetGodotId];
	if (conn && conn.open) {
		conn.send(data);
	}
}

export function leaveMeshSession() {
	// console.log("Leaving WebRTC Mesh Session...");

	if (meshState.peer) {
		meshState.peer.destroy();
		meshState.peer = null;
	}

	meshState.connections = {};
	meshState.myGodotId = null;
}