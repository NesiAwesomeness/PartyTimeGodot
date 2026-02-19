<script>
	import { db, rtdb } from '$lib/firebase';
	import { userStore } from '$lib/userData';
	import { ref, set } from 'firebase/database';
	import { addDoc, collection, deleteDoc, doc, setDoc } from 'firebase/firestore';

	export let request = {
		id: '',
		username: 'John Pork'
	};

	async function handleAcceptRequest() {
		if (!$userStore || !$userStore.uid) return;

		const userID = $userStore.uid;
		const myUsername = $userStore.username;
		const timestamp = Date.now();

		try {
			// 1. CREATE YOUR PLAYGROUND (Auto-generates the Chat ID)
			const myPlaygroundsRef = collection(db, 'users', userID, 'playgrounds');
			const gameDocument = await addDoc(myPlaygroundsRef, {
				chatName: request.username,
				timestamp: timestamp,
				isGroup: false,
				lastOpened: 0
			});

			const chatID = gameDocument.id;

			const requestRef = doc(db, 'users', $userStore.uid, 'requests', request.id);
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
</script>

<div class="request">
	<span>{request.username}</span>
	<button title="Accept" on:click={handleAcceptRequest}>
		<svg viewBox="72 -880 810 810" fill="rgb(68, 203, 68)" class="icon"
			><path
				d="m424-408-86-86q-11-11-28-11t-28 11q-11 11-11 28t11 28l114 114q12 12 28 12t28-12l226-226q11-11 11-28t-11-28q-11-11-28-11t-28 11L424-408Zm56 328q-83 0-156-31.5T197-197q-54-54-85.5-127T80-480q0-83 31.5-156T197-763q54-54 127-85.5T480-880q83 0 156 31.5T763-763q54 54 85.5 127T880-480q0 83-31.5 156T763-197q-54 54-127 85.5T480-80Z"
			/>
		</svg>
	</button>
	<button title="Reject">
		<svg viewBox="0 0 512 512" xml:space="preserve" class="icon" fill="rgb(203, 68, 68)"
			><path
				d="M256,0C114.615,0,0,114.615,0,256s114.615,256,256,256s256-114.615,256-256C511.847,114.678,397.322,0.153,256,0z M341.333,311.189c8.669,7.979,9.229,21.475,1.25,30.144c-7.979,8.669-21.475,9.229-30.144,1.25c-0.434-0.399-0.85-0.816-1.25-1.25   L256,286.165l-55.168,55.168c-8.475,8.185-21.98,7.95-30.165-0.525c-7.984-8.267-7.984-21.373,0-29.64L225.835,256l-55.168-55.168   c-8.185-8.475-7.95-21.98,0.525-30.165c8.267-7.984,21.373-7.984,29.64,0L256,225.835l55.189-55.168   c7.979-8.669,21.475-9.229,30.144-1.25c8.669,7.979,9.229,21.475,1.25,30.144c-0.399,0.434-0.816,0.85-1.25,1.25L286.165,256   L341.333,311.189z"
			/>
		</svg>
	</button>
</div>

<style>
	.request {
		width: 100%;
		padding: 12px;

		display: grid;
		grid-template-columns: 1fr auto auto;

		box-sizing: border-box;
		border-radius: 16px;

		background-color: rgba(255, 255, 255, 0.078);
	}

	.request span {
		color: white;
		font-size: 1.25rem;

		padding: 0 8px;
	}

	button > svg,
	button::after {
		grid-area: 1 / 1;
	}

	.request button {
		height: 100%;
		padding: 0;

		background-color: transparent;
		border: none;

		display: grid;
		place-items: center;

		gap: 2px;
		cursor: pointer;
	}

	button::after {
		content: ''; /* Pseudo-elements won't render without this! */
		position: relative;

		/* Make it fill the button perfectly */
		width: 12px;
		height: 12px;

		background-color: white;
		border-radius: 50%; /* Makes it a circle */
		z-index: 0; /* Puts it on the bottom layer */
	}

	.icon {
		width: 24px;
		height: 24px;

		margin: 0 8px;
		z-index: 1;
	}
</style>
