InertiaRails.configure do |config|
  config.layout = "inertia"
  config.default_render = true
  config.version = ViteRuby.digest
  config.use_script_element_for_initial_page = true
end
