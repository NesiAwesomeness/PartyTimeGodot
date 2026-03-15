<script>
	import { app } from '$lib/app.svelte';
	let { request } = $props();
</script>

<div class="w-full p-3 grid grid-cols-[1fr_auto_auto] box-border rounded-2xl bg-white/[0.078]">
	<span class="text-white text-xl px-2 self-center">{request.username}</span>
	<button
		title="Accept"
		onclick={app.handleAcceptRequest(request)}
		class="h-full p-0 bg-transparent border-none grid place-items-center gap-[2px] cursor-pointer after:content-[''] after:col-start-1 after:row-start-1 after:relative after:w-3 after:h-3 after:bg-white after:rounded-full after:z-0"
	>
		<svg
			viewBox="72 -880 810 810"
			fill="rgb(68, 203, 68)"
			class="col-start-1 row-start-1 w-6 h-6 mx-2 z-10"
		>
			<path
				d="m424-408-86-86q-11-11-28-11t-28 11q-11 11-11 28t11 28l114 114q12 12 28 12t28-12l226-226q11-11 11-28t-11-28q-11-11-28-11t-28 11L424-408Zm56 328q-83 0-156-31.5T197-197q-54-54-85.5-127T80-480q0-83 31.5-156T197-763q54-54 127-85.5T480-880q83 0 156 31.5T763-763q54 54 85.5 127T880-480q0 83-31.5 156T763-197q-54 54-127 85.5T480-80Z"
			/>
		</svg>
	</button>
	<button
		title="Reject"
		onclick={app.handleDeclineRequest(request)}
		class="h-full p-0 bg-transparent border-none grid place-items-center gap-[2px] cursor-pointer after:content-[''] after:col-start-1 after:row-start-1 after:relative after:w-3 after:h-3 after:bg-white after:rounded-full after:z-0"
	>
		<svg
			viewBox="0 0 512 512"
			xml:space="preserve"
			fill="rgb(203, 68, 68)"
			class="col-start-1 row-start-1 w-6 h-6 mx-2 z-10"
		>
			<path
				d="M256,0C114.615,0,0,114.615,0,256s114.615,256,256,256s256-114.615,256-256C511.847,114.678,397.322,0.153,256,0z M341.333,311.189c8.669,7.979,9.229,21.475,1.25,30.144c-7.979,8.669-21.475,9.229-30.144,1.25c-0.434-0.399-0.85-0.816-1.25-1.25   L256,286.165l-55.168,55.168c-8.475,8.185-21.98,7.95-30.165-0.525c-7.984-8.267-7.984-21.373,0-29.64L225.835,256l-55.168-55.168   c-8.185-8.475-7.95-21.98,0.525-30.165c8.267-7.984,21.373-7.984,29.64,0L256,225.835l55.189-55.168   c7.979-8.669,21.475-9.229,30.144-1.25c8.669,7.979,9.229,21.475,1.25,30.144c-0.399,0.434-0.816,0.85-1.25,1.25L286.165,256   L341.333,311.189z"
			/>
		</svg>
	</button>
</div>
