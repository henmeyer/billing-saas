import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import Badge from "@/components/Shared/Badge.vue";

describe("Badge", () => {
  it("renderiza o slot corretamente", () => {
    const wrapper = mount(Badge, { slots: { default: "Ativo" } });
    expect(wrapper.text()).toBe("Ativo");
  });

  it("aplica classe correta para variante green", () => {
    const wrapper = mount(Badge, {
      props: { variant: "green" },
      slots: { default: "Ativo" },
    });
    expect(wrapper.classes()).toContain("badge-green");
  });

  it("aplica badge-gray como padrão", () => {
    const wrapper = mount(Badge, { slots: { default: "X" } });
    expect(wrapper.classes()).toContain("badge-gray");
  });

  it.each([
    ["green",  "badge-green"],
    ["red",    "badge-red"],
    ["yellow", "badge-yellow"],
    ["blue",   "badge-blue"],
    ["gray",   "badge-gray"],
  ])("variante %s → classe %s", (variant, cls) => {
    const wrapper = mount(Badge, {
      props: { variant },
      slots: { default: "X" },
    });
    expect(wrapper.classes()).toContain(cls);
  });
});
