# frozen_string_literal: true

class ResourceStateEvent < ResourceEvent
  include MergeRequestResourceEvent
  include Importable

  validate :exactly_one_issuable, unless: :importing?

  belongs_to :source_merge_request, class_name: 'MergeRequest', foreign_key: :source_merge_request_id

  # state is used for issue and merge request states.
  enum state: Issue.available_states.merge(MergeRequest.available_states).merge(reopened: 5)

  after_create :issue_usage_metrics

  scope :aliased_for_timebox_report, -> do
    select("'state' AS event_type", "id", "created_at", "state AS value", "NULL AS action", "issue_id")
  end

  def self.issuable_attrs
    %i(issue merge_request).freeze
  end

  def issuable
    issue || merge_request
  end

  def for_issue?
    issue_id.present?
  end

  def synthetic_note_class
    StateNote
  end

  private

  def issue_usage_metrics
    return unless for_issue?

    case state
    when 'closed'
      issue_usage_counter.track_issue_closed_action(author: user, project: issue.project)
    when 'reopened'
      issue_usage_counter.track_issue_reopened_action(author: user, project: issue.project)
    else
      # no-op, nothing to do, not a state we're tracking
    end
  end

  def issue_usage_counter
    Gitlab::UsageDataCounters::IssueActivityUniqueCounter
  end
end

ResourceStateEvent.prepend_mod_with('ResourceStateEvent')
