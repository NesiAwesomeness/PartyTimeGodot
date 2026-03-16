import { ref, runTransaction, onChildAdded, push, get, onDisconnect, remove } from "firebase/database";
// Assuming 'rtdb' is your initialized Firebase Realtime Database
import { rtdb } from "$lib/firebase";
// Assuming 'app' contains your current state (uid, chat id, game id)
import { app } from "./app.svelte";

// --- STATE MANAGEMENT ---
// We hold our connections here so we can talk to multiple players in the mesh
export const meshState = {
	myGodotId: null,
	iceServers: [],
	peerConnections: {}, // e.g., { 1: RTCPeerConnection, 2: RTCPeerConnection }
	dataChannels: {},     // e.g., { 1: RTCDataChannel, 2: RTCDataChannel }
	inboxListenerUnsub: null
};

// --- 1. JOIN SESSION & GRAB TICKET ---
export async function joinSession() {
	if (!app.uid) return;
	if (!app.currentGame.id) return

	const response = await fetch('/api/turn');
	meshState.iceServers = await response.json();

	console.log('Joining Session...');

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
		console.log(`Acquired Player ID: ${meshState.myGodotId}`);

		// If I close the tab, free up my chair in Firebase
		const sessionRef = ref(
			rtdb,
			`chats/${app.currentChat.id}/games/${app.currentGame.id}/active_players/${meshState.myGodotId}`
		);

		onDisconnect(sessionRef).remove();

		const myInboxRef = ref(rtdb, `chats/${app.currentChat.id}/games/${app.currentGame.id}/signals/${meshState.myGodotId}`);
		remove(myInboxRef).then(() => {
			setupMeshAndListeners(existingPlayersData);
		});
	}
}


// --- 2. THE SWITCHBOARD (SIGNALING LOBBY) ---
function setupMeshAndListeners(existingPlayersData) {
	// 1. Listen to MY personal inbox for incoming WebRTC signals
	const myInboxRef = ref(
		rtdb,
		`chats/${app.currentChat.id}/games/${app.currentGame.id}/signals/${meshState.myGodotId}`
	);

	meshState.inboxListenerUnsub = onChildAdded(myInboxRef, async (snapshot) => {
		const signal = snapshot.val();
		const signalKey = snapshot.key;

		const specificSignalRef = ref(rtdb, `chats/${app.currentChat.id}/games/${app.currentGame.id}/signals/${meshState.myGodotId}/${signalKey}`);
		remove(specificSignalRef);
		await handleIncomingSignal(signal);
	});

	// 2. Say hello to everyone who is ALREADY in the room
	for (const peerIdStr in existingPlayersData) {
		const peerId = parseInt(peerIdStr);
		if (peerId !== meshState.myGodotId) {
			// I am the newcomer, so I generate Offers for them
			initiateConnectionTo(peerId);
		}
	}
}


// --- 3. CREATE OFFER (FOR NEWCOMERS) ---
async function initiateConnectionTo(targetPeerId) {
	const pc = new RTCPeerConnection({ iceServers: meshState.iceServers });
	meshState.peerConnections[targetPeerId] = pc;

	// Create the Data Channel (The Game Pipe!)
	const dataChannel = pc.createDataChannel('game_data');
	setupDataChannelEvents(targetPeerId, dataChannel);

	// Send my network routes (ICE) to the target
	pc.onicecandidate = (event) => {
		if (event.candidate) {
			sendSignal(targetPeerId, {
				type: 'candidate',
				from: meshState.myGodotId,
				candidate: event.candidate.toJSON()
			});
		}
	};

	// Create and send the WebRTC Offer
	const offer = await pc.createOffer();
	await pc.setLocalDescription(offer);

	sendSignal(targetPeerId, {
		type: 'offer',
		from: meshState.myGodotId,
		sdp: offer.sdp
	});
}


