// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2015 Pantheon Developers (http://launchpad.net/elementary)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <tintou@mailoo.org>
 */

namespace Marlin {
    public const string ROOT_FS_URI = "file://";
    public const double MINIMUM_LOCATION_BAR_ENTRY_WIDTH = 36;
}

public struct Marlin.View.Chrome.IconDirectory {
    string path;
    string icon_name;
    bool protocol;
    GLib.Icon gicon;
    Gdk.Pixbuf icon;
    string[] exploded;
    bool break_loop;
    string? text_displayed;
}

public abstract class Marlin.View.Chrome.BasePathBar : Gtk.Entry {

    public enum TargetType {
        TEXT_URI_LIST,
    }

    protected const Gdk.DragAction file_drag_actions = (Gdk.DragAction.COPY | Gdk.DragAction.MOVE | Gdk.DragAction.LINK);


    public string current_right_click_path;
    public string current_right_click_root;

    
    protected string text_completion = "";
    protected bool multiple_completions = false;
    protected bool text_changed = false;
    protected bool ignore_focus_in = false;
    protected bool ignore_change = false;

    /* if we must display the BreadcrumbsElement which are in  newbreads. */
    bool view_old = false;

    /* This list will contain all BreadcrumbsElement */
    protected Gee.ArrayList<BreadcrumbsElement> elements;

    /* This list will contain the BreadcrumbsElement which are animated */
    Gee.List<BreadcrumbsElement> newbreads;

    /* A flag to know when the animation is finished */
    double anim_state = 0;

    /* A flag to 'hide' animation if desired */
    public bool animation_visible = true;

    Gtk.StyleContext button_context;
    Gtk.StyleContext button_context_active;

    /**
     * When the user click on a breadcrumb, or when he enters a path by hand
     * in the integrated entry
     **/
    public signal void activate_alternate (File file);
    public signal void path_changed (File file);
    public signal void need_completion ();
    public signal void reload ();

    List<IconDirectory?> icons;

    string current_path = "";

    int selected = -1;
    int space_breads = 12;
    int x;
    int y;
    string protocol;

    public signal void completed ();
    public signal void escape ();
    public signal void up ();
    public signal void down ();

    private int timeout = -1;

    private Granite.Services.IconFactory icon_factory;

    private Gdk.Window? entry_window = null;

    construct {
        icon_factory = Granite.Services.IconFactory.get_default ();
        icons = new List<IconDirectory?> ();

        button_context = get_style_context ();
        button_context.add_class ("button");
        button_context.add_class ("raised");
        button_context.add_class ("marlin-pathbar");
        button_context.add_class ("pathbar");

        Gtk.Border border = button_context.get_padding (Gtk.StateFlags.NORMAL);
        //Granite.Widgets.Utils.set_theming (this, , null,
               //                            );

        var css = new Gtk.CssProvider ();
        css.load_from_data ("* {
.noradius-button{border-radius:0px;}
}", 0);

        this.get_style_context ().add_provider (css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        /* x padding */
        x = 0;
        /* y padding */
        y = 0;

        elements = new Gee.ArrayList<BreadcrumbsElement> ();
        
        secondary_icon_activatable = true;
        secondary_icon_sensitive = true;
        truncate_multiline = true;

        realize.connect_after (after_realize);
        activate.connect (on_activate);
        button_press_event.connect (on_button_press_event);
        button_release_event.connect (on_button_release_event);
        icon_press.connect (on_icon_press);
        motion_notify_event.connect_after (after_motion_notify);
        focus_in_event.connect (on_focus_in);
        focus_out_event.connect (on_focus_out);
        grab_focus.connect_after (on_grab_focus);
        changed.connect (on_change);

        /* Drag and drop */
        Gtk.TargetEntry target_uri_list = {"text/uri-list", 0, TargetType.TEXT_URI_LIST};
        Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, {target_uri_list}, Gdk.DragAction.MOVE);
        drag_leave.connect (on_drag_leave);
        drag_motion.connect (on_drag_motion);
        drag_data_received.connect (on_drag_data_received);
        drag_drop.connect (on_drag_drop);
    }

    public bool on_key_press_event (Gdk.EventKey event) {
        switch (event.keyval) {
            case Gdk.Key.KP_Tab:
            case Gdk.Key.Tab:
                complete ();
                return true;

            case Gdk.Key.KP_Down:
            case Gdk.Key.Down:
                down ();
                return true;

            case Gdk.Key.KP_Up:
            case Gdk.Key.Up:
                up ();
                return true;
                
            case Gdk.Key.Escape:
                escape ();
                return true;
        }

        return base.key_press_event (event);
    }

