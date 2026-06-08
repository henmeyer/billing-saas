import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import Dashboard from "@/pages/Dashboard/Index.vue";

const defaultStats = {
  mrr:                 19700,
  arr:                 236400,
  active_customers:    42,
  revenue_this_month:  58000,
  churned_this_month:  2,
  past_due:            0,
  at_risk:             0,
  credits_depleted:    0,
  mrr_by_plan:         { Pro: 9700, Business: 10000 },
  recent_charges:      [],
};

describe("Dashboard/Index", () => {
  it("exibe as métricas principais", () => {
    const wrapper = mount(Dashboard, {
      props: { stats: defaultStats },
      global: { stubs: { AppLayout: { template: "<div><slot /></div>" } } },
    });
    expect(wrapper.text()).toContain("42");
  });

  it("não exibe alertas quando não há problemas", () => {
    const wrapper = mount(Dashboard, {
      props: { stats: defaultStats },
      global: { stubs: { AppLayout: { template: "<div><slot /></div>" } } },
    });
    expect(wrapper.find(".alert-warning").exists()).toBe(false);
    expect(wrapper.find(".alert-danger").exists()).toBe(false);
  });

  it("exibe alerta de inadimplência quando past_due > 0", () => {
    const wrapper = mount(Dashboard, {
      props: { stats: { ...defaultStats, past_due: 3 } },
      global: { stubs: { AppLayout: { template: "<div><slot /></div>" } } },
    });
    expect(wrapper.find(".alert-warning").exists()).toBe(true);
    expect(wrapper.text()).toContain("3 assinatura(s)");
  });

  it("exibe alerta de créditos esgotados", () => {
    const wrapper = mount(Dashboard, {
      props: { stats: { ...defaultStats, credits_depleted: 5 } },
      global: { stubs: { AppLayout: { template: "<div><slot /></div>" } } },
    });
    expect(wrapper.find(".alert-danger").exists()).toBe(true);
    expect(wrapper.text()).toContain("5 cliente(s)");
  });
});
