import { computed } from "vue";
import { usePage } from "@inertiajs/vue3";

export function usePermissions() {
  const page = usePage();
  const can = computed(() => page.props.auth?.can || {});
  const role = computed(() => page.props.auth?.user?.role);

  return { can, role };
}
