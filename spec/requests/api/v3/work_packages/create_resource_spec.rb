#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2022 the OpenProject GmbH
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
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'
require 'rack/test'

describe 'API v3 Work package resource',
         type: :request,
         content_type: :json do
  include API::V3::Utilities::PathHelper

  let(:project) do
    create(:project, identifier: 'test_project', public: false)
  end
  let(:role) { create(:role, permissions:) }
  let(:permissions) { %i[add_work_packages view_project view_work_packages] }

  current_user do
    create(:user, member_in_project: project, member_through_role: role)
  end

  describe 'POST /api/v3/work_packages' do
    let(:path) { api_v3_paths.work_packages }
    let(:other_user) { nil }
    let(:status) { build(:status, is_default: true) }
    let(:priority) { build(:priority, is_default: true) }
    let(:type) { project.types.first }
    let(:parameters) do
      {
        subject: 'new work packages',
        _links: {
          type: {
            href: api_v3_paths.type(type.id)
          },
          project: {
            href: api_v3_paths.project(project.id)
          }
        }
      }
    end

    before do
      status.save!
      priority.save!
      other_user

      perform_enqueued_jobs do
        post path, parameters.to_json
      end
    end

    describe 'notifications' do
      let(:other_user) { create(:user, member_in_project: project, member_with_permissions: permissions) }

      it 'creates a notification' do
        expect(Notification.where(recipient: other_user, resource: WorkPackage.last))
          .to exist
      end

      context 'without notifications' do
        let(:path) { "#{api_v3_paths.work_packages}?notify=false" }

        it 'creates no notification' do
          expect(Notification)
            .not_to exist
        end
      end

      context 'with notifications' do
        let(:path) { "#{api_v3_paths.work_packages}?notify=true" }

        it 'creates a notification' do
          expect(Notification.where(recipient: other_user, resource: WorkPackage.last))
            .to exist
        end
      end
    end

    it 'returns Created(201)' do
      expect(last_response.status).to eq(201)
    end

    it 'creates a work package' do
      expect(WorkPackage.all.count).to eq(1)
    end

    it 'uses the given parameters' do
      expect(WorkPackage.first.subject).to eq(parameters[:subject])
    end

    it 'is associated with the provided project' do
      expect(WorkPackage.first.project).to eq(project)
    end

    it 'is associated with the provided type' do
      expect(WorkPackage.first.type).to eq(type)
    end

    context 'no permissions' do
      let(:current_user) { create(:user) }

      it 'hides the endpoint' do
        expect(last_response.status).to eq(403)
      end
    end

    context 'view_project permission' do
      # Note that this just removes the add_work_packages permission
      # view_project is actually provided by being a member of the project
      let(:permissions) { [:view_project] }

      it 'points out the missing permission' do
        expect(last_response.status).to eq(403)
      end
    end

    context 'empty parameters' do
      let(:parameters) { {} }

      it_behaves_like 'multiple errors', 422

      it 'does not create a work package' do
        expect(WorkPackage.all.count).to eq(0)
      end
    end

    context 'bogus parameters' do
      let(:parameters) do
        {
          bogus: 'bogus',
          _links: {
            type: {
              href: api_v3_paths.type(project.types.first.id)
            },
            project: {
              href: api_v3_paths.project(project.id)
            }
          }
        }
      end

      it_behaves_like 'constraint violation' do
        let(:message) { "Subject can't be blank" }
      end

      it 'does not create a work package' do
        expect(WorkPackage.all.count).to eq(0)
      end
    end

    context 'schedule manually' do
      let(:work_package) { WorkPackage.first }

      context 'with true' do
        # mind the () for the super call, those are required in rspec's super
        let(:parameters) { super().merge(scheduleManually: true) }

        it 'sets the scheduling mode to true' do
          expect(work_package.schedule_manually).to be true
        end
      end

      context 'with false' do
        let(:parameters) { super().merge(scheduleManually: false) }

        it 'sets the scheduling mode to false' do
          expect(work_package.schedule_manually).to be false
        end
      end

      context 'with scheduleManually absent' do
        it 'sets the scheduling mode to false (default)' do
          expect(work_package.schedule_manually).to be false
        end
      end
    end

    context 'invalid value' do
      let(:parameters) do
        {
          subject: nil,
          _links: {
            type: {
              href: api_v3_paths.type(project.types.first.id)
            },
            project: {
              href: api_v3_paths.project(project.id)
            }
          }
        }
      end

      it_behaves_like 'constraint violation' do
        let(:message) { "Subject can't be blank" }
      end

      it 'does not create a work package' do
        expect(WorkPackage.all.count).to eq(0)
      end
    end

    context 'claiming attachments' do
      let(:attachment) { create(:attachment, container: nil, author: current_user) }
      let(:parameters) do
        {
          subject: 'subject',
          _links: {
            type: {
              href: api_v3_paths.type(project.types.first.id)
            },
            project: {
              href: api_v3_paths.project(project.id)
            },
            attachments: [
              href: api_v3_paths.attachment(attachment.id)
            ]
          }
        }
      end

      it 'creates the work package and assigns the attachments' do
        expect(WorkPackage.all.count).to eq(1)

        work_package = WorkPackage.last

        expect(work_package.attachments)
          .to match_array(attachment)
      end
    end
  end
end