    public bool on_button_press_event (Gdk.EventButton event) {
        /* We need to distinguish whether the event comes from one of the icons.
         * There doesn't seem to be a way of doing this directly so we check the window width */
        if (event.window.get_width () < 24)
            return false;

        if (is_focus)    
            return base.button_press_event (event);

        foreach (BreadcrumbsElement element in elements)
            element.pressed = false;

        var el = get_element_from_coordinates ((int) event.x, (int) event.y);

        if (el != null)
            el.pressed = true;

        queue_draw ();

        if (timeout == -1 && event.button == 1) {
            timeout = (int) Timeout.add (150, () => {
                select_bread_from_coord (event);
                timeout = -1;
                return false;
            });
        }

            if (el != null) {
                selected = elements.index_of (el);
                var newpath = get_path_from_element (el);
                change_breadcrumbs (newpath, true);
                activate_alternate (get_file_for_path (newpath));
            }

        if (event.button == 3)
            return select_bread_from_coord (event);

        return true;
    }

    public bool on_button_release_event (Gdk.EventButton event) {
        /* We need to distinguish whether the event comes from one of the icons.
         * There doesn't seem to be a way of doing this directly so we check the window width */
        if (event.window.get_width () < 24)
            return false;

        reset_elements_states ();

        if (timeout != -1) {
            Source.remove ((uint) timeout);
            timeout = -1;
        }
        
        if (is_focus)
            return base.button_release_event (event);


        if (event.button == 1) {
            var el = get_element_from_coordinates ((int) event.x, (int) event.y);
            if (el != null) {
                selected = elements.index_of (el);
                var newpath = get_path_from_element (el);
                path_changed (get_file_for_path (newpath));
            } else
                grab_focus ();
        }
        
        return base.button_release_event (event);
    }

    public void on_icon_press (Gtk.EntryIconPosition pos, Gdk.Event event) {
        if (pos == Gtk.EntryIconPosition.SECONDARY) {
            if (is_focus)
                on_activate ();
            else
                reload ();
        }
    }

    void on_change () {
        if (ignore_change) {
            ignore_change = false;
            return;
        }

        text_completion = "";
        need_completion ();
    }
    
    void after_realize () {
        /* After realizing, we take a reference on the Gdk.Window of the Entry so 
         * we can set the cursor icon as needed. This relies on Gtk storing the
         * owning widget as the user data on a Gdk.Window. The required window   
         * will be the first child of the entry. 
         */
        entry_window = get_window ().get_children_with_user_data (this).data;
    }

    bool after_motion_notify (Gdk.EventMotion event) {

        if (is_focus)
            return false;

        int x = (int) event.x;
        double x_render = 0;
        double x_previous = -10;
        set_tooltip_text ("");

        foreach (BreadcrumbsElement element in elements) {
            if (element.display) {
                x_render += element.real_width;
                if (x <= x_render + 5 && x > x_previous + 5) {
                    selected = elements.index_of (element);
                    set_tooltip_text ("Go to %s".printf (element.text));
                    break;
                }

                x_previous = x_render;
            }
        }

        if (event.x > 0 && event.x < x_render + 5)
            set_entry_cursor (new Gdk.Cursor (Gdk.CursorType.ARROW));
        else
            set_entry_cursor (null);

        return false;
    }

    bool on_focus_out (Gdk.EventFocus event) {
        if (is_focus)
            ignore_focus_in = true;
        else
            reset ();

        return base.focus_out_event (event);
    }

    void reset () {
        ignore_focus_in = false;
        set_entry_text ("");
    }

    bool on_focus_in (Gdk.EventFocus event) {
        if (ignore_focus_in)
            return base.focus_in_event (event);

        set_entry_text (GLib.Uri.unescape_string (get_elements_path ()));
        return base.focus_in_event (event);
    }

    void on_grab_focus () {
        select_region (0, 0);
        set_position (-1);
    }

    void on_activate () {
        string path = text + text_completion;
        path_changed (get_file_for_path (path));
        text_completion = "";
    }

    protected abstract void on_drag_leave (Gdk.DragContext drag_context, uint time);

    protected abstract void on_drag_data_received (Gdk.DragContext context,
                                                   int x,
                                                   int y,
                                                   Gtk.SelectionData selection_data,
                                                   uint info,
                                                   uint time_);

    protected abstract bool on_drag_motion (Gdk.DragContext context, int x, int y, uint time);

