<script>
	import favicon from '$lib/assets/favicon.svg';
	import { Toaster, toast } from 'svelte-sonner';
	import { onMount } from 'svelte';
	import { auth, db, rtdb } from '$lib/firebase';
	import { onAuthStateChanged } from 'firebase/auth';
	import { addDoc, collection, doc, getDoc, getDocs, setDoc, updateDoc } from 'firebase/firestore';
	import { userStore } from '$lib/userData';
	import { goto } from '$app/navigation';
	import '../app.css';
	import { currentChat, playgrounds, requests, toDisplayName } from '$lib/appData';
	import { app } from '$lib/app.svelte';

	onMount(() => {
		app.start();
	});

	$effect(() => {
		console.log(app.uid, 'from effect');
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
