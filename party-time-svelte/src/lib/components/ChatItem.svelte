<script>
	import { db, rtdb } from '$lib/firebase';
	import { getDisplayTime, toDisplayName } from '$lib/appData';
	import { onValue, ref } from 'firebase/database';
	import { onDestroy, onMount } from 'svelte';
	import { doc, updateDoc } from 'firebase/firestore';
	import { app } from '$lib/app.svelte';

	let { chatItem } = $props();
	let timestamp = $derived(getDisplayTime(chatItem.timestamp));

	let unopened = $derived(
		chatItem.timestamp > chatItem.lastOpened && chatItem.id != app.currentChat.id
	);

	let gameArray = [];
	let members = {};
	let playerIndex = -1;

	let currentUnsubscribe = null;

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
				playerIndex = Object.keys(members).indexOf(app.uid);

				gameArray = Object.entries(chatData.games)
					.filter(([key, value]) => key !== 'null')
					.map(([key, value]) => {
						return { id: key, ...value };
					});

				gameArray.sort((a, b) => b.timestamp - a.timestamp);

				const latestGame = Object.entries(chatData.games).reduce(
					(max, game) => (game.timestamp > max.timestamp ? game : max),
					{ timestamp: chatItem.timestamp || 0 }
				);

				newTimestamp = latestGame.timestamp;

				if (newTimestamp > chatItem.timestamp) {
					chatItem.timestamp = newTimestamp;
					updateTimestamp(newTimestamp);
				}
			}

			if (app.currentChat.id === chatItem.id) {
				selectChat();
			}
		});
	});

	async function updateTimestamp(time) {
		const playgroundRef = doc(db, 'users', app.uid, 'playgrounds', chatItem.id);
		await updateDoc(playgroundRef, {
			timestamp: time
		});
	}

	async function selectChat() {
		app.setCurrentChat({ ...app.currentChat, ...chatItem, gameArray, playerIndex, members });
		const playgroundRef = doc(db, 'users', app.uid, 'playgrounds', chatItem.id);

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
	class="w-full bg-transparent border-none p-0 text-left grid grid-cols-[auto_1fr] items-center text-white/[0.85] font-medium cursor-pointer overflow-hidden rounded-2xl"
	onclick={() => {
		if (chatItem.id != app.currentChat.id) {
			selectChat();
		}
	}}
>
	<div class="w-12 h-12 bg-white/[0.63] rounded-full m-3 shrink-0"></div>
	<div
		class="grid grid-flow-row grid-cols-[1fr_auto] h-full gap-y-[2px] content-center border-b-2 border-white/[0.04] min-w-0 {unopened
			? 'font-[800]'
			: 'font-medium'}"
	>
		<span class="text-lg self-start truncate block min-w-0">{toDisplayName(chatItem.chatName)}</span
		>
		<span class="my-1 p-0 pr-6 text-xs shrink-0 {unopened ? 'text-white' : 'text-white/[0.32]'}">
			{timestamp}
		</span>
		<span
			class="text-xs grid grid-flow-col gap-1 w-fit items-center py-1 px-2 rounded-lg bg-[#161616]/40 m-0 {unopened
				? 'text-white'
				: 'text-white/[0.32]'}"
		>
			<svg
				xmlns="http://www.w3.org/2000/svg"
				viewBox="0 0 12 12"
				width="12"
				height="12"
				fill="rgb(203, 68, 68)"
				stroke-linecap="round"
				stroke-linejoin="round"
			>
				<circle cx="6" cy="6" r="5"></circle>
			</svg>

			Color Game
		</span>
	</div>
</button>
