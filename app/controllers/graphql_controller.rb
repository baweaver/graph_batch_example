# frozen_string_literal: true

class GraphqlController < ApplicationController
  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  # protect_from_forgery with: :null_session

  around_action :log_sql_queries
  around_action :track_active_record_instantiations
  around_action :track_gc_and_memory_usage

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]

    context = {
      # Query context goes here, for example:
      # current_user: current_user,
    }

    result = GraphBatchSchema.execute(
      query,
      variables: variables,
      context: context,
      operation_name: operation_name
    )

    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  def log_sql_queries
    count = 0
    callback = ->(_name, _start, _finish, _id, payload) do
      count += 1 if payload[:sql] =~ /\A\s*SELECT/i
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end

    Rails.logger.info("[GraphQL] GraphQL query made #{count} SELECT queries")
  end

  def track_active_record_instantiations
    count = 0

    callback = ->(_name, _started, _finished, _unique_id, payload) {
      count += payload[:record_count] || 0
    }

    ActiveSupport::Notifications.subscribed(callback, "instantiation.active_record") do
      yield
    end

    Rails.logger.info("[GraphQL] Instantiated #{count} ActiveRecord objects")
  end

  def track_gc_and_memory_usage
    gc_start = GC.stat

    yield

    gc_end = GC.stat

    gc_diff = {
      count: gc_end[:count] - gc_start[:count],
      major_gc: gc_end[:major_gc_count] - gc_start[:major_gc_count],
      time: gc_end[:time] - gc_start[:time]
    }

    Rails.logger.info("[GraphQL] GC: #{gc_diff}")
  end

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [ { message: e.message, backtrace: e.backtrace } ], data: {} }, status: 500
  end
end
