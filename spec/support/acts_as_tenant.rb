RSpec.configure do |config|
  config.around do |example|
    if example.metadata[:with_tenant]
      ActsAsTenant.with_tenant(example.metadata[:with_tenant]) do
        example.run
      end
    else
      example.run
    end
  end
end