    protected abstract bool on_drag_drop (Gdk.DragContext context,
                                          int x,
                                          int y,
                                          uint timestamp);
    
    protected void add_icon (IconDirectory icon) {
        if (icon.gicon != null)
            icon.icon = icon_factory.load_symbolic_icon_from_gicon (button_context, icon.gicon, 16);
        else
            icon.icon = icon_factory.load_symbolic_icon (button_context, icon.icon_name, 16);

        icons.append (icon);
    }
    
    public void complete () {
        if (text_completion.length == 0)
            return;

        string path = text + text_completion;
        
        /* If there are multiple results, tab as far as we can, otherwise do the entire result */
        if (!multiple_completions) {
            set_entry_text (path + "/");
            completed ();
        } else
            set_entry_text (path);
    }
    
    public void reset_elements_states () {
        foreach (BreadcrumbsElement element in elements)
            element.pressed = false;

        queue_draw ();
    }
    
    public void set_entry_text (string text) {
        ignore_change = true;
        text_completion = "";
        this.text = text;
        set_position (-1);
    }
    
    public void set_entry_cursor (Gdk.Cursor? cursor) {
        entry_window.set_cursor (cursor ?? new Gdk.Cursor (Gdk.CursorType.XTERM));

    }
    
    public double get_all_breadcrumbs_width (out int breadcrumbs_count) {
        double total_width = 0.0;
        breadcrumbs_count = 0;
        foreach (BreadcrumbsElement element in elements) {
            if (element.display) {
                total_width += element.width;
                element.max_width = -1;
                breadcrumbs_count++;
            }
        }
        return total_width;
    }

    protected BreadcrumbsElement? get_element_from_coordinates (int x, int y) {
        double x_render = 0;
        foreach (BreadcrumbsElement element in elements) {
            if (element.display) {
                if (x_render <= x && x <= x_render + element.real_width)
                    return element;

                x_render += element.real_width;
            }
        }
        return null;
    }

    protected string get_path_from_element (BreadcrumbsElement? el) {
        /* return path up to the speficied element or, if the parameter is null, the whole path */
        string newpath = "";
        bool first = true;

        foreach (BreadcrumbsElement element in elements) {
                string s = element.text;
                if (first) {
                    if (s == "" || s == "file://")
                        newpath = "/";
                    else
                        newpath = s;

                    first = false;
                } else
                    newpath += (s + "/");

                if (el != null && element == el)
                    break;
        }
        return newpath;
    }

    /**
     * Get the current path of the PathBar, based on the elements that it contains
     **/
    public string get_elements_path () {
        return get_path_from_element (null);
    }
    
    /**
     * Gets a properly escaped GLib.File for the given path
     **/
    public File? get_file_for_path (string path) {
        string reserved_chars = (GLib.Uri.RESERVED_CHARS_GENERIC_DELIMITERS + GLib.Uri.RESERVED_CHARS_SUBCOMPONENT_DELIMITERS + " ").replace("#", "");
        string newpath = GLib.Uri.unescape_string (path ?? "");

        /* Format our path so its valid */
        if (newpath == "")
            newpath = "/";
            
        if (newpath[0] == '~')
            newpath = newpath.replace("~", Environment.get_home_dir ());

        if (!newpath.contains("://")) {
            if (!newpath.has_prefix ("/"))
                newpath = "/" + newpath;

            newpath = Marlin.ROOT_FS_URI + newpath;
        } else {
            string [] parts = newpath.split ("://", 3);
            if (parts.length > 2) {
                warning ("Invalid path");
                return null;
            }
        }

        newpath = newpath.replace("ssh:", "sftp:");
        newpath = GLib.Uri.escape_string (newpath, reserved_chars, true);

        File file = File.new_for_commandline_arg (newpath);
        return file;
    }
    
    /**
     * Select the breadcrumb to make a right click. This function check
     * where the user click, then, it loads a context menu with the others
     * directory in it parent.
     * See load_right_click_menu() for the context menu.
     *
     * @param event a button event to compute the coords of the new menu.
     *
     **/
    private bool select_bread_from_coord (Gdk.EventButton event) {
        var el = get_element_from_coordinates ((int) event.x, (int) event.y);

        if (el != null) {
            var newpath = get_path_from_element (el);
            current_right_click_path = newpath;
            current_right_click_root = Marlin.Utils.get_parent (newpath);
            double menu_x_root;

            if (el.x - space_breads < 0)
                menu_x_root = event.x_root - event.x + el.x;
            else
                menu_x_root = event.x_root - event.x + el.x - space_breads;

            double menu_y_root = event.y_root - event.y + get_allocated_height ();
            var style_context = get_style_context ();
            var padding = style_context.get_padding (style_context.get_state ());
            load_right_click_menu (menu_x_root, menu_y_root - padding.bottom - padding.top);
            return true;
        }
        return false;
    }    