// --- 4. PROCESS INCOMING MAIL (OFFERS, ANSWERS, ICE) ---
async function handleIncomingSignal(signal) {
	const senderId = signal.from;

	// If a newcomer sent us an Offer, we won't have a peer connection for them yet. Create it!
	if (!meshState.peerConnections[senderId]) {
		const pc = new RTCPeerConnection({ iceServers: meshState.iceServers });
		meshState.peerConnections[senderId] = pc;

		// Listen for the Data Channel the newcomer created
		pc.ondatachannel = (event) => {
			setupDataChannelEvents(senderId, event.channel);
		};

		// Send our network routes (ICE) back to them
		pc.onicecandidate = (event) => {
			if (event.candidate) {
				sendSignal(senderId, {
					type: 'candidate',
					from: meshState.myGodotId,
					candidate: event.candidate.toJSON()
				});
			}
		};
	}

	const pc = meshState.peerConnections[senderId];

	// Read the signal type
	try {
		if (signal.type === 'offer') {
			await pc.setRemoteDescription(new RTCSessionDescription({ type: 'offer', sdp: signal.sdp }));
			const answer = await pc.createAnswer();
			await pc.setLocalDescription(answer);

			// Accept their call and send the Answer
			sendSignal(senderId, {
				type: 'answer',
				from: meshState.myGodotId,
				sdp: answer.sdp
			});

		} else if (signal.type === 'answer') {
			await pc.setRemoteDescription(new RTCSessionDescription({ type: 'answer', sdp: signal.sdp }));

		} else if (signal.type === 'candidate') {
			await pc.addIceCandidate(new RTCIceCandidate(signal.candidate));
		}
	} catch (error) {
		console.error("Signaling Error:", error, "Signal Data:", signal);
	}
}


// --- 5. UTILITIES ---

// The Mailman: Sends a payload to another player's Firebase inbox
function sendSignal(targetId, payload) {
	const targetInboxRef = ref(
		rtdb,
		`chats/${app.currentChat.id}/games/${app.currentGame.id}/signals/${targetId}`
	);
	push(targetInboxRef, payload); // push() creates a unique timestamped child
}

// Binds the WebRTC connection to your Godot Iframe!
function setupDataChannelEvents(peerId, channel) {
	meshState.dataChannels[peerId] = channel;

	channel.onopen = () => {
		console.log(`✅ WebRTC Mesh Connected to Player ${peerId}!`);

		const godotIframe = document.getElementById("godot-iframe");
		if (godotIframe && godotIframe.contentWindow.GodotReceiveData) {
			godotIframe.contentWindow.networkUpdate("peer_connected", peerId);
		}
	};

	channel.onmessage = (event) => {
		// We received data from another player, pass it into Godot
		const godotIframe = document.getElementById("godot-iframe");
		if (godotIframe && godotIframe.contentWindow.GodotReceiveData) {
			godotIframe.contentWindow.GodotReceiveData(peerId, event.data);
		}
	};

	channel.onclose = () => {
		console.log(`❌ Player ${peerId} disconnected.`);
		delete meshState.dataChannels[peerId];
		delete meshState.peerConnections[peerId];

		const godotIframe = document.getElementById("godot-iframe");
		if (godotIframe && godotIframe.contentWindow.GodotReceiveData) {
			godotIframe.contentWindow.networkUpdate("peer_disconnected", peerId);
		}
	};
}

export function leaveMeshSession() {
	console.log("Leaving WebRTC Mesh Session...");

	if (meshState.inboxListenerUnsub) {
		meshState.inboxListenerUnsub();
		meshState.inboxListenerUnsub = null;
	}

	// 1. Close all active Peer Connections
	for (const peerId in meshState.peerConnections) {
		const pc = meshState.peerConnections[peerId];
		if (pc) {
			// This safely closes the WebRTC socket and the Data Channel
			pc.close();
		}
	}

	meshState.peerConnections = {};
	meshState.dataChannels = {};
}