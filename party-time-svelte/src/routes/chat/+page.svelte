<script>
	import { userStore } from '$lib/userData';
	import { playgrounds, currentChat, requests } from '$lib/appData';

	import { onDestroy, onMount } from 'svelte';
	import { games } from '$lib/appData';

	import search from '$lib/assets/search.svg';
	import add from '$lib/assets/add.svg';
	import request from '$lib/assets/users.svg';
	import close from '$lib/assets/cross-circle-red.svg';

	import ChatItem from '$lib/components/ChatItem.svelte';
	import GameBubble from '$lib/components/GameBubble.svelte';
	import GameOption from '$lib/components/GameOption.svelte';
	import RevealButton from '$lib/components/RevealButton.svelte';
	import Request from '$lib/components/Request.svelte';

	let loading = true;
	let username = 'Username';

	import { goto } from '$app/navigation';
	import { auth, db } from '$lib/firebase';
	import { collection, getDocs, onSnapshot, setDoc } from 'firebase/firestore';

	$: if ($userStore && $userStore.uid) {
		fetchPlaygroundData($userStore.uid);
		displayGameOptions();
	} else {
		stopListening();
	}

	let requestUnsub = null;
	let playgroundUnsub = null;

	function stopListening() {
		if (requestUnsub) {
			requestUnsub();
			requestUnsub = null;
		}

		if (playgroundUnsub) {
			playgroundUnsub();
			playgroundUnsub = null;
		}
	}

	async function fetchPlaygroundData(uid) {
		stopListening();

		if (uid != '') {
			const playgroundRef = collection(db, 'users', uid, 'playgrounds');
			playgroundUnsub = onSnapshot(playgroundRef, (snapshot) => {
				let tempItems = [];
				snapshot.forEach((doc) => {
					tempItems.push({ id: doc.id, ...doc.data() });
				});
				$playgrounds = tempItems;
			});

			const requestsRef = collection(db, 'users', uid, 'requests');
			requestUnsub = onSnapshot(requestsRef, (snapshot) => {
				let tempItems = [];
				snapshot.forEach((doc) => {
					tempItems.push({ id: doc.id, ...doc.data() });
				});
				$requests = tempItems;
			});
		}
	}

	let gameOptions = [];

	onMount(() => {
		$currentChat = {
			chatName: 'Playground Name',
			id: ''
		};
	});

	$: if ($currentChat) displayGameOptions();

	function displayGameOptions() {
		gameOptions = $games;
	}

	onDestroy(() => {
		stopListening();
	});

	let searchName = '';
	let isSearching = false;
	let requestList = false;

	async function handleSendRequest() {
		if (!searchName) return;

		isSearching = true;
		console.log(searchName);

		try {
			// 2. Query the 'users' collection where username == friendUsername
			const usersRef = collection(db, 'users');
			const q = query(usersRef, where('username', '==', friendUsername));

			const querySnapshot = await getDocs(q);

			friendSearchText = '';
			isSearching = false;

			if (querySnapshot.empty) {
				console.log('User not found!');
				return;
			}

			const friendDoc = querySnapshot.docs[0];
			const friendId = friendDoc.id;
			const requestRef = doc(db, 'users', friendId, 'requests', $userStore.uid);

			await setDoc(requestRef, {
				username: $userStore.username,
				timestamp: Date.now()
			});

			console.log('Request sent successfully to', searchedName);
		} catch (error) {
			console.error('Error sending request:', error);
			isSearching = false;
		}
	}

	import GodotHolder from '$lib/components/GodotHolder.svelte';
	
	let lastClickedRect = null;
	let isGameOpen = false;

	const holderBounds = spring(
		{ x: 0, y: 0, w: 1, h: 1, o: 0, r: 16 },
		{
			stiffness: 0.1, // How "snappy" the spring is
			damping: 0.4 // How much it bounces at the end
		}
	);

	function openGame(event) {
		lastClickedRect = event.detail;
		holderBounds.set(
			{
				x: lastClickedRect.offsetLeft,
				y: lastClickedRect.offsetTop,
				w: lastClickedRect.offsetWidth,
				h: lastClickedRect.offsetHeight,
				o: 0.0,
				r: 16
			},
			{ hard: true }
		);

		isGameOpen = true;

		holderBounds.set({
			x: 0,
			y: 0,
			w: window.innerWidth,
			h: window.innerHeight,
			o: 1.0,
			r: 0.0
		});
	}

	function closeGame() {
		if (lastClickedRect) {
			holderBounds.set({
				x: lastClickedRect.offsetLeft,
				y: lastClickedRect.offsetTop,
				w: lastClickedRect.offsetWidth,
				h: lastClickedRect.offsetHeight,
				o: 0.0,
				r: 16.0
			});
		}

		setTimeout(() => {
			isGameOpen = false;
		}, 120);
	}

	function handleResize() {
		if (isGameOpen) {
			holderBounds.set(
				{
					x: 0,
					y: 0,
					w: window.innerWidth,
					h: window.innerHeight
				},
				{ hard: true }
			);
		}
	}

	import { fade } from 'svelte/transition';
	import { quintInOut } from 'svelte/easing';
	import { signOut } from 'firebase/auth';
	import { spring } from 'svelte/motion';

	async function handleLogOut() {
		try {
			await signOut(auth);
			stopListening();
			goto('/');
		} catch (error) {
			console.error('Error signing out:', error.message);
		}
	}