    public virtual string? update_breadcrumbs (string newpath, string breadpath) {
        string strloc;

        if (Posix.strncmp (newpath, "./", 2) == 0)
            return null;

        if (newpath[0] == '/')
            strloc = newpath;
        else if (Posix.strncmp (newpath, "~/", 2) == 0)
            strloc = Environment.get_home_dir ();
        else
            strloc = breadpath + newpath;

        return strloc;
    }

    /**
     * Change the Breadcrumbs content.
     *
     * This function will try to see if the new/old BreadcrumbsElement can
     * be animated.
     **/
    public void change_breadcrumbs (string newpath, bool old = false) {
        var explode_protocol = Uri.unescape_string (newpath).split ("://");

        if (explode_protocol.length > 1) {
            protocol = explode_protocol[0] + "://";
            current_path = explode_protocol[1];
        } else {
            current_path = newpath;
            protocol = Marlin.ROOT_FS_URI;
        }

        selected = -1;
        var breads = current_path.split ("/");
        var newelements = new Gee.ArrayList<BreadcrumbsElement> ();
        string s = protocol == Marlin.ROOT_FS_URI ? "" : protocol;
        newelements.add (new BreadcrumbsElement (s));


        /* Add every mounted volume in our IconDirectory in order to load them properly in the pathbar if needed */
        var volume_monitor = VolumeMonitor.get ();
        var mount_list = volume_monitor.get_mounts ();

        foreach (var mount in mount_list) {
            IconDirectory icon_directory = { mount.get_root ().get_path (),
                                             null, false,
                                             mount.get_icon (),
                                             null, mount.get_root ().get_path ().split ("/"),
                                             true, mount.get_name () };

            if (mount.get_root ().get_path () != null) {
                icon_directory.exploded[0] = "/";
                add_icon (icon_directory);
            }
        }

        foreach (string dir in breads) {
            if (dir != "")
                newelements.add (new BreadcrumbsElement (dir));
        }

        int max_path = int.min (elements.size, newelements.size);
        foreach (IconDirectory icon in icons) {
            if (icon.protocol && icon.path == protocol) {
                newelements[0].set_icon(icon.icon);
                newelements[0].text_displayed = icon.text_displayed;
                break;
            } else if (!icon.protocol && icon.exploded.length <= newelements.size) {
                bool found = true;
                int h = 0;

                for (int i = 1; i < icon.exploded.length; i++) {
                    if (icon.exploded[i] != newelements[i].text) {
                        found = false;
                        break;
                    }
                    h = i;
                }

                if (found) {
                    for (int j = 0; j < h; j++)
                        newelements[j].display = false;

                    newelements[h].display = true;
                    newelements[h].set_icon (icon.icon);
                    newelements[h].display_text = (icon.text_displayed != null) || !icon.break_loop;
                    newelements[h].text_displayed = icon.text_displayed;

                    if (icon.break_loop)
                        break;

                }
            }
        }

        /* Remove the volume icons we added just before. */
        /*for (uint i = icons.length () - 1; i >= icons_list; i--) {
            icons.remove (icons.nth_data (i));
        }


        if (anim > 0) {
            Source.remove (anim);
            anim = 0;
        }

        if (newelements.size > elements.size) {
            view_old = false;
            newbreads = newelements.slice (max_path, newelements.size);
            animate_new_breads ();
        } else if (newelements.size < elements.size) {
            view_old = true;
            newbreads = elements.slice (max_path, elements.size);
            animate_old_breads ();
        } else {
            newbreads = newelements.slice (max_path, newelements.size);
            animate_new_breads ();
        }*/

        
        if (old) {
            view_old = true;
            newbreads = newelements.slice (max_path, elements.size);
            animate_old_breads ();
        } else {
            newbreads = newelements.slice (max_path, newelements.size);   
            animate_new_breads ();
        }
        
        elements.clear ();
        elements = newelements;
    }

    uint anim = 0;

