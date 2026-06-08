<template>
  <SuperadminLayout>
    <div class="page-header">
      <div class="flex items-center gap-3">
        <Link
          :href="`/superadmin/accounts/${account.id}`"
          class="text-sm text-gray-500 hover:text-gray-700"
        >
          ← {{ account.name }}
        </Link>
        <h2 class="page-title">Editar conta</h2>
      </div>
    </div>

    <div class="max-w-md">
      <div class="card">
        <div class="card-body space-y-4">
          <div v-if="Object.keys(errors).length" class="alert-danger">
            <p v-for="(msgs, field) in errors" :key="field">{{ msgs.join(", ") }}</p>
          </div>

          <div>
            <label class="form-label">Nome</label>
            <input v-model="form.name" type="text" class="form-input" />
          </div>

          <div>
            <label class="form-label">Slug</label>
            <input :value="account.slug" type="text" class="form-input bg-gray-50" readonly />
            <p class="form-hint">O slug não pode ser alterado.</p>
          </div>
        </div>
      </div>

      <div class="flex gap-3 justify-end mt-6">
        <Link :href="`/superadmin/accounts/${account.id}`" class="btn-secondary">
          Cancelar
        </Link>
        <button @click="submit" :disabled="form.processing" class="btn-primary">
          {{ form.processing ? "Salvando..." : "Salvar" }}
        </button>
      </div>
    </div>
  </SuperadminLayout>
</template>

<script setup>
import { Link, useForm } from "@inertiajs/vue3";
import SuperadminLayout from "@/components/Layout/SuperadminLayout.vue";

const props = defineProps({
  account: Object,
  errors:  { type: Object, default: () => ({}) },
});

const form = useForm({ name: props.account.name });

const submit = () => form.put(`/superadmin/accounts/${props.account.id}`);
</script>
