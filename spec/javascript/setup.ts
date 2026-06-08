import { vi } from "vitest";

vi.mock("@inertiajs/vue3", () => ({
  Link: { template: "<a><slot /></a>" },
  router: { post: vi.fn(), delete: vi.fn(), put: vi.fn() },
  usePage: () => ({
    props: {
      auth: {
        user: {
          id: 1,
          name: "Test User",
          email: "test@test.com",
          role: "admin",
        },
        account: { id: 1, name: "Test Account", slug: "test-account" },
        accounts: [],
      },
      flash: { notice: null, alert: null, token: null },
    },
    url: "/",
  }),
  useForm: (initial: Record<string, unknown>) => {
    const form = { ...initial, processing: false, errors: {} } as Record<string, unknown>;
    form.post = vi.fn();
    form.put = vi.fn();
    form.delete = vi.fn();
    form.transform = vi.fn().mockReturnValue(form);
    return form;
  },
}));
