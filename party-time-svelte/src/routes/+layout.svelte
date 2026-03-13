<script>
	import favicon from '$lib/assets/favicon.svg';
	import { Toaster, toast } from 'svelte-sonner';
	import { onMount } from 'svelte';
	import { auth, db, rtdb } from '$lib/firebase';
	import { onAuthStateChanged } from 'firebase/auth';
	import { addDoc, collection, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';
	import { userStore } from '$lib/userData';
	import { goto } from '$app/navigation';
	import '../app.css';
	import { currentChat, playgrounds, requests } from '$lib/appData';

	onMount(() => {
		const unsubscribe = onAuthStateChanged(auth, async (user) => {
			console.log('Hello World!');
			if (!user) {
				goto('/');

				$userStore.username = '';
				$playgrounds = [];
				$requests = [];
			}
		});
		return () => unsubscribe();
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
