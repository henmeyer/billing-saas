import "./application.css";
import { createApp } from "vue";

import StatsCards from "../components/Dashboard/StatsCards.vue";
import MrrChart from "../components/Dashboard/MrrChart.vue";
import CreditUsage from "../components/Dashboard/CreditUsage.vue";
import PlanLicenses from "../components/Plans/PlanLicenses.vue";
import PlanCredits from "../components/Plans/PlanCredits.vue";

const components = {
  "stats-cards": StatsCards,
  "mrr-chart": MrrChart,
  "credit-usage": CreditUsage,
  "plan-licenses": PlanLicenses,
  "plan-credits": PlanCredits,
};

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-vue]").forEach((el) => {
    const name = el.dataset.vue;
    const component = components[name];
    if (!component) return;

    const props = el.dataset.props ? JSON.parse(el.dataset.props) : {};
    createApp(component, props).mount(el);
  });
});
