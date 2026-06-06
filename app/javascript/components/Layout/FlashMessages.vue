<template>
  <div v-if="flash.notice || flash.alert || flash.token" class="px-6 pt-4 space-y-2">
    <div v-if="flash.notice" class="alert-success">
      <span>✓</span> {{ flash.notice }}
    </div>
    <div v-if="flash.alert" class="alert-danger">
      <span>✕</span> {{ flash.alert }}
    </div>
    <!-- Token de API key — mostrado uma única vez -->
    <div v-if="flash.token" class="alert-success">
      <div class="flex-1">
        <p class="font-medium mb-1">Chave criada! Copie agora — não será exibida novamente.</p>
        <code class="bg-green-100 text-green-900 px-3 py-1.5 rounded text-sm font-mono break-all block mt-1">
          {{ flash.token }}
        </code>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({ flash: Object });
</script>
