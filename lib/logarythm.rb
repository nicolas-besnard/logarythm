require "logarythm/engine"

module Logarythm
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    attr_accessor :application_uuid
    attr_accessor :application_envs
    attr_accessor :application_socket_id
    attr_accessor :application_socket_key
    attr_accessor :application_socket_secret

    def initialize
      @application_uuid          = nil
      @application_envs          = nil
      @application_socket_id     = nil
      @application_socket_key    = nil
      @application_socket_secret = nil
    end
  end

  class Railtie < Rails::Railtie
    config.after_initialize do

      def deep_simplify_record(hsh)
        hsh.keep_if do |h, v|
          if v.is_a?(Hash)
            deep_simplify_record(v)
          else
            v.is_a? String
          end
        end
      end

      configuration = Logarythm.configuration
      if configuration.present?
        configuration_options = [
          :application_uuid,
          :application_envs,
          :application_socket_id,
          :application_socket_key,
          :application_socket_secret
        ].map { |option| configuration.send(option).present? }.exclude?(false)

        if configuration_options && configuration.application_envs.include?(Rails.env.to_sym)
          Pusher.app_id = configuration.application_socket_id
          Pusher.key    = configuration.application_socket_key
          Pusher.secret = configuration.application_socket_secret

          ActiveSupport::Notifications.subscribe /process_action.action_controller/ do |name, start, finish, id, payload|
            Pusher.trigger_async(configuration.application_uuid, 'process_action.action_controller', {
              content: {
                env: Rails.env,
                name: name,
                start: start,
                finish: finish,
                payload: (Base64.encode64(deep_simplify_record(payload).to_json) rescue nil)
              }
            })
          end

          ActiveSupport::Notifications.subscribe /sql.active_record/ do |name, start, finish, id, payload|
            Pusher.trigger_async(configuration.application_uuid, 'sql.active_record', {
              content: {
                env: Rails.env,
                name: name,
                start: start,
                finish: finish,
                payload: (Base64.encode64(deep_simplify_record(payload).to_json) rescue nil)
              }
            })
          end

          ActiveSupport::Notifications.subscribe /render_template.action_view/ do |name, start, finish, id, payload|
            Pusher.trigger_async(configuration.application_uuid, 'render_template.action_view', {
              content: {
                env: Rails.env,
                name: name,
                start: start,
                finish: finish,
                payload: (Base64.encode64(deep_simplify_record(payload).to_json) rescue nil)
              }
            })
          end
        end
      end
    end
  end
end
