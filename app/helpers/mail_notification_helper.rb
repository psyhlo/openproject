#-- encoding: UTF-8

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2021 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

module MailNotificationHelper
  include ::ColorsHelper

  def logo_tag(**options)
    current_logo = CustomStyle.current.logo unless CustomStyle.current.nil?

    if current_logo.present?
      logo_file = current_logo.local_file
      logo = File.read(logo_file)
      suffix = MIME::Types.type_for(logo_file.path).first.content_type
    else
      logo = Rails.application.assets["logo_openproject_narrow.svg"]
      suffix = "svg+xml"
    end

    email_image_tag(logo, suffix, options)
  end

  def email_image_tag(image, suffix, **options)
    image_string = image.to_s
    base64_string = Base64.strict_encode64(image_string)

    image_tag "data:image/#{suffix};base64,#{base64_string}", **options
  end

  def notification_timestamp_text(journal, html: true, extended_text: false)
    user = html ? link_to_user(journal.user, only_path: false) : journal.user.name

    timestamp_text(user, journal, extended_text)
  end

  def unique_reasons_of_notifications(notifications)
    notifications
      .map(&:reason_mail_digest)
      .uniq
  end

  def notifications_path(id)
    notifications_center_url(['details', id, 'activity'])
  end

  def type_color(type, default_fallback)
    color_id = selected_color(type)
    color_id ? Color.find(color_id).hexcode : default_fallback
  end

  def status_colors(status)
    color_id = selected_color(status)
    Color.find(color_id).color_styles.map { |k, v| "#{k}:#{v};" }.join(' ') if color_id
  end

  private

  def timestamp_text(user, journal, extended)
    value = journal.initial? ? "created" : "updated"
    if extended
      sanitize(
        "#{I18n.t(:"mail.notifications.work_packages.#{value}")} #{I18n.t(:"mail.notifications.work_packages.#{value}_at",
                                                                          user: user,
                                                                          timestamp: journal.created_at.strftime(
                                                                            I18n.t(:'time.formats.time')
                                                                          ))}"
      )
    else
      sanitize(I18n.t(:"mail.notifications.work_packages.#{value}_at",
                      user: user,
                      timestamp: journal.created_at.strftime(I18n.t(:'time.formats.time'))))
    end
  end
end
