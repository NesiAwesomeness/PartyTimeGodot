<script>
	import { userStore } from '$lib/userData';
	import { playgrounds, currentChat, requests, requestsSent, toDisplayName } from '$lib/appData';

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

	import { goto } from '$app/navigation';
	import { auth, db, rtdb } from '$lib/firebase';
	import { get, ref, set } from 'firebase/database';

	import {
		addDoc,
		collection,
		doc,
		getDocs,
		onSnapshot,
		query,
		setDoc,
		where
	} from 'firebase/firestore';

	let loading = true;
	let username = 'Username';

	let newRequest = false;
	let requestUnsub = null;
	let playgroundUnsub = null;

	let isSearching = false;

	let signOutModal = false;
	let addFriendModal = false;

	$: memberList = $currentChat?.members ? Object.values($currentChat.members) : [];
	$: isGroup = $currentChat?.isGroup;

	onMount(() => {
		$currentChat = {
			chatName: 'Playground Name',
			id: ''
		};

		fetchPlaygroundData($userStore.uid);
	});

	onDestroy(() => {
		stopListening();
	});

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
				tempItems.sort((a, b) => b.timestamp - a.timestamp);
				$playgrounds = tempItems;
			});

			const requestsRef = collection(db, 'users', uid, 'requests');

			requestUnsub = onSnapshot(requestsRef, (snapshot) => {
				let tempItems = [];
				snapshot.forEach((doc) => {
					tempItems.push({ id: doc.id, ...doc.data() });
				});
				tempItems.sort((a, b) => b.timestamp - a.timestamp);
				$requests = tempItems;

				console.log('New Requests', tempItems);

				// const latestRequest = tempItems.reduce(
				// 	(max, request) => (request.timestamp > max.timestamp ? game : max),
				// 	{ timestamp: $userStore.lastCheckedRequests || 0 }
				// );

				// newRequest = latestRequest.timestamp > $userStore.lastCheckedRequests;
				// Updates the requests received by the current user
			});
		}
	}

	let chatContainer = null;

	$: if ($currentChat.gameArray && chatContainer) {
		// Wait for the DOM to update with the new item
		setTimeout(() => {
			chatContainer.scrollTo({
				top: chatContainer.scrollHeight,
				behavior: 'smooth'
			});
		}, 50);
	}

	let gameOptions = [];

	$: if ($currentChat) displayGameOptions();

	function displayGameOptions() {
		gameOptions = $games;
	}

	let requestList = false;
	let searchName = '';
	let friendName = '';

	import { flip } from 'svelte/animate';
	import { fly, fade } from 'svelte/transition';

	import { quintInOut } from 'svelte/easing';
	import { spring } from 'svelte/motion';

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

	import { signOut } from 'firebase/auth';
	import Modal from '$lib/components/Modal.svelte';
	import Loader from '$lib/components/Loader.svelte';
	import { toast } from 'svelte-sonner';

	$: friendsResult = $playgrounds;

	function handleFindFriend(e) {
		const friend = e.currentTarget.value.toLowerCase();
		if (friend !== '') {
			isSearching = true;
		} else {
			friendsResult = $playgrounds;
			isSearching = false;
		}

		friendsResult = $playgrounds.filter(({ chatName }) => chatName.toLowerCase().includes(friend));
	}

	let isRequesting = false;

	async function handleSendRequest() {
		if (!friendName) return;

		isRequesting = true;

		try {
			// 2. Query the 'users' collection where username == friendUsername
			const usersRef = collection(db, 'users');
			const q = query(usersRef, where('username', '==', friendName));

			const querySnapshot = await getDocs(q);
			const searchedName = friendName;

			friendName = '';
			isRequesting = false;

			if (querySnapshot.empty) {
				// use toast here...?
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
			isRequesting = false;
		}
	}

	async function handleLogOut() {
		try {
			await signOut(auth);
			stopListening();
		} catch (error) {
			console.error('Error signing out:', error.message);
		}
	}

	// Modal state
	let addGroupModal = false;

	// Form state
	let groupName = '';
	let selectedChats = [];

	// Derived state: Filter out existing groups to only show individual friends
	$: eligibleChats = $playgrounds.filter((chat) => !chat.isGroup);

	// Validation: Must have a name and at least 2 people selected
	$: canCreateGroup = groupName.trim() !== '' && selectedChats.length >= 2;

	function toggleChatSelection(chatId) {
		if (selectedChats.includes(chatId)) {
			// Remove if already selected
			selectedChats = selectedChats.filter((id) => id !== chatId);
		} else {
			// Add if not selected
			selectedChats = [...selectedChats, chatId];
		}
	}

	async function handleCreateGroup() {
		if (!canCreateGroup || !$userStore || !$userStore.uid) return;

		const userID = $userStore.uid;
		const myUsername = $userStore.username;
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

		// Cache group name before clearing and hiding UI immediately
		const finalGroupName = groupName;
		closeGroupModal();

		try {
			// 1. Create document in my playgrounds (auto-generates the group ID)
			const myPlaygroundsRef = collection(db, 'users', userID, 'playgrounds');
			const groupData = {
				chatName: finalGroupName,
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

	function closeGroupModal() {
		addGroupModal = false;
		groupName = '';
		selectedChats = [];

		requestList = false;
	}
</script>

<svelte:window on:resize={handleResize} />

<GodotHolder rect={$holderBounds} {isGameOpen} on:click={closeGame} />

<Modal bind:isOpen={signOutModal} class="flex justify-center items-center">
	<h3 class="text-xl text-center max-w-[250px]">Are you sure you want to Sign out?</h3>
	<div class="flex justify-center items-center gap-[10px] mt-[30px]">
		<button
			on:click={() => {
				signOutModal = false;
			}}
			class="px-[16px] py-[2px] rounded-full bg-[white] text-black">No</button
		>
		<button class="px-[16px] py-[2px] rounded-full bg-[#cb4444]" on:click={handleLogOut}>Yes</button
		>
	</div>
</Modal>

<Modal bind:isOpen={addFriendModal} class="flex justify-center items-center">
	<div class="w-full max-w-[400px] p-4">
		<div
			class="relative flex items-center bg-[#161616] rounded-full p-1.5 pl-10 border border-white/10 focus-within:border-gray-500"
		>
			<input
				bind:value={friendName}
				class="flex-grow text-white text-sm h-8 bg-transparent focus:outline-none placeholder-white/30 px-2"
				name="search"
				type="text"
				placeholder="Paste Username Here"
				disabled={isRequesting}
			/>

			<button
				class="bg-white/10 flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center disabled:opacity-50 disabled:cursor-not-allowed"
				on:click={handleSendRequest}
				disabled={isRequesting}
			>
				{#if isRequesting}
					<span class="text-white text-xs">...</span>
				{:else}
					<img src={add} class="w-4 h-4" alt="Add Friend" />
				{/if}
			</button>
		</div>
	</div>
</Modal>

<Modal bind:isOpen={addGroupModal} on:close={closeGroupModal}>
	<div class="w-full max-w-[400px] flex flex-col gap-5 p-2 box-border">
		<div class="flex justify-between items-center px-1">
			<h2 class="text-white text-xl font-semibold m-0">Create Group</h2>
		</div>

		<div
			class="relative flex items-center bg-[#161616] rounded-xl p-2.5 border border-white/10 focus-within:border-gray-500"
		>
			<input
				bind:value={groupName}
				class="flex-grow text-white text-sm h-8 bg-transparent focus:outline-none placeholder-white/30 px-2"
				type="text"
				placeholder="Group Name"
			/>
		</div>

		<div class="flex flex-col gap-2">
			<span class="text-white/40 text-xs font-medium uppercase tracking-wider px-1 mb-1"
				>Select Friends</span
			>

			<div
				class="flex flex-col bg-[#161616] rounded-xl border border-white/10 max-h-[40vh] overflow-y-auto overflow-x-hidden [scrollbar-width:thin] [&::-webkit-scrollbar]:w-1.5 [&::-webkit-scrollbar-thumb]:bg-white/10 [&::-webkit-scrollbar-thumb]:rounded-full"
			>
				{#each eligibleChats as chat (chat.id)}
					<button
						class="flex items-center justify-between p-3.5 transition-colors text-left cursor-pointer border-b border-white/5 last:border-b-0
                        {selectedChats.includes(chat.id)
							? 'bg-white/10'
							: 'bg-transparent hover:bg-white/5'}"
						on:click={() => toggleChatSelection(chat.id)}
					>
						<span class="text-white text-sm font-medium">{chat.chatName}</span>

						<div
							class="w-5 h-5 rounded-full border flex items-center justify-center transition-colors shrink-0
                        {selectedChats.includes(chat.id)
								? 'bg-gray-400 border-gray-400'
								: 'border-white/20'}"
						>
							{#if selectedChats.includes(chat.id)}
								<svg
									class="w-3.5 h-3.5 text-[#161616]"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="3"
										d="M5 13l4 4L19 7"
									></path>
								</svg>
							{/if}
						</div>
					</button>
				{:else}
					<div class="text-white/30 text-sm text-center py-6">No friends available to add.</div>
				{/each}
			</div>
		</div>

		<button
			class="mt-1 w-full bg-gray-200 text-[#161616] font-bold text-sm h-11 rounded-xl flex items-center justify-center disabled:bg-white/10 disabled:text-white/30 disabled:cursor-not-allowed transition-colors cursor-pointer"
			on:click={handleCreateGroup}
			disabled={!canCreateGroup}
		>
			Create Group
		</button>
	</div>
</Modal>

<div class="absolute w-screen h-screen bg-[#1c1c1c]">
	<!-- Custom aspect ratio AND max-width modifiers replacing portrait/landscape -->
	<div
		class="grid box-border gap-2 [@media(min-width:650px)_and_(min-aspect-ratio:4/5)]:grid-flow-col [@media(min-width:650px)_and_(min-aspect-ratio:4/5)]:grid-cols-[auto_1fr] [@media(max-width:649px),(max-aspect-ratio:4/5)]:grid-cols-1 w-full h-full p-2"
	>
		{#if $userStore.uid === ''}
			<div class="flex justify-center items-center w-screen h-screen"><Loader size={64} /></div>
		{:else}
			<!-- Chat View -->
			<div
				class="grid grid-rows-[auto_1fr_48px] gap-2 w-full [@media(min-width:650px)_and_(min-aspect-ratio:4/5)]:max-w-[300px] h-full min-h-0 {$currentChat.id !=
				''
					? '[@media(max-width:649px),(max-aspect-ratio:4/5)]:hidden'
					: ''}"
			>
				<div class="flex flex-col gap-3 p-3 bg-black/20 rounded-2xl overflow-hidden">
					<div class="grid grid-cols-[auto_1fr_auto_auto] items-center gap-2">
						<img src={search} class="w-5 h-[18px]" alt="Search" />
						<input
							bind:value={searchName}
							class="appearance-none bg-transparent text-white box-border w-full h-6 font-semibold text-xl focus:outline-none"
							name="search"
							type="text"
							placeholder="Search"
							on:input={handleFindFriend}
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
								src={request}
								alt="Requests"
								label="Friends"
								on:click={() => {
									requestList = true;
									$userStore.lastCheckedRequests = Date.now();
								}}
							/>
						{/if}
					</div>
					{#if requestList}
						<div
							class="my-2 flex flex-col gap-2 font-semibold"
							in:fade={{ duration: 400, easing: quintInOut }}
						>
							<button
								class="font-[inherit] p-3 border-none font-semibold text-base text-white/80 bg-[#4e88aa] cursor-pointer rounded-2xl overflow-hidden"
								on:click={() => {
									requestList = false;
									addFriendModal = true;
								}}
							>
								Add Friend
							</button>
							<button
								class="font-[inherit] p-3 border-none font-semibold text-base text-white/80 bg-[#4e88aa] cursor-pointer rounded-2xl overflow-hidden"
								on:click={() => {
									addGroupModal = true;
									requestList = false;
								}}
							>
								Create Group
							</button>
							<span class="text-white/40"> Requests </span>
							<div class="grid gap-2">
								{#each $requests as item (item.id)}
									<Request request={item} />
								{:else}
									<span class="text-white/20 p-4">No Requests</span>
								{/each}
							</div>
						</div>
					{/if}
				</div>
				<div class="rounded-2xl overflow-hidden">
					<div
						class="flex flex-col h-full box-border overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
					>
						<span class="text-white/50 mx-3 mb-2 mt-0 font-medium">Playgrounds</span>
						<div
							class="p-0 m-0 grid gap-0.5 rounded-2xl bg-[#212121] shadow-[inset_0_0_4px_rgba(255,255,255,0.025),inset_0_0_4px_rgba(255,255,255,0.02)]"
						>
							{#each friendsResult as item, i (item.id)}
								<div
									animate:flip={{ duration: 400 }}
									in:fly={{ y: 20, duration: 300, delay: i * 50 }}
								>
									<ChatItem chatItem={item} />
								</div>
							{:else}
								<span class="text-white/20 p-4">No Playgrounds</span>
							{/each}
						</div>
					</div>
				</div>
				<div
					class="grid grid-cols-[auto_1fr_90px] gap-1 items-center px-1 text-white bg-[#212121] shadow-[inset_0_0_4px_rgba(255,255,255,0.025),inset_0_0_4px_rgba(255,255,255,0.02)] rounded-2xl overflow-hidden"
				>
					<div class="w-6 h-6 bg-white/75 rounded-full m-2 shrink-0"></div>
					<p class="text-xl font-semibold w-full m-0 truncate">{$userStore.username}</p>
					<button
						class="appearance-none grid justify-center bg-[#cb4444] text-xs font-medium rounded-full m-2 p-1 cursor-pointer"
						on:click={() => {
							signOutModal = true;
						}}>Sign out</button
					>
				</div>
			</div>

			<!-- Playground View -->
			<div
				class="grid gap-2 w-full [@media(min-width:650px)_and_(min-aspect-ratio:4/5)]:min-w-[360px] min-h-0 {$currentChat.id ==
				''
					? '[@media(max-width:649px),(max-aspect-ratio:4/5)]:hidden'
					: ''}"
				style="
                grid-template-rows: 48px 1fr {$currentChat.id != '' ? '120px' : ''};
            "
			>
				<div
					class="flex items-center px-1 text-white bg-[#212121] shadow-[inset_0_0_4px_rgba(255,255,255,0.025),inset_0_0_4px_rgba(255,255,255,0.02)] rounded-2xl overflow-hidden h-full"
				>
					<!-- Back Button -->
					<button
						title="back"
						class="[@media(max-width:649px),(max-aspect-ratio:4/5)]:flex [@media(min-width:650px)_and_(min-aspect-ratio:4/5)]:hidden appearance-none bg-transparent border-none p-2 ml-1 cursor-pointer items-center justify-center rounded-full hover:bg-white/10 transition-colors"
						on:click={() => {
							$currentChat = { chatName: 'Playground Name', id: '', gameArray: [] };
						}}
					>
						<svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2.5"
								d="M15 19l-7-7 7-7"
							/>
						</svg>
					</button>

					<!-- Replaced DIV with SVG Circle and added shrink-0 -->
					<svg class="w-6 h-6 m-2 shrink-0" viewBox="0 0 24 24">
						<circle cx="12" cy="12" r="12" fill="rgba(255, 255, 255, 0.75)" />
					</svg>

					<p class="text-xl font-semibold w-full m-0 truncate">
						{toDisplayName($currentChat.chatName)}
					</p>

					{#if isGroup}
						<div
							style="display: flex; justify-content: flex-end; align-items: center; gap: 8px; margin-right: 8px;"
						>
							{#each memberList as mem}
								<span class="bg-[#454545] text-xs font-medium px-2 py-1 rounded-full"
									>@{mem.toLocaleLowerCase()}</span
								>
							{/each}
						</div>
					{/if}
				</div>
				<div
					class="rounded-2xl overflow-hidden bg-[#212121] shadow-[inset_0_0_4px_rgba(255,255,255,0.025),inset_0_0_4px_rgba(255,255,255,0.02)]"
				>
					<div
						class="flex flex-col-reverse p-2 gap-2 h-full box-border overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
						bind:this={chatContainer}
					>
						{#if $currentChat.members !== []}
							{#each $currentChat.gameArray as item, i (item.id)}
								<div
									animate:flip={{ duration: 400 }}
									in:fly={{ y: 20, duration: 300, delay: i * 50 }}
								>
									<GameBubble gameData={item} id={item.id} on:click={openGame} />
								</div>
							{/each}
						{/if}
					</div>
				</div>
				{#if $currentChat.id != ''}
					<div
						class="w-full h-full flex flex-row gap-2 p-2 box-border rounded-2xl overflow-hidden bg-[#212121] shadow-[inset_0_0_4px_rgba(255,255,255,0.02),inset_0_0_4px_rgba(255,255,255,0.025),inset_0_0_32px_#212121,inset_0_0_32px_#212121,inset_0_0_64px_#212121,inset_0_0_128px_#212121] bg-[radial-gradient(circle,rgba(255,255,255,0.04)_0.5px,transparent_1.5px)] bg-[size:12px_12px] bg-[position:2px_0]"
					>
						{#each gameOptions as game (game.key)}
							<GameOption {game} />
						{/each}
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>