    /* A threaded function to animate the old BreadcrumbsElement */
    private void animate_old_breads () {
        anim_state = animation_visible ? 0.0 : 0.95;
        var step = animation_visible ? 0.05 : 0.001;

        foreach (BreadcrumbsElement bread in newbreads)
            bread.offset = anim_state;

        if (anim > 0)
            Source.remove(anim);

        anim = Timeout.add (1000/60, () => {
            anim_state += step;
            /* FIXME: Instead of this hacksih if( != null), we should use a
             * nice mutex */
            if (newbreads == null) {
                anim = 0;
                return false;
            }

            if (anim_state > 1.0 - step) {
                foreach (BreadcrumbsElement bread in newbreads)
                    bread.offset = 1.0;

                newbreads = null;
                view_old = false;
                queue_draw ();
                anim = 0;
                return false;
            } else {
                foreach (BreadcrumbsElement bread in newbreads)
                    bread.offset = anim_state;

                queue_draw ();
                return true;
            }
        });
    }

    /* A threaded function to animate the new BreadcrumbsElement */
    private void animate_new_breads () {
        anim_state = animation_visible ? 1.0 : 0.007;
        double step = animation_visible ? 0.08 : 0.001;

        foreach (BreadcrumbsElement bread in newbreads)
            bread.offset = anim_state;

        if (anim > 0)
            Source.remove (anim);

        anim = Timeout.add (1000/60, () => {
            anim_state -= step;
            /* FIXME: Instead of this hacksih if( != null), we should use a
             * nice mutex */
            if (newbreads == null) {
                anim = 0;
                return false;
            }

            if (anim_state < step) {
                foreach (BreadcrumbsElement bread in newbreads)
                    bread.offset = 0.0;

                newbreads = null;
                view_old = false;
                anim = 0;
                queue_draw ();
                return false;
            } else {
                foreach (BreadcrumbsElement bread in newbreads)
                    bread.offset = anim_state;

                queue_draw ();
                return true;
            }
        });
    }

    public override bool draw (Cairo.Context cr) {
        if (button_context_active == null) {
            button_context_active = new Gtk.StyleContext ();
            button_context_active.set_path(button_context.get_path ());
            button_context_active.set_state (Gtk.StateFlags.ACTIVE);
        }
        
        base.draw (cr);
        double height = get_allocated_height ();
        double width = get_allocated_width ();

        if (!is_focus) {
            double margin = y;

            /* Ensure there is an editable area to the right of the breadcrumbs */
            double width_marged = width - 2*margin - MINIMUM_LOCATION_BAR_ENTRY_WIDTH;
            double height_marged = height - 2*margin;
            double x_render = margin;
            int breadcrumbs_displayed = 0;
            double max_width = get_all_breadcrumbs_width (out breadcrumbs_displayed);

            if (max_width > width_marged) { /* let's check if the breadcrumbs are bigger than the widget */
                /* each element must not be bigger than the width/breadcrumbs count */
                double max_element_width = width_marged/breadcrumbs_displayed;

                foreach (BreadcrumbsElement element in elements) {
                    if (element.display && element.width < max_element_width) {
                        breadcrumbs_displayed --;
                        max_element_width += (max_element_width - element.width)/breadcrumbs_displayed;
                    }
                }

                foreach (BreadcrumbsElement element in elements)
                    if (element.display && element.width > max_element_width)
                        element.max_width = max_element_width - element.last_height/2;
            }

            cr.save ();
            /* Really draw the elements */
            foreach (BreadcrumbsElement element in elements) {
                if (element.display) {
                    x_render = element.draw (cr, x_render, margin, height_marged, button_context, this);
                    /* save element x axis position */
                    element.x = x_render - element.real_width;
                }
            }

            /* Draw the old breadcrumbs, only for the animations */
            if (view_old)
                foreach (BreadcrumbsElement element in newbreads)
                    if (element.display)
                        x_render = element.draw(cr, x_render, margin, height_marged, button_context, this);
                        
            cr.restore ();
        } else {
            if (text_completion != "") {
                int layout_width, layout_height;
                double text_width, text_height;
                
                cr.set_source_rgba (0, 0, 0, 0.4);
                Pango.Layout layout = create_pango_layout (text);
                layout.get_size (out layout_width, out layout_height);
                text_width = Pango.units_to_double (layout_width);
                text_height = Pango.units_to_double (layout_height);
                cr.move_to (text_width + 4, text_height / 4);
                layout.set_text (text_completion, -1);
                Pango.cairo_show_layout (cr, layout);
            }
        }

        return true;
    }

    protected abstract void load_right_click_menu (double x, double y);
}


namespace Marlin.Utils {
    public string get_parent (string newpath) {
        var file = File.new_for_commandline_arg (newpath);
        return file.get_parent ().get_uri ();
    }
}
