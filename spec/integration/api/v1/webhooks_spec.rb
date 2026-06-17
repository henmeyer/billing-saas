require "swagger_helper"

# Spec puramente documentacional — não existem rotas reais para estes endpoints.
# Os webhooks são ENVIADOS pelo sistema para URLs externas configuradas nas integrações.
# Este arquivo gera a documentação Swagger dos payloads de webhook de saída.
RSpec.describe "Webhooks de saída", type: :request, document_only: true do
  let(:Authorization) { nil }

  path "/webhooks/callbacks" do
    get "Documentação dos webhooks de saída" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        ## Visão geral

        Webhooks são disparados automaticamente quando eventos ocorrem no sistema.
        Configure a URL de destino em **Configurações → Integrações**.

        ## Autenticação

        Cada webhook inclui o header:
        ```
        X-Billing-Signature: sha256=<assinatura>
        ```

        A assinatura é calculada como `HMAC-SHA256(secret, body)`.
        O `secret` é gerado automaticamente na criação da integração
        e exibido na página de configuração.

        ## Validação da assinatura

        **Ruby:**
        ```ruby
        expected = "sha256=" + OpenSSL::HMAC.hexdigest(
          "SHA256", SECRET, request.body.read
        )
        valid = ActiveSupport::SecurityUtils.secure_compare(
          expected, request.headers["X-Billing-Signature"]
        )
        ```

        **Node.js:**
        ```js
        const sig = crypto
          .createHmac('sha256', SECRET)
          .update(rawBody)
          .digest('hex')
        const valid = `sha256=${sig}` === req.headers['x-billing-signature']
        ```

        **Python:**
        ```python
        import hmac, hashlib
        sig = hmac.new(
          SECRET.encode(), raw_body, hashlib.sha256
        ).hexdigest()
        valid = f"sha256={sig}" == request.headers.get("X-Billing-Signature")
        ```

        ## Retry

        Em caso de falha (timeout ou resposta não-2xx), o sistema
        tenta novamente com backoff exponencial:
        1min → 5min → 30min → 2h → 8h (5 tentativas no total).

        **Responda com HTTP 200 imediatamente** e processe em background.

        ## Identificar testes

        Webhooks disparados pelo botão de teste incluem `"test": true` no payload.
        Você pode usar isso para ignorar em produção se necessário.

        ## Catálogo de eventos

        Selecione os eventos desejados ao configurar cada integração.
        Abaixo estão todos os eventos disponíveis com seus payloads.
      DESC

      response "200", "Documentação de referência" do
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/subscription.activated" do
    post "subscription.activated — Assinatura ativada" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado quando uma nova assinatura é criada e ativada.

        **Quando usar:** liberar acesso ao sistema, criar o tenant do cliente,
        configurar as licenças e créditos iniciais.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookSubscriptionActivated"
        examples "application/json" => {
          event:      "subscription.activated",
          uuid:       "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
          timestamp:  "2026-06-01T14:30:00Z",
          account_id: "1",
          test:       false,
          customer:   {
            id:          "42",
            external_id: "EXT123",
            name:        "Empresa X",
            email:       "admin@empresax.com"
          },
          features:   {
            ai_enabled:     true,
            export_reports: false
          },
          data:       {
            plan: { id: 1, name: "Pro" }
          }
        }
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/subscription.cancelled" do
    post "subscription.cancelled — Assinatura cancelada" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado quando uma assinatura é cancelada.

        **Quando usar:** revogar acesso, arquivar dados do cliente,
        disparar fluxo de win-back.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookSubscriptionCancelled"
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/subscription.past_due" do
    post "subscription.past_due — Pagamento em atraso" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado quando um pagamento fica em atraso.

        **Quando usar:** notificar o cliente, restringir acesso a features
        premium, iniciar fluxo de cobrança.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookSubscriptionPastDue"
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/subscription.renewed" do
    post "subscription.renewed — Assinatura renovada" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado quando uma assinatura é renovada com sucesso.

        **Quando usar:** resetar contadores de uso, renovar limites
        de créditos, registrar o novo período.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookSubscriptionRenewed"
        examples "application/json" => {
          event:      "subscription.renewed",
          uuid:       "b2c3d4e5-f6a7-8901-bcde-f12345678901",
          timestamp:  "2026-06-01T00:00:00Z",
          account_id: "1",
          test:       false,
          customer:   {
            id: "42", external_id: "EXT123",
            name: "Empresa X", email: "admin@empresax.com"
          },
          features:   { ai_enabled: true },
          data:       { period_end: "2026-07-01T00:00:00Z" }
        }
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/subscription.trial_ending" do
    post "subscription.trial_ending — Trial encerrando" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado 3 dias antes do trial expirar.

        **Quando usar:** enviar email de aviso, oferecer desconto
        de conversão, solicitar dados de pagamento.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookSubscriptionTrialEnding"
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/plan.changed" do
    post "plan.changed — Plano alterado" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado quando o cliente muda de plano (upgrade ou downgrade).

        **Quando usar:** atualizar limites de licenças e créditos,
        habilitar ou desabilitar features, notificar o time de CS.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookPlanChanged"
        examples "application/json" => {
          event:      "plan.changed",
          uuid:       "c3d4e5f6-a7b8-9012-cdef-123456789012",
          timestamp:  "2026-06-01T14:30:00Z",
          account_id: "1",
          test:       false,
          customer:   {
            id: "42", external_id: "EXT123",
            name: "Empresa X", email: "admin@empresax.com"
          },
          features:   {
            ai_enabled:     true,
            export_reports: true
          },
          data:       {
            previous_plan: { id: 1, name: "Starter" },
            new_plan:      { id: 2, name: "Pro" }
          }
        }
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/payment.received" do
    post "payment.received — Pagamento confirmado" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado quando um pagamento é confirmado pelo gateway.

        **Quando usar:** registrar receita, liberar acesso após
        período de inadimplência, emitir nota fiscal.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookPaymentReceived"
        examples "application/json" => {
          event:      "payment.received",
          uuid:       "d4e5f6a7-b8c9-0123-defa-234567890123",
          timestamp:  "2026-06-01T14:30:00Z",
          account_id: "1",
          test:       false,
          customer:   {
            id: "42", external_id: "EXT123",
            name: "Empresa X", email: "admin@empresax.com"
          },
          features:   { ai_enabled: true },
          data:       {
            amount_cents: 19_700,
            gateway:      "asaas",
            charge_id:    "pay_abc123"
          }
        }
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/payment.failed" do
    post "payment.failed — Pagamento falhou" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado quando uma tentativa de cobrança falha.

        **Quando usar:** notificar o cliente, iniciar régua de
        cobrança, restringir acesso após N tentativas.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookPaymentFailed"
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/credits.threshold_reached" do
    post "credits.threshold_reached — Threshold de créditos atingido" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado quando o uso de créditos atinge 80% ou 95% do limite.

        Disparado **uma vez por threshold por período de cobrança**.

        **Quando usar:** notificar o cliente, oferecer recarga,
        mostrar aviso no sistema.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookCreditsThresholdReached"
        examples "application/json" => {
          event:      "credits.threshold_reached",
          uuid:       "e5f6a7b8-c9d0-1234-efab-345678901234",
          timestamp:  "2026-06-15T10:00:00Z",
          account_id: "1",
          test:       false,
          customer:   {
            id: "42", external_id: "EXT123",
            name: "Empresa X", email: "admin@empresax.com"
          },
          features:   { ai_enabled: true },
          data:       {
            credit_type:   "coins",
            used:          800,
            limit:         1000,
            usage_percent: 80.0,
            threshold:     80
          }
        }
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/credits.depleted" do
    post "credits.depleted — Créditos esgotados" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado quando os créditos chegam a zero.

        **Quando usar:** bloquear uso de features que consomem créditos,
        notificar o cliente urgentemente, oferecer recarga imediata.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookCreditsDepleted"
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/credits.recharged" do
    post "credits.recharged — Créditos recarregados" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado quando créditos são adicionados manualmente
        (compra de pacote avulso) ou na renovação do plano.

        **Quando usar:** liberar bloqueio de features, notificar
        o cliente da recarga, atualizar saldo no sistema.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookCreditsRecharged"
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end

  path "/webhooks/events/license.updated" do
    post "license.updated — Licença atualizada" do
      tags        "Webhooks"
      produces    "application/json"
      description <<~DESC
        Disparado quando a quantidade de licenças de um tipo é alterada
        (upgrade/downgrade de plano ou ajuste manual).

        **Quando usar:** atualizar limites no sistema integrado,
        bloquear criação de novos usuários se reduzido, notificar admin.
      DESC

      response "200", "Payload do evento" do
        schema "$ref" => "#/components/schemas/WebhookLicenseUpdated"
        examples "application/json" => {
          event:      "license.updated",
          uuid:       "f6a7b8c9-d0e1-2345-fabc-456789012345",
          timestamp:  "2026-06-01T14:30:00Z",
          account_id: "1",
          test:       false,
          customer:   {
            id: "42", external_id: "EXT123",
            name: "Empresa X", email: "admin@empresax.com"
          },
          features:   { ai_enabled: true },
          data:       {
            license_type:      "user_licenses",
            previous_quantity: 10,
            new_quantity:      20
          }
        }
        it "documentação apenas" do |_example|
          expect(true).to be true
        end
      end
    end
  end
end
