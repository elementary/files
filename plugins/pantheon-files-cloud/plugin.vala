/***
    Copyright (c) 2019 elementary LLC <https://elementary.io>

    Pantheon Files is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of the
    License, or (at your option) any later version.

    Pantheon Files is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program.  If not, see <http://www.gnu.org/licenses/>.

    Author(s):  Fernando da Silva Sousa <wild.nando@gmail.com>
***/

public class Marlin.Plugins.Cloud.Plugin : Marlin.Plugins.Base {
    Marlin.SidebarInterface? sidebar;
    CloudProviders.Collector collector;
    Gee.ArrayList<CloudProviders.Provider> providers_connected;

    public Plugin () {
        providers_connected = new Gee.ArrayList<CloudProviders.Provider> ();
        collector = CloudProviders.Collector.dup_singleton ();
        collector.providers_changed.connect (on_providers_changes);
    }

    /**
     * Assign loaded sidebar to plugin's sidebar reference
     *
     * @param a instance of Marlin.AbstractSidebar
     */
    public override void sidebar_loaded (Gtk.Widget widget) {
        sidebar = (Marlin.SidebarInterface)widget;
        on_providers_changes ();
    }

    /**
     * Plugin hook that triggers when sidebar receives a update request on
     * Marlin's code
     *
     * @param a instance of Marlin.AbstractSidebar
     */
    public override void update_sidebar (Gtk.Widget widget) {
        foreach (var provider in collector.get_providers ()) {
            foreach (var account in provider.get_accounts ()) {
                add_account_to_sidebar (account, provider);
            }
        }
    }

    void on_providers_changes () {
        //  Listen to new accounts
        unowned GLib.List<CloudProviders.Provider> providers = collector.get_providers ();
        foreach (var provider in providers) {
            //  Avoid listening to same provider again
            if (!(provider in providers_connected)) {
                providers_connected.add (provider);
                provider.accounts_changed.connect (on_accounts_changed);
            }
        }

        /* Remove any lost providers */
        foreach (var provider in providers_connected) {
            if (providers.find (provider) == null) {
                provider.accounts_changed.disconnect (on_accounts_changed);
                providers_connected.remove (provider);
            }
        }

        //  Request sidebar update to show new accounts
        request_sidebar_update ();
    }

    void on_accounts_changed () {
        request_sidebar_update ();
    }

    /**
     * Request a update on marlin's sidebar
     */
    void request_sidebar_update () {
        return_if_fail (sidebar != null);
        sidebar.request_update ();
    }

    void add_account_to_sidebar (CloudProviders.Account account, CloudProviders.Provider provider) {
        //  Fix menu loading with wrong order by forcing dbus to cache menu_model
        account.menu_model.get_n_items ();
        var reference = sidebar.add_plugin_item (adapt_plugin_item (provider, account),
                                                 Marlin.PlaceType.NETWORK_CATEGORY);

        //  Update sidebar representation of the cloudprovider account on it's properties changes
        account.notify.connect (() => {
            return_if_fail (sidebar != null);
            sidebar.update_plugin_item (adapt_plugin_item (provider, account), reference);
        });
    }

    /**
     * Generate a SidebarPluginItem from provider and account informations
     */
    static Marlin.SidebarPluginItem adapt_plugin_item (CloudProviders.Provider provider,
                                                        CloudProviders.Account account) {

        var item = new Marlin.SidebarPluginItem () {
            name = account.name,
            tooltip = account.path,
            uri = account.path,
            icon = account.icon,
            show_spinner = account.get_status () == CloudProviders.AccountStatus.SYNCING,
            action_group = account.action_group,
            action_group_namespace = "cloudprovider",
            menu_model = account.menu_model,
            action_icon = get_icon (account.get_status ())
        };

        return item;
    }

    /**
     * Get icon for current account status
     *
     * @param a status {@link CloudProviders.AccountStatus} of a {@link CloudProviders.Account}
     *
     * @return a error icon if status is error else returns null
     */
    static Icon? get_icon (CloudProviders.AccountStatus status) {
        return status == CloudProviders.AccountStatus.ERROR ?
                         new ThemedIcon.with_default_fallbacks ("dialog-error-symbolic") :
                         null;
    }
}

public Marlin.Plugins.Base module_init () {
    return new Marlin.Plugins.Cloud.Plugin ();
}
