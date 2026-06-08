import { describe, it, expect } from "vitest";
import { nextTick } from "vue";
import { mount } from "@vue/test-utils";
import PlansForm from "@/pages/Plans/Form.vue";

const defaultProps = {
  plan: {
    id:             null,
    name:           "",
    price_cents:    0,
    billing_cycle:  "monthly",
    pricing_model:  "flat",
    licenses:       [],
    credits:        [],
    features:       [],
    integration_ids: [],
    prices:         [],
  },
  license_types: [
    { id: 1, key: "user_licenses", label: "Usuários", unit: "usuário" },
  ],
  credit_types: [{ id: 1, key: "coins", label: "Coins", unit: "coin" }],
  feature_types: [{ id: 1, key: "ai_enabled", label: "IA habilitada" }],
  currencies: [
    { id: 1, code: "BRL", name: "Real", symbol: "R$", default: true },
  ],
  integrations: [],
  errors:       {},
};

describe("Plans/Form", () => {
  it("renderiza campos básicos", () => {
    const wrapper = mount(PlansForm, {
      props: defaultProps,
      global: { stubs: { AppLayout: { template: "<div><slot /></div>" } } },
    });
    expect(wrapper.find('input[type="text"]').exists()).toBe(true);
  });

  it("exibe seção de features", () => {
    const wrapper = mount(PlansForm, {
      props: defaultProps,
      global: { stubs: { AppLayout: { template: "<div><slot /></div>" } } },
    });
    expect(wrapper.text()).toContain("IA habilitada");
  });

  it("exibe modelos de precificação", () => {
    const wrapper = mount(PlansForm, {
      props: defaultProps,
      global: { stubs: { AppLayout: { template: "<div><slot /></div>" } } },
    });
    expect(wrapper.text()).toContain("Fixo");
    expect(wrapper.text()).toContain("Por unidade");
    expect(wrapper.text()).toContain("Volume");
  });

  it("mostra campos de per_unit ao selecionar esse modelo", () => {
    const wrapper = mount(PlansForm, {
      props: {
        ...defaultProps,
        plan: { ...defaultProps.plan, pricing_model: "per_unit" },
      },
      global: { stubs: { AppLayout: { template: "<div><slot /></div>" } } },
    });
    expect(wrapper.text()).toContain("Métrica de cobrança");
  });
});