</script>

<svelte:window on:resize={handleResize} />

<GodotHolder rect={$holderBounds} {isGameOpen} on:click={closeGame} />

<div class="chat-page">
	<div class="chat-page-wrapper">
		{#if $userStore.uid === ''}
			<div style="color: white;">Loading app...</div>
		{:else}
			<div class="chat-view">
				<div class="friend-seek-wrapper box">
					<div class="friend-seek">
						<img src={search} class="icon" alt="Search" />
						<input
							bind:value={searchName}
							class="search-bar"
							name="search"
							type="text"
							disabled={isSearching}
							placeholder="Search"
						/>

						{#if requestList}
							<RevealButton
								src={close}
								alt="Close"
								label="Close Tab"
								on:click={() => {
									requestList = false;
								}}
							/>
						{:else}
							<RevealButton
								src={add}
								alt="Add Friend"
								label="Add Friend"
								on:click={handleSendRequest}
							/>
							<RevealButton
								src={request}
								alt="Requests"
								label="Requests"
								on:click={() => {
									requestList = true;
								}}
							/>
						{/if}
					</div>
					{#if requestList}
						<div class="more-friends" in:fade={{ duration: 400, easing: quintInOut }}>
							<button class="box"> Create GroupPlay </button>
							<span class="requests-label"> Requests </span>
							<div class="requests">
								{#each $requests as item (item.id)}
									<Request request={item} />
								{:else}
									<span class="none-label">No Requests</span>
								{/each}
							</div>
						</div>
					{/if}
				</div>
				<div class="box">
					<div class="chat-list-wrapper">
						<span class="chat-list-label">Playgrounds</span>
						<div class="chat-list panel">
							{#each $playgrounds as item (item.id)}
								<ChatItem chatItem={item} />
							{:else}
								<span class="none-label">No Playgrounds</span>
							{/each}
						</div>
					</div>
				</div>
				<div class="info panel box">
					<div class="icon-placeholder"></div>
					<p class="chat-title">{$userStore.username}</p>
					<button class="sign-out" on:click={handleLogOut}>Sign out</button>
				</div>
			</div>
			<div class="playground-view">
				<div class="info panel box">
					<div class="icon-placeholder"></div>
					<p class="chat-title">{$currentChat.chatName}</p>
				</div>
				<div class="box panel">
					<div class="plays">
						{#each $currentChat.gameArray as item (item.id)}
							<!-- Send the id as well... -->
							<GameBubble gameData={item} id={item.id} on:click={openGame} />
						{/each}
					</div>
				</div>
				<div class="game-options panel box">
					{#each gameOptions as game (game.key)}
						<GameOption {game} />
					{/each}
				</div>
			</div>
		{/if}
	</div>
</div>

<style>
	.none-label {
		color: rgba(255, 255, 255, 0.2);
	}

	.chat-page {
		position: absolute;
		width: 100vw;
		height: 100vh;

		background-color: rgb(28, 28, 28);
	}

	.chat-page-wrapper {
		display: grid;
		box-sizing: border-box;
		gap: 8px;

		grid-auto-flow: column;
		grid-template-columns: auto 1fr;

		width: 100%;
		height: 100%;

		padding: 8px;
	}

	.chat-view {
		display: grid;
		grid-template-rows: auto 1fr 48px;
		gap: 8px;

		max-width: 300px;
		height: 100%;

		min-height: 0;
	}

	.chat-list {
		padding: 0;
		margin: 0;

		display: grid;
		gap: 2px;

		border-radius: 16px;
		background-color: rgba(255, 255, 255, 0.037);
	}

	.chat-list-wrapper {
		display: flex;
		flex-direction: column;

		height: 100%;
		box-sizing: border-box;

		overflow: auto;
		scrollbar-width: none;
	}

	.chat-list-label {
		color: rgba(255, 255, 255, 0.498);
		margin: 8px 12px;
		margin-top: 0;

		font-weight: 500;
	}

	.plays {
		display: flex;
		flex-direction: column-reverse;

		padding: 8px;

		gap: 8px;

		height: 100%;
		box-sizing: border-box;

		overflow: auto;
		scrollbar-width: none;
	}

	.playground-view {
		display: grid;
		grid-template-rows: 48px 1fr 120px;

		gap: 8px;
		min-width: 360px;
		min-height: 0;
	}

	.sign-out {
		all: unset;

		display: grid;
		justify-content: center;

		background-color: rgb(203, 68, 68);
		font-size: 0.75rem;
		font-weight: 500;

		font-family: inherit;

		border-radius: 99px;

		margin: 8px;
		padding: 4px;
		cursor: pointer;
	}

	.icon-placeholder {
		width: 24px;
		height: 24px;

		background-color: rgba(255, 255, 255, 0.769);
		border-radius: 999px;

		margin: 8px;
	}

	.friend-seek-wrapper {
		display: flex;
		flex-direction: column;
		gap: 12px;

		padding: 12px;
		background-color: rgba(0, 0, 0, 0.2);
	}

	.friend-seek {
		display: grid;
		grid-template-columns: auto 1fr auto auto;

		align-items: center;
		gap: 8px;
	}

	.search-bar {
		all: unset;
		color: white;

		box-sizing: border-box;

		width: 100%;
		height: 24px;

		font-weight: 600;
		font-size: 1.25rem;
	}

	.more-friends {
		margin: 8px 0;
		display: flex;
		flex-direction: column;

		gap: 8px;
		font-weight: 600;
	}

	.more-friends button {
		font-family: inherit;
		padding: 12px;

		border: none;
		font-weight: 600;
		font-size: 1rem;

		color: rgba(255, 255, 255, 0.801);
		background-color: rgb(78, 136, 170);
		cursor: pointer;
	}

	.requests-label {
		color: rgba(255, 255, 255, 0.425);
	}

	.requests {
		display: grid;
		gap: 8px;
	}

	.info {
		display: grid;

		grid-template-columns: auto 1fr 90px;
		gap: 4px;

		align-items: center;

		padding: 0 4px;

		color: white;
	}

	.box {
		border-radius: 16px;
		overflow: hidden;
	}

	.panel {
		box-shadow:
			inset 0 0 4px rgba(255, 255, 255, 0.025),
			inset 0 0 4px rgba(255, 255, 255, 0.02);
		background-color: rgb(33, 33, 33);
	}

	.chat-title {
		font-size: 1.25rem;
		font-weight: 600;

		width: 100%;
		margin: 0;
	}

	.icon {
		width: 20px;
		height: 18px;
	}

	.game-options {
		box-shadow:
			inset 0 0 4px rgba(255, 255, 255, 0.02),
			inset 0 0 4px rgba(255, 255, 255, 0.025),
			inset 0 0 32px rgb(33, 33, 33),
			inset 0 0 32px rgb(33, 33, 33),
			inset 0 0 64px rgb(33, 33, 33),
			inset 0 0 128px rgb(33, 33, 33);

		background-image: radial-gradient(circle, rgba(255, 255, 255, 0.04) 1px, transparent 2px);

		background-size: 16px 16px;
		background-position: 4px 0;

		width: 100%;
		height: 100%;

		display: flex;
		flex-direction: row;
		padding: 8px;

		box-sizing: border-box;
	}
</style>
