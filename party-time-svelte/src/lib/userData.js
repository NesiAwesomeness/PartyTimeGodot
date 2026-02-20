import { writable } from 'svelte/store';

export const userStore = writable({
	uid: "", username: "",
	lastCheckedRequests: 0.0
});