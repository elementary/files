/***
    ViewSwicher.cs

    Authors:
       mathijshenquet <mathijs.henquet@gmail.com>
       ammonkey <am.monkeyd@gmail.com>

    Copyright (c) 2010 mathijshenquet

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
***/

namespace Marlin.View.Chrome {

    public class ViewSwitcher : Gtk.Box {
        public Granite.Widgets.ModeButton switcher;

        private int _mode;
        public int mode {
            set {
                Gtk.Widget target;
                int active_index;

                switch ((Marlin.ViewMode)value) {
                case Marlin.ViewMode.LIST:
                    target = list;
                    active_index = 1;
                    break;
                case Marlin.ViewMode.MILLER_COLUMNS:
                    target = miller;
                    active_index = 2;
                    break;
                default:
                    target = icon;
                    active_index = 0;
                    value = 0;
                    break;
                }

                freeze_update = true;
                switcher.set_active (active_index);
                freeze_update = false;
                _mode = value;
            }
            private get {
                return _mode;
            }
        }

        private bool freeze_update = false;
        private GLib.SimpleAction view_mode_action;

        private Gtk.Image icon;
        private Gtk.Image list;
        private Gtk.Image miller;

        private GLib.Variant icon_sv;
        private GLib.Variant list_sv;
        private GLib.Variant miller_sv;

        public ViewSwitcher (GLib.SimpleAction _view_mode_action) {
            Object (orientation: Gtk.Orientation.HORIZONTAL);

            this.view_mode_action = _view_mode_action;
            switcher = new Granite.Widgets.ModeButton ();
            switcher.halign = switcher.valign = Gtk.Align.CENTER;

            icon = new Gtk.Image.from_icon_name ("view-grid-symbolic", Gtk.IconSize.MENU);
            icon.tooltip_text = _("View as Grid")+" (Ctrl + 1)";
            switcher.append (icon);
            icon_sv = new GLib.Variant.string ("ICON");

            list = new Gtk.Image.from_icon_name ("view-list-symbolic", Gtk.IconSize.MENU);
            list.tooltip_text = _("View as List")+" (Ctrl + 2)";
            switcher.append (list);
            list_sv = new GLib.Variant.string ("LIST");

            miller = new Gtk.Image.from_icon_name ("view-column-symbolic", Gtk.IconSize.MENU);
            miller.tooltip_text = _("View in Columns")+" (Ctrl + 3)";
            switcher.append (miller);
            miller_sv = new GLib.Variant.string ("MILLER");

            switcher.mode_changed.connect ((image) => {
                if (freeze_update) {
                    return;
                }

                if (image == list) {
                    view_mode_action.activate (list_sv);
                } else if (image == miller) {
                    view_mode_action.activate (miller_sv);
                } else {
                    view_mode_action.activate (icon_sv);
                }
            });

            switcher.sensitive = true;

            pack_start (switcher, true, true, 0);
        }
    }
}
