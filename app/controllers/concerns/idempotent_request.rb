require "digest"

module IdempotentRequest
  extend ActiveSupport::Concern

  IDEMPOTENCY_HEADER = "Idempotency-Key"
  INTERNAL_PARAMS = %w[controller action format].freeze

  private

  def with_idempotency
    key = request.headers[IDEMPOTENCY_HEADER].to_s.strip
    return yield if key.blank?

    fingerprint = idempotency_fingerprint
    record = find_or_create_idempotency_key(key, fingerprint)

    record.with_lock do
      return render_idempotency_conflict if record.request_fingerprint != fingerprint
      return render json: record.response_body, status: record.response_status if record.completed?

      yield
      record.update!(
        response_status: response.status,
        response_body: JSON.parse(response.body)
      )
    end
  end

  def find_or_create_idempotency_key(key, fingerprint)
    IdempotencyKey.create_or_find_by!(user: current_user, key: key) do |record|
      record.request_method = request.request_method
      record.request_path = request.path
      record.request_fingerprint = fingerprint
    end
  end

  def idempotency_fingerprint
    payload = {
      method: request.request_method,
      path: request.path,
      params: deep_sort_hash(idempotency_params)
    }

    Digest::SHA256.hexdigest(JSON.generate(payload))
  end

  def idempotency_params
    params.to_unsafe_h.except(*INTERNAL_PARAMS)
  end

  def deep_sort_hash(value)
    case value
    when Hash
      value.keys.sort.to_h { |key| [key, deep_sort_hash(value[key])] }
    when Array
      value.map { |item| deep_sort_hash(item) }
    else
      value
    end
  end

  def render_idempotency_conflict
    render json: {
      status: {
        code: 409,
        message: "Idempotency-Key has already been used with a different request."
      }
    }, status: :conflict
  end
end
