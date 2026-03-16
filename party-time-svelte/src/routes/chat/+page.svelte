<script>
	import { toDisplayName } from '$lib/appData';
	import { onDestroy, onMount } from 'svelte';
	import { games } from '$lib/appData';

	import search from '$lib/assets/search.svg';
	import add from '$lib/assets/add.svg';
	import request from '$lib/assets/users.svg';
	import close from '$lib/assets/cross-circle-red.svg';

	import ChatItem from '$lib/components/ChatItem.svelte';
	import GameBubble from '$lib/components/GameBubble.svelte';
	import GameOption from '$lib/components/GameOption.svelte';
	import RevealButton from '$lib/interfaces/RevealButton.svelte';
	import Request from '$lib/components/Request.svelte';
	import Modal from '$lib/interfaces/Modal.svelte';
	import Loader from '$lib/interfaces/Loader.svelte';

	import { auth } from '$lib/firebase';
	import { app } from '$lib/app.svelte';

	let signOutModal = $state(false);
	let addFriendModal = $state(false);

	let memberList = $derived(app.currentChat?.members ? Object.values(app.currentChat.members) : []);
	let gameOptions = $derived(memberList.length > 1 ? games : []);
	let isGroup = $derived(app.currentChat?.isGroup);

	onMount(() => {
		app.resetCurrentChat();
	});

	let chatContainer = $state(null);

	$effect(() => {
		if (chatContainer && app.currentChat.gameArray) {
			setTimeout(() => {
				chatContainer.scrollTo({
					top: chatContainer.scrollHeight,
					behavior: 'smooth'
				});
			}, 50);
		}
	});

	let requestList = $state(false);

	let searchName = $state('');
	let searchResults = $derived(
		searchName === ''
			? app.playgrounds
			: app.playgrounds.filter(({ chatName }) =>
					chatName.toLowerCase().includes(searchName.toLowerCase())
				)
	);

	let friendName = $state('');

	import { flip } from 'svelte/animate';
	import { fly, fade } from 'svelte/transition';

	import { quintInOut } from 'svelte/easing';
	import { spring } from 'svelte/motion';

	import GodotHolder from '$lib/components/GodotHolder.svelte';

	let lastClickedRect = null;
	let isGameOpen = $state(false);

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

	async function handleLogOut() {
		try {
			await signOut(auth);
		} catch (error) {
			console.error('Error signing out:', error.message);
		}
	}

	// Modal state
	let addGroupModal = $state(false);

	// Form state
	let groupName = $state('');
	let selectedChats = $state([]);

	let eligibleChats = app.playgrounds.filter((chat) => !chat.isGroup);
	let canCreateGroup = $derived(groupName.trim() !== '' && selectedChats.length >= 2);

	function toggleChatSelection(chatId) {
		if (selectedChats.includes(chatId)) {
			// Remove if already selected
			selectedChats = selectedChats.filter((id) => id !== chatId);
		} else {
			// Add if not selected
			selectedChats = [...selectedChats, chatId];
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

<GodotHolder rect={$holderBounds} on:click={closeGame} />

<Modal bind:isOpen={signOutModal} class="flex justify-center items-center">
	<h3 class="text-xl text-center max-w-[250px]">Are you sure you want to Sign out?</h3>
	<div class="flex justify-center items-center gap-[10px] mt-[30px]">
		<button
			onclick={() => {
				signOutModal = false;
			}}
			class="px-[16px] py-[2px] rounded-full bg-[white] text-black">No</button
		>
		<button class="px-[16px] py-[2px] rounded-full bg-[#cb4444]" onclick={handleLogOut}>Yes</button>
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
				disabled={app.isRequesting}
			/>

			<button
				class="bg-white/10 flex-shrink-0 w-8 h-8 rounded-full flex
				items-center justify-center disabled:opacity-50 disabled:cursor-not-allowed"
				onclick={() => {
					app.handleSendRequest(friendName);
					friendName = '';
				}}
				disabled={app.isRequesting}
			>
				{#if app.isRequesting}
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
				class="flex flex-col bg-[#161616] rounded-xl border border-white/10 max-h-[40vh] overflow-y-auto overflow-x-hidden
				[scrollbar-width:thin] [&::-webkit-scrollbar]:w-1.5 [&::-webkit-scrollbar-thumb]:bg-white/10 [&::-webkit-scrollbar-thumb]:rounded-full"
			>
				{#each eligibleChats as chat (chat.id)}
					<button
						class="flex items-center justify-between p-3.5 transition-colors text-left cursor-pointer border-b border-white/5 last:border-b-0
                        {selectedChats.includes(chat.id)
							? 'bg-white/10'
							: 'bg-transparent hover:bg-white/5'}"
						onclick={() => toggleChatSelection(chat.id)}
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
			class="mt-1 w-full bg-gray-200 text-[#161616] font-bold text-sm h-11 rounded-xl flex items-center
			justify-center disabled:bg-white/10 disabled:text-white/30 disabled:cursor-not-allowed transition-colors cursor-pointer"
			disabled={!canCreateGroup}
			onclick={() => {
				app.handleCreateGroup(groupName, selectedChats);
				closeGroupModal();
			}}
		>
			Create Group
		</button>
	</div>
</Modal>

<div class="absolute w-screen h-screen bg-[#1c1c1c]">
	<!-- Custom aspect ratio AND max-width modifiers replacing portrait/landscape -->
	<div
		class="grid box-border gap-2 [@media(min-width:650px)_and_(min-aspect-ratio:4/5)]:grid-flow-col
		[@media(min-width:650px)_and_(min-aspect-ratio:4/5)]:grid-cols-[auto_1fr] [@media(max-width:649px),(max-aspect-ratio:4/5)]:grid-cols-1 w-full h-full p-2"
	>
		{#if app.uid === ''}
			<div class="flex justify-center items-center w-screen h-screen"><Loader size={64} /></div>
		{:else}
			<!-- Chat View -->
			<div
				class="grid grid-rows-[auto_1fr_48px] gap-2 w-full [@media(min-width:650px)_and_(min-aspect-ratio:4/5)]:max-w-[300px] h-full min-h-0 {app
					.currentChat.id != ''
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
									app.lastCheckedRequests = Date.now();
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
								onclick={() => {
									requestList = false;
									addFriendModal = true;
								}}
							>
								Add Friend
							</button>
							<button
								class="font-[inherit] p-3 border-none font-semibold text-base text-white/80 bg-[#4e88aa] cursor-pointer rounded-2xl overflow-hidden"
								onclick={() => {
									addGroupModal = true;
									requestList = false;
								}}
							>
								Create Group
							</button>
							<span class="text-white/40"> Requests </span>
							<div class="grid gap-2">
								{#each app.requests as item (item.id)}
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
							{#each searchResults as item, i (item.id)}
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
					<p class="text-xl font-semibold w-full m-0 truncate">{app.username}</p>
					<button
						class="appearance-none grid justify-center bg-[#cb4444] text-xs font-medium rounded-full m-2 p-1 cursor-pointer"
						onclick={() => {
							signOutModal = true;
						}}>Sign out</button
					>
				</div>
			</div>

			<!-- Playground View -->
			<div
				class="grid gap-2 w-full [@media(min-width:650px)_and_(min-aspect-ratio:4/5)]:min-w-[360px] min-h-0 {app
					.currentChat.id == ''
					? '[@media(max-width:649px),(max-aspect-ratio:4/5)]:hidden'
					: ''}"
				style="
                grid-template-rows: 48px 1fr {app.currentChat.id != '' ? '120px' : ''};
            "
			>
				<div
					class="flex items-center px-1 text-white bg-[#212121] shadow-[inset_0_0_4px_rgba(255,255,255,0.025),inset_0_0_4px_rgba(255,255,255,0.02)] rounded-2xl overflow-hidden h-full"
				>
					<!-- Back Button -->
					<button
						title="back"
						class="[@media(max-width:649px),(max-aspect-ratio:4/5)]:flex [@media(min-width:650px)_and_(min-aspect-ratio:4/5)]:hidden
						appearance-none bg-transparent border-none p-2 ml-1 cursor-pointer items-center justify-center rounded-full hover:bg-white/10 transition-colors"
						onclick={() => {
							app.resetCurrentChat();
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
						{toDisplayName(app.currentChat.chatName)}
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
				{#if app.currentChat.members !== []}
					<div
						class="rounded-2xl overflow-hidden bg-[#212121] shadow-[inset_0_0_4px_rgba(255,255,255,0.025),inset_0_0_4px_rgba(255,255,255,0.02)]"
					>
						<div
							class="flex flex-col-reverse p-2 gap-2 h-full box-border overflow-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
							bind:this={chatContainer}
						>
							{#each app.currentChat.gameArray as item, i (item.id)}
								<div
									animate:flip={{ duration: 400 }}
									in:fly={{ y: 20, duration: 300, delay: i * 50 }}
								>
									<GameBubble gameData={item} id={item.id} on:click={openGame} />
								</div>
							{/each}
						</div>
					</div>
					{#if app.currentChat.id != ''}
						<div
							class="w-full h-full flex flex-row gap-2 p-2 box-border rounded-2xl overflow-hidden bg-[#212121] shadow-[inset_0_0_4px_rgba(255,255,255,0.02),inset_0_0_4px_rgba(255,255,255,0.025),inset_0_0_32px_#212121,inset_0_0_32px_#212121,inset_0_0_64px_#212121,inset_0_0_128px_#212121] bg-[radial-gradient(circle,rgba(255,255,255,0.04)_0.5px,transparent_1.5px)] bg-[size:12px_12px] bg-[position:2px_0]"
						>
							{#each gameOptions as option (option.key)}
								<GameOption {option} />
							{/each}
						</div>
					{/if}
				{/if}
			</div>
		{/if}
	</div>
</div>
