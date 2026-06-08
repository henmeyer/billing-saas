import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import ConfirmButton from "@/components/Shared/ConfirmButton.vue";

describe("ConfirmButton", () => {
  it("emite confirm quando usuário confirma", async () => {
    vi.stubGlobal("confirm", () => true);
    const wrapper = mount(ConfirmButton, {
      props: { message: "Tem certeza?" },
      slots: { default: "Deletar" },
    });
    await wrapper.find("button").trigger("click");
    expect(wrapper.emitted("confirm")).toBeTruthy();
  });

  it("não emite confirm quando usuário cancela", async () => {
    vi.stubGlobal("confirm", () => false);
    const wrapper = mount(ConfirmButton, {
      props: { message: "Tem certeza?" },
      slots: { default: "Deletar" },
    });
    await wrapper.find("button").trigger("click");
    expect(wrapper.emitted("confirm")).toBeFalsy();
  });

  it("exibe o texto do slot", () => {
    const wrapper = mount(ConfirmButton, {
      props: { message: "X" },
      slots: { default: "Remover item" },
    });
    expect(wrapper.text()).toBe("Remover item");
  });
});
