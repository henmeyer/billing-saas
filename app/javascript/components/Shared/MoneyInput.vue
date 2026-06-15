<template>
  <div class="relative">
    <input
      ref="inputRef"
      type="text"
      class="form-input"
      :class="inputClass"
      :placeholder="placeholder"
    />
  </div>
</template>

<script setup>
import { watch } from "vue";
import { useCurrencyInput } from "vue-currency-input";

const props = defineProps({
  modelValue: { type: Number, default: 0 },
  currency: { type: String, default: "BRL" },
  locale: { type: String, default: "pt-BR" },
  placeholder: { type: String, default: "0,00" },
  inputClass: { type: String, default: "" },
});

const emit = defineEmits(["update:modelValue"]);

// valueScaling: "precision" keeps numberValue in cents (1000 ↔ R$ 10,00)
const { inputRef, numberValue } = useCurrencyInput({
  currency: props.currency,
  locale: props.locale,
  currencyDisplay: "symbol",
  precision: 2,
  valueScaling: "precision",
  hideCurrencySymbolOnFocus: false,
  hideGroupingSeparatorOnFocus: false,
  hideNegligibleDecimalDigitsOnFocus: false,
  valueRange: { min: 0 },
});

watch(numberValue, (val) => {
  if (val !== props.modelValue) {
    emit("update:modelValue", val ?? 0);
  }
});

watch(
  () => props.modelValue,
  (cents) => {
    if (cents !== numberValue.value) {
      numberValue.value = cents ?? 0;
    }
  },
  { immediate: true },
);
</script>
