# frozen_string_literal: true

# Monkey-patch para compatibilidade entre gem dlocal_go (que usa http gem v5 API)
# e http gem v6 (que mudou a interface de .post(url, opts_hash) para .post(url, **opts)).
#
# A gem dlocal_go chama: HTTP.auth(...).send(:post, url, { json: body })
# Mas http v6 espera:   HTTP.auth(...).post(url, json: body)  (keyword args)
#
# Este patch corrige o call_api para usar keyword splat.

module DlocalGo
  module EndpointGeneratorPatch
    private

    def call_api(http_method, uri, params)
      parsed_uri, keys_to_remove = parse_uri(uri, params)
      url = endpoint_url(parsed_uri)
      needs_body = %i[post put patch].include?(http_method)

      if needs_body
        request_body = params.except(*keys_to_remove)
        HTTP.auth(auth_header).headers(json_content_type).send(http_method, url, json: request_body)
      else
        HTTP.auth(auth_header).headers(json_content_type).send(http_method, url)
      end
    end
  end

  Client.prepend(EndpointGeneratorPatch)
end
