<template>
  <button @click="handleClick" :class="btnClass">
    <slot />
  </button>
</template>

<script setup>
const props = defineProps({
  message: { type: String, default: "Tem certeza?" },
  btnClass: { type: String, default: "btn-danger btn-sm" },
});

const emit = defineEmits(["confirm"]);

const handleClick = () => {
  if (window.confirm(props.message)) emit("confirm");
};
</script>
