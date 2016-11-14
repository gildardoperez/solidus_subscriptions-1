module SubscriptionStateMachine
  extend ActiveSupport::Concern
  included do
    class << self
      def active
        with_states %w(active renewing)
      end
    end

    state_machine initial: :active do
      event(:renew) { transition %i(active renewing) => :renewing }
      event(:renewed) { transition renewing: :active }

      after_transition any => :renewing, do: :mark_last_renewal!
      after_transition renewing: :active, do: :adjust_next_renewal!

      event(:cancel) { transition active: :cancelled }
      event(:pause) { transition active: :paused }
      event(:resume) { transition paused: :active }

      after_transition on: :cancel do |subscription|
        subscription.update_attributes(cancelled_at: Time.now)
      end

      after_transition on: :pause do |subscription|
        subscription.update_attributes(pause_at: Time.now, resume_at: nil)
      end

      after_transition on: :resume do |subscription, transition|
        resume_at = transition.args.first || Time.now
        subscription.update_attributes(resume_at: resume_at)
        subscription.update_attributes(pause_at: nil, state: 'active') if (resume_at.to_date <= Date.today)
      end
    end
  end
end
