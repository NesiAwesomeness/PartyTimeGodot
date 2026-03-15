<script>
	import favicon from '$lib/assets/favicon.svg';
	import { Toaster, toast } from 'svelte-sonner';
	import { onMount } from 'svelte';
	import { auth, db, rtdb } from '$lib/firebase';
	import { addDoc, collection, doc, getDoc, getDocs, setDoc, updateDoc } from 'firebase/firestore';
	import { goto } from '$app/navigation';
	import '../app.css';
	import { app } from '$lib/app.svelte';
	import { page } from '$app/state';

	onMount(() => {
		app.init();
	});

	$effect(() => {
		// Wait until Firebase has actually checked the user status
		if (!app.isInitialized) return;

		const isAtLoginScreen = page.url.pathname === '/';

		if (app.uid && isAtLoginScreen) {
			goto('/chat');
		} else if (!app.uid && !isAtLoginScreen) {
			goto('/');
		}
	});
	let { children } = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

{@render children()}
<Toaster richColors />

<style>
	:global(html),
	:global(body) {
		overflow: hidden;
		font-family: 'Funnel Display', sans-serif;
	}
</style>
