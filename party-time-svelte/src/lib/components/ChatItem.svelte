<script>
	import { rtdb } from '$lib/firebase';
	import { userStore } from '$lib/userData';
	import { getDisplayTime, currentChat } from '$lib/appData';
	import { onValue, ref } from 'firebase/database';
	import { onDestroy, onMount } from 'svelte';

	export let chatItem = {
		id: 'z',
		timestamp: 0.0
	};

	$: timestamp = getDisplayTime(chatItem.timestamp);

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
			if (snapshot.exists()) {
				const chatData = snapshot.val();

				members = chatData.members;
				playerIndex = Object.keys(members).indexOf($userStore.uid);

				gameArray = Object.entries(chatData.games)
					.filter(([key, value]) => key !== 'null')
					.map(([key, value]) => {
						return { id: key, ...value };
					});

				// update timestamp here.
				console.log();
			}

			if ($currentChat.id === chatItem.id) {
				// console.log('Games Updated ', chatItem.chatName, 'on this account ', $userStore.username);
				$currentChat.gameArray = gameArray;
			}
		});
	});

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
			$currentChat = { ...$currentChat, ...chatItem, gameArray, playerIndex, members };
			// update lastOpened here.
		}
	}}
>
	<div class="icon-placeholder"></div>
	<div class="chat-info">
		<span class="username">{chatItem.chatName}</span>
		<span class="timestamp">{timestamp}</span>
		<span class="game-type">
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

		color: rgba(255, 255, 255, 0.32);
		background-color: rgba(22, 22, 22, 0.4);
		margin: 0;
	}

	.timestamp {
		margin: 4px 0;
		padding: 0;
		padding-right: 24px;

		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.4);
	}

	.icon-placeholder {
		width: 48px;
		height: 48px;

		background-color: rgba(255, 255, 255, 0.63);
		border-radius: 999px;

		margin: 12px;
	}
</style>
