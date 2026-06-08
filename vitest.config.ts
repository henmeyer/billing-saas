import { defineConfig } from "vitest/config";
import vue from "@vitejs/plugin-vue";
import path from "path";

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: { "@": path.resolve(__dirname, "app/javascript") },
  },
  test: {
    globals: true,
    environment: "jsdom",
    include: ["spec/javascript/**/*.spec.ts"],
    setupFiles: ["spec/javascript/setup.ts"],
  },
});
