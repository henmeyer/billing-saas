<template>
  <AppLayout>
    <div class="page-header">
      <div>
        <h2 class="page-title">Produtos</h2>
        <p class="text-sm text-gray-500 mt-0.5">Pacotes avulsos de créditos</p>
      </div>
      <Link href="/products/new" class="btn-primary">Novo produto</Link>
    </div>

    <div v-if="!products.length" class="card">
      <div class="card-body text-center py-12">
        <p class="text-gray-400 text-sm mb-4">Nenhum produto cadastrado ainda.</p>
        <Link href="/products/new" class="btn-primary inline-flex">Criar produto</Link>
      </div>
    </div>

    <div v-else class="card">
      <div class="table-wrapper">
        <table class="table">
          <thead>
            <tr>
              <th>Produto</th>
              <th>Tipo</th>
              <th>Créditos</th>
              <th>Preço</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in products" :key="p.id">
              <td>
                <p class="font-medium text-gray-900">{{ p.name }}</p>
                <p v-if="p.description" class="text-xs text-gray-400">{{ p.description }}</p>
              </td>
              <td>
                <Badge variant="blue">{{ p.product_type }}</Badge>
              </td>
              <td class="text-sm text-gray-700">
                <span v-if="p.credit_type">
                  {{ fmtNum(p.credit_quantity) }} {{ p.credit_type.unit }}s
                  <span class="text-gray-400">({{ p.credit_type.label }})</span>
                </span>
                <span v-else class="text-gray-400">—</span>
              </td>
              <td class="font-medium">{{ fmt(p.price) }}</td>
              <td>
                <Badge :variant="p.active ? 'green' : 'gray'">
                  {{ p.active ? "Ativo" : "Inativo" }}
                </Badge>
              </td>
              <td class="text-right flex gap-2 justify-end">
                <Link :href="`/products/${p.id}/edit`" class="btn-secondary btn-sm">
                  Editar
                </Link>
                <ConfirmButton
                  :message="`Desativar ${p.name}?`"
                  @confirm="deactivate(p.id)"
                >
                  Desativar
                </ConfirmButton>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link, router } from "@inertiajs/vue3";
import AppLayout from "@/components/Layout/AppLayout.vue";
import Badge from "@/components/Shared/Badge.vue";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

defineProps({ products: Array });

const deactivate = (id) => router.delete(`/products/${id}`);

const fmt = (v) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v || 0);
const fmtNum = (v) => new Intl.NumberFormat("pt-BR").format(v || 0);
</script>
