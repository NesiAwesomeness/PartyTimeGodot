import { onAuthStateChanged } from "firebase/auth";
import { auth, db, rtdb } from "./firebase";
import { addDoc, collection, doc, getDoc, getDocs, onSnapshot, query, setDoc, where } from "firebase/firestore";
import { goto } from "$app/navigation";
import { toDisplayName } from "./appData";
import { ref, set } from "firebase/database";

class appState {
	loading = $state(true)
	uid = $state('')
	username = $state('')
	isInitialized = $state(false);

	playgrounds = $state([])
	requests = $state([])
	lastCheckedRequests = $state(0.0)

	init() {
		onAuthStateChanged(auth, async (user) => {
			if (user) {
				this.uid = user.uid
				const userDocRef = doc(db, 'users', user.uid);
				const userSnapshot = await getDoc(userDocRef);

				const rawName = user.email.split('@')[0];
				this.username = toDisplayName(rawName);

				let userInfo = {
					lastCheckedRequests: 0.0,
					username: rawName,
					active: true
				};

				if (userSnapshot.exists()) {
					userInfo = {
						...userSnapshot.data()
					};
				} else {
					await setDoc(userDocRef, userInfo);
				}

				this.lastCheckedRequests = userInfo.lastCheckedRequests
				this.loading = false

				this.fetchPlaygroundData()

			} else {
				this.uid = ''
				this.username = ''

				this.playgrounds = [];
				this.requests = [];

				this.stopListening();
			}
			this.isInitialized = true;
		});
	}

	#requestUnsub = null;
	#playgroundUnsub = null;

	stopListening() {
		if (this.#requestUnsub) {
			this.#requestUnsub();
			this.#requestUnsub = null;
		}
		if (this.#playgroundUnsub) {
			this.#playgroundUnsub();
			this.#playgroundUnsub = null;
		}
	}

