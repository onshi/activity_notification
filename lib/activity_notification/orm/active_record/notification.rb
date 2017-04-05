require 'activity_notification/apis/notification_api'

module ActivityNotification
  module ORM
    module ActiveRecord
      # Notification model implementation generated by ActivityNotification.
      class Notification < ::ActiveRecord::Base
        include Common
        include Renderable
        include NotificationApi
        # @deprecated ActivityNotification.config.table_name as of 1.1.0
        self.table_name = ActivityNotification.config.table_name || ActivityNotification.config.notification_table_name
        # self.table_name = ActivityNotification.config.notification_table_name

        # Belongs to target instance of this notification as polymorphic association.
        # @scope instance
        # @return [Object] Target instance of this notification
        belongs_to :target,        polymorphic: true

        # Belongs to notifiable instance of this notification as polymorphic association.
        # @scope instance
        # @return [Object] Notifiable instance of this notification
        belongs_to :notifiable,    polymorphic: true

        # Belongs to group instance of this notification as polymorphic association.
        # @scope instance
        # @return [Object] Group instance of this notification
        belongs_to :group,         polymorphic: true

        # Belongs to group owner notification instance of this notification.
        # Only group member instance has :group_owner value.
        # Group owner instance has nil as :group_owner association.
        # @scope instance
        # @return [Notification] Group owner notification instance of this notification
        belongs_to :group_owner, { class_name: "ActivityNotification::Notification" }.merge(Rails::VERSION::MAJOR >= 5 ? { optional: true } : {})

        # Has many group member notification instances of this notification.
        # Only group owner instance has :group_members value.
        # Group member instance has nil as :group_members association.
        # @scope instance
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of the group member notification instances of this notification
        has_many   :group_members, class_name: "ActivityNotification::Notification", foreign_key: :group_owner_id

        # Belongs to :otifier instance of this notification.
        # @scope instance
        # @return [Object] Notifier instance of this notification
        belongs_to :notifier,      polymorphic: true

        # Serialize parameters Hash
        serialize  :parameters, Hash

        validates  :target,        presence: true
        validates  :notifiable,    presence: true
        validates  :key,           presence: true

        # Selects group owner notifications only.
        # @scope class
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :group_owners_only,                 -> { where(group_owner_id: nil) }

        # Selects group member notifications only.
        # @scope class
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :group_members_only,                -> { where.not(group_owner_id: nil) }

        # Selects all notification index.
        #   ActivityNotification::Notification.all_index!
        # is defined same as
        #   ActivityNotification::Notification.group_owners_only.latest_order
        # @scope class
        # @example Get all notification index of the @user
        #   @notifications = @user.notifications.all_index!
        #   @notifications = @user.notifications.group_owners_only.latest_order
        # @param [Boolean] reverse If notification index will be ordered as earliest first
        # @param [Boolean] with_group_members If notification index will include group members
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :all_index!,                        ->(reverse = false, with_group_members = false) {
          target_index = with_group_members ? self : group_owners_only
          reverse ? target_index.earliest_order : target_index.latest_order
        }

        # Selects unopened notifications only.
        # @scope class
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :unopened_only,                     -> { where(opened_at: nil) }

        # Selects unopened notification index.
        #   ActivityNotification::Notification.unopened_index
        # is defined same as
        #   ActivityNotification::Notification.unopened_only.group_owners_only.latest_order
        # @scope class
        # @example Get unopened notificaton index of the @user
        #   @notifications = @user.notifications.unopened_index
        #   @notifications = @user.notifications.unopened_only.group_owners_only.latest_order
        # @param [Boolean] reverse If notification index will be ordered as earliest first
        # @param [Boolean] with_group_members If notification index will include group members
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :unopened_index,                    ->(reverse = false, with_group_members = false) {
          target_index = with_group_members ? unopened_only : unopened_only.group_owners_only
          reverse ? target_index.earliest_order : target_index.latest_order
        }

        # Selects opened notifications only without limit.
        # Be careful to get too many records with this method.
        # @scope class
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :opened_only!,                      -> { where.not(opened_at: nil) }

        # Selects opened notifications only with limit.
        # @scope class
        # @param [Integer] limit Limit to query for opened notifications
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :opened_only,                       ->(limit) { opened_only!.limit(limit) }

        # Selects unopened notification index.
        #   ActivityNotification::Notification.opened_index(limit)
        # is defined same as
        #   ActivityNotification::Notification.opened_only(limit).group_owners_only.latest_order
        # @scope class
        # @example Get unopened notificaton index of the @user with limit 10
        #   @notifications = @user.notifications.opened_index(10)
        #   @notifications = @user.notifications.opened_only(10).group_owners_only.latest_order
        # @param [Integer] limit Limit to query for opened notifications
        # @param [Boolean] reverse If notification index will be ordered as earliest first
        # @param [Boolean] with_group_members If notification index will include group members
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :opened_index,                      ->(limit, reverse = false, with_group_members = false) {
          target_index = with_group_members ? opened_only(limit) : opened_only(limit).group_owners_only
          reverse ? target_index.earliest_order : target_index.latest_order
        }

        # Selects group member notifications in unopened_index.
        # @scope class
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :unopened_index_group_members_only, -> { where(group_owner_id: unopened_index.map(&:id)) }

        # Selects group member notifications in opened_index.
        # @scope class
        # @param [Integer] limit Limit to query for opened notifications
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :opened_index_group_members_only,   ->(limit) { where(group_owner_id: opened_index(limit).map(&:id)) }

        # Selects notifications within expiration.
        # @scope class
        # @param [ActiveSupport::Duration] expiry_delay Expiry period of notifications
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :within_expiration_only,            ->(expiry_delay) { where("created_at > ?", expiry_delay.ago) }

        # Selects group member notifications with specified group owner ids.
        # @scope class
        # @param [Array<String>] owner_ids Array of group owner ids
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :group_members_of_owner_ids_only,   ->(owner_ids) { where(group_owner_id: owner_ids) }

        # Selects filtered notifications by target instance.
        #   ActivityNotification::Notification.filtered_by_target(@user)
        # is the same as
        #   @user.notifications
        # @scope class
        # @param [Object] target Target instance for filter
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :filtered_by_target,                ->(target) { where(target: target) }

        # Selects filtered notifications by target_type.
        # @example Get filtered unopened notificatons of User as target type
        #   @notifications = ActivityNotification.Notification.unopened_only.filtered_by_target_type('User')
        # @scope class
        # @param [String] target_type Target type for filter
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :filtered_by_target_type,           ->(target_type) { where(target_type: target_type) }

        # Selects filtered notifications by notifiable instance.
        # @example Get filtered unopened notificatons of the @user for @comment as notifiable
        #   @notifications = @user.notifications.unopened_only.filtered_by_instance(@comment)
        # @scope class
        # @param [Object] notifiable Notifiable instance for filter
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :filtered_by_instance,              ->(notifiable) { where(notifiable: notifiable) }

        # Selects filtered notifications by notifiable_type.
        # @example Get filtered unopened notificatons of the @user for Comment notifiable class
        #   @notifications = @user.notifications.unopened_only.filtered_by_type('Comment')
        # @scope class
        # @param [String] notifiable_type Notifiable type for filter
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :filtered_by_type,                  ->(notifiable_type) { where(notifiable_type: notifiable_type) }

        # Selects filtered notifications by group instance.
        # @example Get filtered unopened notificatons of the @user for @article as group
        #   @notifications = @user.notifications.unopened_only.filtered_by_group(@article)
        # @scope class
        # @param [Object] group Group instance for filter
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :filtered_by_group,                 ->(group) { where(group: group) }

        # Selects filtered notifications by key.
        # @example Get filtered unopened notificatons of the @user with key 'comment.reply'
        #   @notifications = @user.notifications.unopened_only.filtered_by_key('comment.reply')
        # @scope class
        # @param [String] key Key of the notification for filter
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :filtered_by_key,                   ->(key) { where(key: key) }

        # Selects filtered notifications by notifiable_type, group or key with filter options.
        # @example Get filtered unopened notificatons of the @user for Comment notifiable class
        #   @notifications = @user.notifications.unopened_only.filtered_by_options({ filtered_by_type: 'Comment' })
        # @example Get filtered unopened notificatons of the @user for @article as group
        #   @notifications = @user.notifications.unopened_only.filtered_by_options({ filtered_by_group: @article })
        # @example Get filtered unopened notificatons of the @user for Article instance id=1 as group
        #   @notifications = @user.notifications.unopened_only.filtered_by_options({ filtered_by_group_type: 'Article', filtered_by_group_id: '1' })
        # @example Get filtered unopened notificatons of the @user with key 'comment.reply'
        #   @notifications = @user.notifications.unopened_only.filtered_by_options({ filtered_by_key: 'comment.reply' })
        # @example Get filtered unopened notificatons of the @user for Comment notifiable class with key 'comment.reply'
        #   @notifications = @user.notifications.unopened_only.filtered_by_options({ filtered_by_type: 'Comment', filtered_by_key: 'comment.reply' })
        # @example Get custom filtered notificatons of the @user
        #   @notifications = @user.notifications.unopened_only.filtered_by_options({ custom_filter: ["created_at >= ?", time.hour.ago] })
        # @scope class
        # @param [Hash] options Options for filter
        # @option options [String]     :filtered_by_type       (nil) Notifiable type for filter
        # @option options [Object]     :filtered_by_group      (nil) Group instance for filter
        # @option options [String]     :filtered_by_group_type (nil) Group type for filter, valid with :filtered_by_group_id
        # @option options [String]     :filtered_by_group_id   (nil) Group instance id for filter, valid with :filtered_by_group_type
        # @option options [String]     :filtered_by_key        (nil) Key of the notification for filter 
        # @option options [Array|Hash] :custom_filter          (nil) Custom notification filter (e.g. ["created_at >= ?", time.hour.ago])
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of filtered notifications
        scope :filtered_by_options,               ->(options = {}) {
          options = ActivityNotification.cast_to_indifferent_hash(options)
          filtered_notifications = all
          if options.has_key?(:filtered_by_type)
            filtered_notifications = filtered_notifications.filtered_by_type(options[:filtered_by_type])
          end
          if options.has_key?(:filtered_by_group)
            filtered_notifications = filtered_notifications.filtered_by_group(options[:filtered_by_group])
          end
          if options.has_key?(:filtered_by_group_type) && options.has_key?(:filtered_by_group_id)
            filtered_notifications = filtered_notifications
                                     .where(group_type: options[:filtered_by_group_type], group_id: options[:filtered_by_group_id])
          end
          if options.has_key?(:filtered_by_key)
            filtered_notifications = filtered_notifications.filtered_by_key(options[:filtered_by_key])
          end
          if options.has_key?(:custom_filter)
            filtered_notifications = filtered_notifications.where(options[:custom_filter])
          end
          filtered_notifications
        }

        # Includes target instance with query for notifications.
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of notifications with target
        scope :with_target,                       -> { includes(:target) }

        # Includes notifiable instance with query for notifications.
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of notifications with notifiable
        scope :with_notifiable,                   -> { includes(:notifiable) }

        # Includes group instance with query for notifications.
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of notifications with group
        scope :with_group,                        -> { includes(:group) }

        # Includes group owner instances with query for notifications.
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of notifications with group owner
        scope :with_group_owner,                  -> { includes(:group_owner) }

        # Includes group member instances with query for notifications.
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of notifications with group members
        scope :with_group_members,                -> { includes(:group_members) }

        # Includes notifier instance with query for notifications.
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of notifications with notifier
        scope :with_notifier,                     -> { includes(:notifier) }

        # Orders by latest (newest) first as created_at: :desc.
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of notifications ordered by latest first
        scope :latest_order,                      -> { order(created_at: :desc) }

        # Orders by earliest (older) first as created_at: :asc.
        # @return [ActiveRecord_AssociationRelation<Notificaion>] Database query of notifications ordered by earliest first
        scope :earliest_order,                    -> { order(created_at: :asc) }

        # Returns latest notification instance.
        # @return [Notification] Latest notification instance
        def self.latest
          latest_order.first
        end

        # Returns earliest notification instance.
        # @return [Notification] Earliest notification instance
        def self.earliest
          earliest_order.first
        end

        # Selects unique keys from query for notifications.
        # @return [Array<String>] Array of notification unique keys
        def self.uniq_keys
          select(:key).distinct.pluck(:key)
        end

        protected

          # Returns count of group members of the unopened notification.
          # This method is designed to cache group by query result to avoid N+1 call.
          # @api protected
          #
          # @return [Integer] Count of group members of the unopened notification
          def unopened_group_member_count
            # Cache group by query result to avoid N+1 call
            unopened_group_member_counts = target.notifications
                                                 .unopened_index_group_members_only
                                                 .group(:group_owner_id)
                                                 .count
            unopened_group_member_counts[id] || 0
          end

          # Returns count of group members of the opened notification.
          # This method is designed to cache group by query result to avoid N+1 call.
          # @api protected
          #
          # @return [Integer] Count of group members of the opened notification
          def opened_group_member_count(limit = ActivityNotification.config.opened_index_limit)
            # Cache group by query result to avoid N+1 call
            opened_group_member_counts   = target.notifications
                                                 .opened_index_group_members_only(limit)
                                                 .group(:group_owner_id)
                                                 .count
            count = opened_group_member_counts[id] || 0
            count > limit ? limit : count
          end

          # Returns count of group member notifiers of the unopened notification not including group owner notifier.
          # This method is designed to cache group by query result to avoid N+1 call.
          # @api protected
          #
          # @return [Integer] Count of group member notifiers of the unopened notification
          def unopened_group_member_notifier_count
            # Cache group by query result to avoid N+1 call
            unopened_group_member_notifier_counts = target.notifications
                                                          .unopened_index_group_members_only
                                                          .includes(:group_owner)
                                                          .where('group_owners_notifications.notifier_type = notifications.notifier_type')
                                                          .where.not('group_owners_notifications.notifier_id = notifications.notifier_id')
                                                          .references(:group_owner)
                                                          .group(:group_owner_id, :notifier_type)
                                                          .count('distinct notifications.notifier_id')
            unopened_group_member_notifier_counts[[id, notifier_type]] || 0
          end

          # Returns count of group member notifiers of the opened notification not including group owner notifier.
          # This method is designed to cache group by query result to avoid N+1 call.
          # @api protected
          #
          # @return [Integer] Count of group member notifiers of the opened notification
          def opened_group_member_notifier_count(limit = ActivityNotification.config.opened_index_limit)
            # Cache group by query result to avoid N+1 call
            opened_group_member_notifier_counts   = target.notifications
                                                          .opened_index_group_members_only(limit)
                                                          .includes(:group_owner)
                                                          .where('group_owners_notifications.notifier_type = notifications.notifier_type')
                                                          .where.not('group_owners_notifications.notifier_id = notifications.notifier_id')
                                                          .references(:group_owner)
                                                          .group(:group_owner_id, :notifier_type)
                                                          .count('distinct notifications.notifier_id')
            count = opened_group_member_notifier_counts[[id, notifier_type]] || 0
            count > limit ? limit : count
          end

      end
    end
  end
end
