<template>
  <header class="h-14 bg-white border-b border-gray-200 flex items-center px-6 flex-shrink-0">
    <div class="flex-1">
      <h1 class="text-sm font-medium text-gray-900">
        {{ $page.props.pageTitle || "" }}
      </h1>
    </div>
    <div class="flex items-center gap-3 text-xs text-gray-500">
      <span class="badge-gray">{{ auth?.account?.name }}</span>
    </div>
  </header>
</template>

<script setup>
defineProps({ auth: Object });
</script>
