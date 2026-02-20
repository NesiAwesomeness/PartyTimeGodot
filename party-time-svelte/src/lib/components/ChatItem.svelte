<script>
	import { db, rtdb } from '$lib/firebase';
	import { userStore } from '$lib/userData';
	import { getDisplayTime, currentChat, playgrounds } from '$lib/appData';
	import { onValue, ref } from 'firebase/database';
	import { onDestroy, onMount } from 'svelte';
	import { doc, updateDoc } from 'firebase/firestore';

	export let chatItem = {
		id: 'z',
		timestamp: 0.0
	};

	$: timestamp = getDisplayTime(chatItem.timestamp);
	$: unopened = chatItem.timestamp > chatItem.lastOpened && chatItem.id != $currentChat.id;

	let currentUnsubscribe = null;

	// just save this shit.
	let gameArray = [];
	let members = {};
	let playerIndex = -1;

	onMount(() => {
		if (currentUnsubscribe) {
			currentUnsubscribe();
			currentUnsubscribe = null;
		}

		const chatRef = ref(rtdb, `chats/${chatItem.id}`);
		currentUnsubscribe = onValue(chatRef, (snapshot) => {
			let newTimestamp = chatItem.timestamp;

			if (snapshot.exists()) {
				const chatData = snapshot.val();

				members = chatData.members;
				playerIndex = Object.keys(members).indexOf($userStore.uid);

				gameArray = Object.entries(chatData.games)
					.filter(([key, value]) => key !== 'null')
					.map(([key, value]) => {
						return { id: key, ...value };
					});

				gameArray.sort((a, b) => b.timestamp - a.timestamp);

				const latestGame = gameArray.reduce(
					(max, game) => (game.timestamp > max.timestamp ? game : max),
					{ timestamp: chatItem.timestamp || 0 }
				);

				newTimestamp = latestGame.timestamp;

				if (newTimestamp > chatItem.timestamp) {
					chatItem.timestamp = newTimestamp;
					updateTimestamp(newTimestamp);
				}
			}

			if ($currentChat.id === chatItem.id) {
				selectChat();
			}
		});
	});

	async function updateTimestamp(time) {
		const playgroundRef = doc(db, 'users', $userStore.uid, 'playgrounds', chatItem.id);
		await updateDoc(playgroundRef, {
			timestamp: time
		});
	}

	async function selectChat() {
		$currentChat = { ...$currentChat, ...chatItem, gameArray, playerIndex, members };
		const playgroundRef = doc(db, 'users', $userStore.uid, 'playgrounds', chatItem.id);

		await updateDoc(playgroundRef, {
			lastOpened: Date.now()
		});
	}

	onDestroy(() => {
		if (currentUnsubscribe) {
			currentUnsubscribe();
			currentUnsubscribe = null;
		}
	});
</script>

<button
	class="chat"
	on:click={() => {
		if (chatItem.id != $currentChat.id) {
			selectChat();
		}
	}}
>
	<div class="icon-placeholder"></div>
	<div
		class="chat-info"
		style="
		font-weight: {unopened ? 800 : 500};"
	>
		<span class="username">{chatItem.chatName}</span>
		<span class="timestamp" style="color: {unopened ? '#ffffff' : 'rgba(255, 255, 255, 0.32)'};"
			>{timestamp}</span
		>
		<span class="game-type" style="color: {unopened ? '#ffffff' : 'rgba(255, 255, 255, 0.32)'};">
			<svg
				xmlns="http://www.w3.org/2000/svg"
				viewBox="0 0 12 12"
				width="12"
				height="12"
				fill="rgb(203, 68, 68)"
				stroke-linecap="round"
				stroke-linejoin="round"
				class="svg-circle"
			>
				<circle cx="6" cy="6" r="5"></circle>
			</svg>

			Color Game
		</span>
	</div>
</button>

<style>
	.chat {
		all: unset;
		display: grid;
		grid-template-columns: auto 1fr;

		align-items: center;

		color: rgba(255, 255, 255, 0.849);
		font-weight: 500;
		cursor: pointer;

		width: 100%;

		overflow: hidden;
		border-radius: 16px;
	}

	.username {
		font-size: 1.125rem;
		align-self: flex-start;
	}

	.chat-info {
		display: grid;
		grid-auto-flow: row;
		grid-template-columns: 1fr auto;

		height: 100%;
		gap: 2px 0;

		align-content: center;
		border-bottom: 2px solid rgba(255, 255, 255, 0.04);
	}

	.game-type {
		font-size: 0.75rem;
		display: grid;
		grid-auto-flow: column;
		gap: 4px;

		width: fit-content;

		align-items: center;

		padding: 4px 8px;
		border-radius: 8px;

		background-color: rgba(22, 22, 22, 0.4);
		margin: 0;
	}

	.timestamp {
		margin: 4px 0;
		padding: 0;
		padding-right: 24px;

		font-size: 0.75rem;
	}

	.icon-placeholder {
		width: 48px;
		height: 48px;

		background-color: rgba(255, 255, 255, 0.63);
		border-radius: 999px;

		margin: 12px;
	}
</style>
