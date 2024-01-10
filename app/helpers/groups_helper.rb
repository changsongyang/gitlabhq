# frozen_string_literal: true

module GroupsHelper
  def can_change_group_visibility_level?(group)
    can?(current_user, :change_visibility_level, group)
  end

  def can_update_default_branch_protection?(group)
    can?(current_user, :update_default_branch_protection, group)
  end

  def can_change_share_with_group_lock?(group)
    can?(current_user, :change_share_with_group_lock, group)
  end

  def can_change_prevent_sharing_groups_outside_hierarchy?(group)
    can?(current_user, :change_prevent_sharing_groups_outside_hierarchy, group)
  end

  def can_disable_group_emails?(group)
    can?(current_user, :set_emails_disabled, group) && !group.parent&.emails_disabled?
  end

  def can_admin_group_member?(group)
    Ability.allowed?(current_user, :admin_group_member, group)
  end

  def can_admin_service_accounts?(group)
    false
  end

  def group_icon_url(group, options = {})
    if group.is_a?(String)
      group = Group.find_by_full_path(group)
    end

    group.try(:avatar_url) || ActionController::Base.helpers.image_path('no_group_avatar.png')
  end

  def group_title(group)
    @has_group_title = true
    full_title = []

    sorted_ancestors(group).with_route.reverse_each.with_index do |parent, index|
      if index > 0
        add_to_breadcrumb_collapsed_links(group_title_link(parent), location: :before)
      else
        full_title << breadcrumb_list_item(group_title_link(parent, hidable: false))
      end

      push_to_schema_breadcrumb(simple_sanitize(parent.name), group_path(parent))
    end

    full_title << render("layouts/nav/breadcrumbs/collapsed_inline_list", location: :before, title: _("Show all breadcrumbs"))

    full_title << breadcrumb_list_item(group_title_link(group))
    push_to_schema_breadcrumb(simple_sanitize(group.name), group_path(group))

    full_title.join.html_safe
  end

  def projects_lfs_status(group)
    lfs_status =
      if group.lfs_enabled?
        group.projects.count(&:lfs_enabled?)
      else
        group.projects.count { |project| !project.lfs_enabled? }
      end

    size = group.projects.size

    if lfs_status == size
      'for all projects'
    else
      "for #{lfs_status} out of #{pluralize(size, 'project')}"
    end
  end

  def group_lfs_status(group)
    status = group.lfs_enabled? ? 'enabled' : 'disabled'

    content_tag(:span, class: "lfs-#{status}") do
      "#{status.humanize} #{projects_lfs_status(group)}"
    end
  end

  # Overridden in EE
  def remove_group_message(group)
    _("You are going to remove %{group_name}. This will also delete all of its subgroups and projects. Removed groups CANNOT be restored! Are you ABSOLUTELY sure?") %
      { group_name: group.name }
  end

  def share_with_group_lock_help_text(group)
    return default_help unless group.parent&.share_with_group_lock?

    if group.share_with_group_lock?
      if can?(current_user, :change_share_with_group_lock, group.parent)
        ancestor_locked_but_you_can_override(group)
      else
        ancestor_locked_so_ask_the_owner(group)
      end
    else
      ancestor_locked_and_has_been_overridden(group)
    end
  end

  def link_to_group(group)
    link_to(group.name, group_path(group))
  end

  def prevent_sharing_groups_outside_hierarchy_help_text(group)
    s_("GroupSettings|Available only on the top-level group. Applies to all subgroups. Groups already shared with a group outside %{group} are still shared unless removed manually.").html_safe % { group: link_to_group(group) }
  end

  def render_setting_to_allow_project_access_token_creation?(group)
    group.root? && current_user.can?(:admin_setting_to_allow_resource_access_token_creation, group)
  end

  def show_thanks_for_purchase_alert?(quantity)
    quantity.to_i > 0
  end

  def project_list_sort_by
    @group_projects_sort || @sort || params[:sort] || sort_value_recently_created
  end

  def subgroup_creation_data(group)
    {
      parent_group_url: group.parent && group_url(group.parent),
      parent_group_name: group.parent&.name,
      import_existing_group_path: new_group_path(parent_id: group.parent_id, anchor: 'import-group-pane'),
      is_saas: Gitlab.com?.to_s
    }
  end

  def group_name_and_path_app_data
    {
      base_path: root_url,
      mattermost_enabled: Gitlab.config.mattermost.enabled.to_s
    }
  end

  def group_overview_tabs_app_data(group)
    {
      group_id: group.id,
      subgroups_and_projects_endpoint: group_children_path(group, format: :json),
      shared_projects_endpoint: group_shared_projects_path(group, format: :json),
      archived_projects_endpoint: group_children_path(group, format: :json, archived: 'only'),
      current_group_visibility: group.visibility,
      initial_sort: project_list_sort_by,
      show_schema_markup: 'true',
      new_subgroup_path: new_group_path(parent_id: group.id, anchor: 'create-group-pane'),
      new_project_path: new_project_path(namespace_id: group.id),
      new_subgroup_illustration: image_path('illustrations/subgroup-create-new-sm.svg'),
      new_project_illustration: image_path('illustrations/project-create-new-sm.svg'),
      empty_projects_illustration: image_path('illustrations/empty-state/empty-projects-md.svg'),
      empty_subgroup_illustration: image_path('illustrations/empty-state/empty-subgroup-md.svg'),
      empty_search_illustration: image_path('illustrations/empty-state/empty-search-md.svg'),
      render_empty_state: 'true',
      can_create_subgroups: can?(current_user, :create_subgroup, group).to_s,
      can_create_projects: can?(current_user, :create_projects, group).to_s
    }
  end

  def group_readme_app_data(group_readme)
    {
      web_path: group_readme.present.web_path,
      name: group_readme.present.name
    }
  end

  def show_group_readme?(group)
    return false unless group.group_readme

    can?(current_user, :read_code, group.readme_project)
  end

  def group_settings_readme_app_data(group)
    {
      group_readme_path: group.group_readme&.present&.web_path,
      readme_project_path: group.readme_project&.present&.path_with_namespace,
      group_path: group.full_path,
      group_id: group.id
    }
  end

  def enabled_git_access_protocol_options_for_group(_)
    case ::Gitlab::CurrentSettings.enabled_git_access_protocol
    when nil, ""
      [[_("Both SSH and HTTP(S)"), "all"], [_("Only SSH"), "ssh"], [_("Only HTTP(S)"), "http"]]
    when "ssh"
      [[_("Only SSH"), "ssh"]]
    when "http"
      [[_("Only HTTP(S)"), "http"]]
    end
  end

  def new_custom_emoji_path(group)
    return unless Feature.enabled?(:custom_emoji)
    return unless group
    return unless can?(current_user, :create_custom_emoji, group)

    new_group_custom_emoji_path(group)
  end

  def access_level_roles_user_can_assign(group)
    max_access_level = group.max_member_access_for_user(current_user)
    group.access_level_roles.select do |_name, access_level|
      access_level <= max_access_level
    end
  end

  def groups_projects_more_actions_dropdown_data(source)
    model_name = source.model_name.to_s.downcase
    dropdown_data = {
      is_group: source.is_a?(Group).to_s,
      id: source.id
    }

    return dropdown_data unless current_user

    if can?(current_user, :"destroy_#{model_name}_member", source.members.find_by(user_id: current_user.id)) # rubocop: disable CodeReuse/ActiveRecord -- we need to fetch it
      dropdown_data[:leave_path] = polymorphic_path([:leave, source, :members])
      dropdown_data[:leave_confirm_message] = leave_confirmation_message(source)
    elsif source.requesters.find_by(user_id: current_user.id) # rubocop: disable CodeReuse/ActiveRecord -- we need to fetch it
      requester = source.requesters.find_by(user_id: current_user.id) # rubocop: disable CodeReuse/ActiveRecord -- we need to fetch it
      if can?(current_user, :withdraw_member_access_request, requester)
        dropdown_data[:withdraw_path] = polymorphic_path([:leave, source, :members])
        dropdown_data[:withdraw_confirm_message] = remove_member_message(requester)
      end
    elsif source.request_access_enabled && can?(current_user, :request_access, source)
      dropdown_data[:request_access_path] = polymorphic_path([:request_access, source, :members])
    end

    dropdown_data
  end

  private

  def group_title_link(group, hidable: false, show_avatar: false)
    link_to(group_path(group), class: "group-path js-breadcrumb-item-text #{'hidable' if hidable}") do
      icon = render Pajamas::AvatarComponent.new(group, alt: group.name, class: "avatar-tile", size: 16) if group.try(:avatar_url) || show_avatar
      [icon, simple_sanitize(group.name)].join.html_safe
    end
  end

  def ancestor_group(group)
    ancestor = oldest_consecutively_locked_ancestor(group)
    if can?(current_user, :read_group, ancestor)
      link_to ancestor.name, group_path(ancestor)
    else
      ancestor.name
    end
  end

  def remove_the_share_with_group_lock_from_ancestor(group)
    ancestor = oldest_consecutively_locked_ancestor(group)
    text = s_("GroupSettings|remove the share with group lock from %{ancestor_group_name}") % { ancestor_group_name: ancestor.name }
    if can?(current_user, :admin_group, ancestor)
      link_to text, edit_group_path(ancestor)
    else
      text
    end
  end

  def oldest_consecutively_locked_ancestor(group)
    sorted_ancestors(group).find do |group|
      !group.has_parent? || !group.parent.share_with_group_lock?
    end
  end

  # Ancestors sorted by hierarchy depth in bottom-top order.
  def sorted_ancestors(group)
    if group.root_ancestor.use_traversal_ids?
      group.ancestors(hierarchy_order: :asc)
    else
      group.ancestors
    end
  end

  def default_help
    s_("GroupSettings|Applied to all subgroups unless overridden by a group owner. Groups already added to the project lose access.")
  end

  def ancestor_locked_but_you_can_override(group)
    s_("GroupSettings|This setting is applied on %{ancestor_group}. You can override the setting or %{remove_ancestor_share_with_group_lock}.").html_safe % { ancestor_group: ancestor_group(group), remove_ancestor_share_with_group_lock: remove_the_share_with_group_lock_from_ancestor(group) }
  end

  def ancestor_locked_so_ask_the_owner(group)
    s_("GroupSettings|This setting is applied on %{ancestor_group}. To share projects in this group with another group, ask the owner to override the setting or %{remove_ancestor_share_with_group_lock}.").html_safe % { ancestor_group: ancestor_group(group), remove_ancestor_share_with_group_lock: remove_the_share_with_group_lock_from_ancestor(group) }
  end

  def ancestor_locked_and_has_been_overridden(group)
    s_("GroupSettings|This setting is applied on %{ancestor_group} and has been overridden on this subgroup.").html_safe % { ancestor_group: ancestor_group(group) }
  end

  def group_url_error_message
    s_('GroupSettings|Choose a group path that does not start with a dash or end with a period. It can also contain alphanumeric characters and underscores.')
  end

  # Maps `jobs_to_be_done` values to option texts
  def localized_jobs_to_be_done_choices
    {
      basics: _('I want to learn the basics of Git'),
      move_repository: _('I want to move my repository to GitLab from somewhere else'),
      code_storage: _('I want to store my code'),
      exploring: _('I want to explore GitLab to see if it’s worth switching to'),
      ci: _('I want to use GitLab CI with my existing repository'),
      other: _('A different reason')
    }.with_indifferent_access.freeze
  end
end

GroupsHelper.prepend_mod_with('GroupsHelper')
