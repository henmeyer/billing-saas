import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import ProgressBar from "@/components/Shared/ProgressBar.vue";

describe("ProgressBar", () => {
  const defaultProps = {
    label:   "Coins",
    used:    300,
    limit:   1000,
    balance: 700,
    percent: 30,
    unit:    "coin",
  };

  it("renderiza label e valores corretos", () => {
    const wrapper = mount(ProgressBar, { props: defaultProps });
    expect(wrapper.text()).toContain("Coins");
    expect(wrapper.text()).toContain("300");
    expect(wrapper.text()).toContain("1000");
    expect(wrapper.text()).toContain("30%");
  });

  it("barra verde quando uso < 80%", () => {
    const wrapper = mount(ProgressBar, { props: defaultProps });
    const bar = wrapper.find(".bg-brand-500");
    expect(bar.exists()).toBe(true);
  });

  it("barra amarela quando uso >= 80%", () => {
    const wrapper = mount(ProgressBar, {
      props: { ...defaultProps, percent: 85, used: 850, balance: 150 },
    });
    const bar = wrapper.find(".bg-yellow-500");
    expect(bar.exists()).toBe(true);
  });

  it("barra vermelha quando uso >= 100%", () => {
    const wrapper = mount(ProgressBar, {
      props: { ...defaultProps, percent: 100, used: 1000, balance: 0 },
    });
    const bar = wrapper.find(".bg-red-500");
    expect(bar.exists()).toBe(true);
  });

  it("não ultrapassa 100% na barra visual", () => {
    const wrapper = mount(ProgressBar, {
      props: { ...defaultProps, percent: 120, used: 1200, balance: 0 },
    });
    const bar = wrapper.find("[style]");
    expect(bar.attributes("style")).toContain("width: 100%");
  });
});
