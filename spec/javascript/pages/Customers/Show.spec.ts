import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import CustomersShow from "@/pages/Customers/Show.vue";

const baseCustomer = {
  id: 1,
  name: "Empresa ABC",
  email: "abc@test.com",
  status: "active",
  health_score: 85,
};

const makeSub = (overrides = {}) => ({
  id: 1,
  status: "active",
  gateway: "stripe",
  integration_name: "Integração A",
  plan_name: "Plano Pro",
  base_price_cents: 9900,
  period_amount_cents: 9900,
  period_base_cents: 9900,
  period_extras_cents: 0,
  has_extras: false,
  currency_code: "BRL",
  current_period_end: "15/07/2025",
  started_at: "15/06/2025",
  current_extra_packages: {},
  ...overrides,
});

const defaultProps = {
  customer: baseCustomer,
  subscriptions: [],
  subscription: null,
  charges: [],
  snapshots: [],
  available_products: [],
  period_credits: [],
  period_licenses: [],
};

const globalStubs = {
  stubs: {
    AppLayout: { template: "<div><slot /></div>" },
    ProgressBar: { template: "<div />" },
    ConfirmButton: { template: "<button><slot /></button>" },
  },
};

describe("Customers/Show", () => {
  it("renders empty state when no active subscriptions", () => {
    const wrapper = mount(CustomersShow, {
      props: { ...defaultProps, subscriptions: [] },
      global: globalStubs,
    });
    expect(wrapper.text()).toContain("Sem assinatura ativa");
    expect(wrapper.text()).toContain("Criar assinatura");
  });

  it("renders subscription cards for each active subscription", () => {
    const subscriptions = [
      makeSub({
        id: 1,
        integration_name: "Integração A",
        plan_name: "Plano Pro",
      }),
      makeSub({
        id: 2,
        integration_name: "Integração B",
        plan_name: "Plano Basic",
      }),
    ];
    const wrapper = mount(CustomersShow, {
      props: { ...defaultProps, subscriptions, subscription: subscriptions[0] },
      global: globalStubs,
    });

    expect(wrapper.text()).toContain("Integração A");
    expect(wrapper.text()).toContain("Integração B");
    expect(wrapper.text()).toContain("Plano Pro");
    expect(wrapper.text()).toContain("Plano Basic");
    expect(wrapper.text()).not.toContain("Sem assinatura ativa");
  });

  it("displays status badge for each subscription", () => {
    const subscriptions = [
      makeSub({ id: 1, status: "active" }),
      makeSub({ id: 2, status: "past_due" }),
    ];
    const wrapper = mount(CustomersShow, {
      props: { ...defaultProps, subscriptions, subscription: subscriptions[0] },
      global: globalStubs,
    });

    expect(wrapper.text()).toContain("Ativo");
    expect(wrapper.text()).toContain("Inadimplente");
  });

  it("shows value decomposition with extras when has_extras is true", () => {
    const subscriptions = [
      makeSub({
        id: 1,
        has_extras: true,
        period_base_cents: 9900,
        period_extras_cents: 5000,
        period_amount_cents: 14900,
      }),
    ];
    const wrapper = mount(CustomersShow, {
      props: { ...defaultProps, subscriptions, subscription: subscriptions[0] },
      global: globalStubs,
    });

    expect(wrapper.text()).toContain("Valor base");
    expect(wrapper.text()).toContain("Extras contratados");
    expect(wrapper.text()).toContain("Total mensal");
  });

  it("hides extras line when subscription has no extras", () => {
    const subscriptions = [
      makeSub({
        id: 1,
        has_extras: false,
        period_base_cents: 9900,
        period_extras_cents: 0,
        period_amount_cents: 9900,
      }),
    ];
    const wrapper = mount(CustomersShow, {
      props: { ...defaultProps, subscriptions, subscription: subscriptions[0] },
      global: globalStubs,
    });

    expect(wrapper.text()).toContain("Valor base");
    expect(wrapper.text()).not.toContain("Extras contratados");
    expect(wrapper.text()).toContain("Total mensal");
  });

  it("renders Editar button linking to subscription edit page", () => {
    const subscriptions = [makeSub({ id: 42 })];
    const wrapper = mount(CustomersShow, {
      props: { ...defaultProps, subscriptions, subscription: subscriptions[0] },
      global: globalStubs,
    });

    const subEditLink = wrapper
      .findAll("a")
      .find(
        (a) => a.attributes("href") === "/customers/1/subscriptions/42/edit",
      );
    expect(subEditLink).toBeTruthy();
    expect(subEditLink!.text()).toContain("Editar");
  });

  it("renders create subscription link in empty state", () => {
    const wrapper = mount(CustomersShow, {
      props: { ...defaultProps, subscriptions: [] },
      global: globalStubs,
    });

    const createLink = wrapper
      .findAll("a")
      .find((a) => a.text().includes("Criar assinatura"));
    expect(createLink).toBeTruthy();
    expect(createLink!.attributes("href")).toBe(
      "/customers/1/subscriptions/new",
    );
  });
});