	fetchPlaygroundData() {
		this.stopListening();

		if (!this.uid) return;

		// 1. Listen to Playgrounds
		const playgroundRef = collection(db, 'users', this.uid, 'playgrounds');
		this.#playgroundUnsub = onSnapshot(playgroundRef, (snapshot) => {
			let tempItems = [];
			snapshot.forEach((doc) => {
				tempItems.push({ id: doc.id, ...doc.data() });
			});
			tempItems.sort((a, b) => b.timestamp - a.timestamp);

			// Directly assign. Svelte handles the reactivity magic.
			this.playgrounds = tempItems;
		});

		// 2. Listen to Requests
		const requestsRef = collection(db, 'users', this.uid, 'requests');
		this.#requestUnsub = onSnapshot(requestsRef, (snapshot) => {
			let tempItems = [];
			snapshot.forEach((doc) => {
				tempItems.push({ id: doc.id, ...doc.data() });
			});
			tempItems.sort((a, b) => b.timestamp - a.timestamp);

			const latestRequest = tempItems.reduce(
				(max, request) => (request.timestamp > max.timestamp ? request : max),
				{ timestamp: this.lastCheckedRequests }
			);

			// Update states directly
			this.newRequest = latestRequest.timestamp > this.lastCheckedRequests;
			this.requests = tempItems;
		});
	}

	isRequesting = $state(false);

	async handleSendRequest(friendName) {
		if (!friendName) return;

		this.isRequesting = true;

		try {
			// 2. Query the 'users' collection where username == friendUsername
			const usersRef = collection(db, 'users');
			const q = query(usersRef, where('username', '==', friendName));

			const querySnapshot = await getDocs(q);
			const searchedName = friendName;

			friendName = '';
			this.isRequesting = false;

			if (querySnapshot.empty) {
				// use toast here...?
				console.log('User not found!');
				return;
			}

			const friendDoc = querySnapshot.docs[0];
			const friendId = friendDoc.id;
			const requestRef = doc(db, 'users', friendId, 'requests', this.uid);

			await setDoc(requestRef, {
				username: this.username,
				timestamp: Date.now()
			});

			console.log('Request sent successfully to', searchedName);
		} catch (error) {
			console.error('Error sending request:', error);
			this.isRequesting = false;
		}
	}

	// GROUP CHAT STUFF
	async handleCreateGroup(groupName, selectedChats) {
		if (!groupName || !this.uid) return;

		const userID = this.uid;
		const myUsername = this.username;
		const timestamp = Date.now();

		// Build group members dictionary
		let groupMembers = { [userID]: myUsername };
		let friendUserIds = []; // We need these for the fan-out

		for (const chatId of selectedChats) {
			const membersRef = ref(rtdb, `chats/${chatId}/members`);
			const snapshot = await get(membersRef);

			if (snapshot.exists()) {
				const membersDict = snapshot.val();
				const friendId = Object.keys(membersDict).find((id) => id !== userID);

				if (friendId) {
					groupMembers[friendId] = membersDict[friendId];
					friendUserIds.push(friendId);
				}
			}
		}

		try {
			// 1. Create document in my playgrounds (auto-generates the group ID)
			const myPlaygroundsRef = collection(db, 'users', userID, 'playgrounds');
			const groupData = {
				chatName: groupName,
				creator: myUsername,
				timestamp: timestamp,
				isGroup: true,
				lastOpened: 0.0
			};

			const gameDocument = await addDoc(myPlaygroundsRef, groupData);
			const groupID = gameDocument.id;

			// 2. Set up RTDB chat reference
			const chatRef = ref(rtdb, `chats/${groupID}`);
			await set(chatRef, {
				games: { null: 0 }, // Equivalent to NULL_GAME
				members: groupMembers
			});

			// 3. "Fan out" to all other members
			for (const memberID of friendUserIds) {
				const theirPlaygroundRef = doc(db, 'users', memberID, 'playgrounds', groupID);
				await setDoc(theirPlaygroundRef, groupData);
			}

			console.log('Group created successfully:', groupID);
		} catch (error) {
			console.error('Error creating group:', error);
		}
	}

	async handleAcceptRequest(request) {
		if (!this.uid) return;

		const userID = this.uid;
		const myUsername = this.username;
		const timestamp = Date.now();

		try {
			const myPlaygroundsRef = collection(db, 'users', userID, 'playgrounds');
			const gameDocument = await addDoc(myPlaygroundsRef, {
				chatName: request.username,
				timestamp: timestamp,
				isGroup: false,
				lastOpened: 0
			});

			const chatID = gameDocument.id;

			const requestRef = doc(db, 'users', userID, 'requests', request.id);
			await deleteDoc(requestRef);

			const chatRef = ref(rtdb, `chats/${chatID}`);

			const members = {};
			members[userID] = myUsername;
			members[request.id] = request.username;

			const blank = { null: 0 };

			await set(chatRef, {
				games: blank,
				members: members
			});

			const theirPlaygroundRef = doc(db, 'users', request.id, 'playgrounds', chatID);
			await setDoc(theirPlaygroundRef, {
				chatName: myUsername,
				timestamp: timestamp,
				isGroup: false,
				lastOpened: 0
			});
			console.log('Successfully created chat room:', chatID);
		} catch (error) {
			console.error('Error accepting request:', error);
		}
	}

	async handleDeclineRequest(request) {
		if (!this.uid) return;

		try {
			const requestRef = doc(db, 'users', this.uid, 'requests', request.id);
			await deleteDoc(requestRef);

			console.log('Successfully declined ', request.username, "'s request!");
		} catch (error) {
			console.error('Error declining request:', error);
		}
	}

	// current chat details
	currentChat = $state({
		id: '', chatName: 'Playground Name',
		lastOpened: 0.0, timestamp: 0.0,
		gameArray: [], playerIndex: -1,
		members: { "ab": "cd" }
	})

	setCurrentChat(chat) {
		this.currentChat = { ...this.currentChat, ...chat }
	}

	resetCurrentChat() {
		this.currentChat = {
			id: '', chatName: 'Playground Name',
			lastOpened: 0.0, timestamp: 0.0,
			gameArray: [], playerIndex: -1,
			members: { "ab": "cd" }
		}
	}

	currentGame = $state({
		id: "",
		isTurnBased: false,
		gameData: {},
	})

	setGame(game) {
		this.currentGame = { ...this.currentGame, ...game }
	}

	resetGame() {
		this.currentGame = {
			id: "",
			isTurnBased: false,
			gameData: {},
		}
	}

}

export const app = new appState();

class gameState {
	loading = $state(true)
	gameRequest = $state(null);

	setRequest(request) {
		this.gameRequest = request;
	}

	resetRequest() {
		this.gameRequest = null;
	}
}

export const game = new gameState();