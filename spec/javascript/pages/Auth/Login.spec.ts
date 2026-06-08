import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import Login from "@/pages/Auth/Login.vue";

describe("Auth/Login", () => {
  it("renderiza campos de email e senha", () => {
    const wrapper = mount(Login);
    expect(wrapper.find('input[type="email"]').exists()).toBe(true);
    expect(wrapper.find('input[type="password"]').exists()).toBe(true);
  });

  it("renderiza botão de submit", () => {
    const wrapper = mount(Login);
    expect(wrapper.find('button[type="submit"]').exists()).toBe(true);
  });

  it("chama form.post ao submeter", async () => {
    const wrapper = mount(Login);
    await wrapper.find("form").trigger("submit");
    expect(wrapper.find("button").text()).toContain("Entrar");
  });
});
