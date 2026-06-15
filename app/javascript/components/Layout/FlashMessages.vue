<template>
  <div
    v-if="visible && (flash.notice || flash.alert || flash.token)"
    class="px-6 pt-4 space-y-2"
  >
    <div
      v-if="flash.notice"
      class="bg-green-50 border border-green-200 text-green-700 text-sm px-4 py-2.5 rounded-lg flex items-center gap-2"
    >
      <span class="text-green-500 flex-shrink-0">✓</span>
      <span class="flex-1">{{ flash.notice }}</span>
      <button
        @click="visible = false"
        class="text-green-400 hover:text-green-600 text-lg leading-none"
      >
        ×
      </button>
    </div>
    <div
      v-if="flash.alert"
      class="bg-red-50 border border-red-200 text-red-700 text-sm px-4 py-2.5 rounded-lg flex items-center gap-2"
    >
      <span class="text-red-500 flex-shrink-0">✕</span>
      <span class="flex-1">{{ flash.alert }}</span>
      <button
        @click="visible = false"
        class="text-red-400 hover:text-red-600 text-lg leading-none"
      >
        ×
      </button>
    </div>
    <!-- Token de API key — mostrado uma única vez -->
    <div
      v-if="flash.token"
      class="bg-green-50 border border-green-200 text-green-700 text-sm px-4 py-2.5 rounded-lg"
    >
      <div class="flex-1">
        <p class="font-medium mb-1">
          Chave criada! Copie agora — não será exibida novamente.
        </p>
        <code
          class="bg-green-100 text-green-900 px-3 py-1.5 rounded text-sm font-mono break-all block mt-1"
        >
          {{ flash.token }}
        </code>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from "vue";

const props = defineProps({ flash: Object });

const visible = ref(true);

watch(
  () => props.flash,
  () => {
    visible.value = true;
    if (props.flash?.notice && !props.flash?.token) {
      setTimeout(() => {
        visible.value = false;
      }, 5000);
    }
  },
  { deep: true },
);
</script>
