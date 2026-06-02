import { createApp } from "vue";
import StatsCards from "../components/Dashboard/StatsCards.vue";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("dashboard-stats");
  if (el) {
    const stats = JSON.parse(el.dataset.stats);
    createApp(StatsCards, { stats }).mount(el);
  }
});
