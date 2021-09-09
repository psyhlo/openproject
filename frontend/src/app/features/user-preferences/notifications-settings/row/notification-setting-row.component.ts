import {
  ChangeDetectionStrategy,
  Component,
  Input,
  OnInit,
} from '@angular/core';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { arrayUpdate } from '@datorama/akita';
import { NotificationSetting } from 'core-app/features/user-preferences/state/notification-setting.model';
import { UserPreferencesService } from 'core-app/features/user-preferences/state/user-preferences.service';

@Component({
  // eslint-disable-next-line @angular-eslint/component-selector
  selector: '[op-notification-setting-row]',
  templateUrl: './notification-setting-row.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class NotificationSettingRowComponent implements OnInit {
  @Input() first = false;

  @Input() count:number;

  @Input() setting:NotificationSetting;

  /** Whether this setting is global */
  global = false;

  text = {
    title: this.I18n.t('js.notifications.settings.title'),
    save: this.I18n.t('js.button_save'),
    email: this.I18n.t('js.notifications.email'),
    inApp: this.I18n.t('js.notifications.in_app'),
    remove_all: this.I18n.t('js.notifications.settings.remove_all'),
    involved_header: this.I18n.t('js.notifications.settings.involved'),
    mentioned_header: this.I18n.t('js.notifications.settings.mentioned'),
    watched_header: this.I18n.t('js.notifications.settings.watched'),
    work_package_commented_header: this.I18n.t('js.notifications.settings.work_package_commented'),
    work_package_created_header: this.I18n.t('js.notifications.settings.work_package_created'),
    work_package_processed_header: this.I18n.t('js.notifications.settings.work_package_processed'),
    work_package_prioritized_header: this.I18n.t('js.notifications.settings.work_package_prioritized'),
    work_package_scheduled_header: this.I18n.t('js.notifications.settings.work_package_scheduled'),
    any_event_header: this.I18n.t('js.notifications.settings.all'),
    default_all_projects: this.I18n.t('js.notifications.settings.default_all_projects'),
    add_setting: this.I18n.t('js.notifications.settings.add'),
    channel: (channel:string):string => this.I18n.t(`js.notifications.channels.${channel}`),
  };

  constructor(
    private I18n:I18nService,
    private storeService:UserPreferencesService,
  ) {
  }

  ngOnInit() {
    this.global = this.setting._links.project.href === null;
  }

  remove():void {
    this.storeService.store.update(
      ({ notifications }) => ({
        notifications: notifications.filter((notification) => notification._links.project.href !== this.setting._links.project.href),
      }),
    );
  }

  update(delta:Partial<NotificationSetting>) {
    this.storeService.store.update(
      ({ notifications }) => ({
        notifications: arrayUpdate(
          notifications, this.matcherFn.bind(this), delta,
        ),
      }),
    );
  }

  private matcherFn(notification:NotificationSetting) {
    return notification._links.project.href === this.setting._links.project.href
      && notification.channel === this.setting.channel;
  }
}
