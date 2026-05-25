module JsonApiRenderable
  extend ActiveSupport::Concern

  private

  def serialize(serializer_class, record)
    serializer_class.new(record).serializable_hash[:data][:attributes]
  end

  def render_status_payload(status:, data: nil, http_status: :ok)
    body = { status: status }
    body[:data] = data unless data.nil?
    render json: body, status: http_status
  end
end
