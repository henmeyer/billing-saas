import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";
import vue from "@vitejs/plugin-vue";
import path from "path";

export default defineConfig({
  plugins: [RubyPlugin(), vue()],
  resolve: { alias: { "@": path.resolve(__dirname, "app/javascript") } },
  server: {
    hmr: {
      // O browser acessa via localhost, não pelo hostname do container
      host: "localhost",
      port: 3038,
      protocol: "ws",
    },
    watch: {
      // Polling necessário para detectar mudanças em volumes Docker
      usePolling: true,
      interval: 500,
    },
  },
  test: {
    globals: true,
    environment: "jsdom",
    root: ".",
    include: ["spec/javascript/**/*.spec.ts"],
    setupFiles: ["spec/javascript/setup.ts"],
  },
});
