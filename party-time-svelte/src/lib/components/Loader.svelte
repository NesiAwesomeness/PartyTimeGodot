<script>
	export let size;
</script>

<div
	style="
    width: {size}px;
	height: {size}px;
    "
	class="relative"
>
	<div
		class="border-[6px] w-full left-0 top-0 h-full border-[#0F0F0F] rounded-[50%] absolute"
	></div>
	<div
		class="border-[6px] w-full left-0 top-0 h-full rounded-[50%] border-x-[transparent] spinner rotate-0 border-[#0F0F0F] border-t-white absolute"
	></div>
</div>

<style>
	.spinner {
		animation: spin 0.6s infinite linear;
	}

	@keyframes spin {
		0% {
			transform: rotate(0deg);
		}

		100% {
			transform: rotate(360deg);
		}
	}
</style>
