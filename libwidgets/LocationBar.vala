/*
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

using Gtk;

namespace Marlin
{
    public const string ROOT_FS_URI = "file://";
}

public struct Marlin.View.Chrome.IconDirectory
{
    string path;
    string icon_name;
    bool protocol;
    GLib.Icon gicon;
    Gdk.Pixbuf icon;
    string[] exploded;
    bool break_loop;
    string? text_displayed;
}

public abstract class Marlin.View.Chrome.BasePathBar : EventBox
{
	public string current_right_click_path;
    public string current_right_click_root;
    //double right_click_root;

    /* if we must display the BreadcrumbsElement which are in  newbreads. */
    bool view_old = false;

    /* Used to decide if this button press event must be send to the
     * integrated entry or not. */
    double x_render_saved = 0;

    /* if we have the focus or not
     * FIXME: this should be replaced with some nice Gtk.Widget method. */
    public new bool focus = false;

    public Gtk.ActionGroup clipboard_actions;
    
    /* This list will contain all BreadcrumbsElement */
    Gee.ArrayList<BreadcrumbsElement> elements;
    
    /* This list will contain the BreadcrumbsElement which are animated */
    Gee.List<BreadcrumbsElement> newbreads;
    
    /* A flag to know when the animation is finished */
    double anim_state = 0;

    Gtk.StyleContext button_context;
    Gtk.StyleContext button_context_active;
    public BreadcrumbsEntry entry;

    /**
     * When the user click on a breadcrumb, or when he enters a path by hand
     * in the integrated entry
     **/
    public signal void activate_alternate(string path);
    public signal void changed(string changed);
    public signal void need_completion();

    List<IconDirectory?> icons;
    
    string text = "";

    int selected = -1;
    int space_breads = 12;
    int x;
    int y;
    string protocol;

    public signal void escape();

    private int timeout = -1;

    int left_padding;
    int right_padding;

    private Granite.Services.IconFactory icon_factory;


    construct
    {
        add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                  | Gdk.EventMask.BUTTON_RELEASE_MASK
                  | Gdk.EventMask.KEY_PRESS_MASK
                  | Gdk.EventMask.KEY_RELEASE_MASK
                  | Gdk.EventMask.POINTER_MOTION_MASK
                  | Gdk.EventMask.LEAVE_NOTIFY_MASK);
        init_clipboard();
        icon_factory = Granite.Services.IconFactory.get_default ();
        icons = new List<IconDirectory?>();

        button_context = get_style_context();
        button_context.add_class("button");
        button_context.add_class("raised");
        button_context.add_class("marlin-pathbar");
        button_context.add_class("pathbar");

        Gtk.Border border = button_context.get_padding(Gtk.StateFlags.NORMAL);
        Granite.Widgets.Utils.set_theming (this, ".noradius-button{border-radius:0px;}", null,
                                           Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        left_padding = 5;//border.left;
        right_padding = border.right;

        set_can_focus(true);
        set_visible_window (false);
        
        /* x padding */
        x = 0;
        /* y padding */
        y = 0;
            
        elements = new Gee.ArrayList<BreadcrumbsElement>();

        entry = new BreadcrumbsEntry();

        entry.enter.connect(on_entry_enter);

        /* Let's connect the signals ;)
         * FIXME: there could be a separate function for each signal */
        entry.need_draw.connect(queue_draw);

        entry.left.connect(() => {
            if(elements.size > 0)
            {
                var element = elements[elements.size - 1];
                elements.remove(element);
                if(element.display)
                {
                    if(entry.text[0] != '/')
                    {
                        entry.text = element.text + "/" + entry.text;
                        entry.cursor = element.text.length + 1;
                    }
                    else
                    {
                        entry.text = element.text + entry.text;
                        entry.cursor = element.text.length;
                    }
                    entry.reset_selection();
                }
            }
        });

        entry.left_full.connect(() => {
            string tmp = entry.text;
            string tmp_entry = "";

            foreach(BreadcrumbsElement element in elements)
            {
                if(element.display)
                {
                    if(tmp_entry[0] != '/')
                    {
                        tmp_entry += element.text + "/";
                    }
                    else
                    {
                        tmp_entry += element.text;
                    }
                }
            }
            entry.text = tmp_entry + tmp;
            elements.clear();
        });

        entry.backspace.connect(() => {
            if(elements.size > 0)
            {
                string strloc = get_elements_path ();
                File location = File.new_for_commandline_arg (strloc);
                location = location.get_parent ();
                if (location == null)
                    location = File.new_for_commandline_arg (protocol);
                changed  (location.get_uri() + "/");
                grab_focus();
            }
        });

        entry.escape.connect(() => {
            escape();
        });

        entry.need_completion.connect(() => { need_completion(); });
        
        entry.paste.connect( () => {
            var display = get_display();
            Gdk.Atom atom = Gdk.SELECTION_CLIPBOARD;
            Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display(display,atom);
            clipboard.request_text(request_text);
        });

        entry.hide();


        /* Drag and drop */
        Gtk.TargetEntry target_uri_list = {"text/uri-list", 0, 0};
        Gtk.drag_dest_set(this, Gtk.DestDefaults.ALL, {target_uri_list}, Gdk.DragAction.MOVE);
        drag_begin.connect(on_drag_begin);
        drag_leave.connect(on_drag_leave);
        drag_motion.connect(on_drag_motion);
        drag_data_received.connect(on_drag_data_received);
    }

    void on_drag_begin(Gdk.DragContext drag_context) {
        critical("Start drag...");
    }

    void on_drag_leave(Gdk.DragContext drag_context, uint time) {
        foreach(BreadcrumbsElement element in elements) {
            if(element.pressed) {
                element.pressed = false;
                queue_draw();
                break;
            }
        }
    }

    void on_drag_data_received (Gdk.DragContext context, int x, int y, Gtk.SelectionData selection_data, uint info, uint time_) {
        var real_action = context.get_selected_action();
        List<GLib.File> uris = new List<GLib.File>();
        foreach(var uri in selection_data.get_uris()) {
            print("Path to move: %s\n", uri);
            uris.append(File.new_for_uri(uri));
        }

        var el = get_element_from_coordinates (x, y);
        if (el != null) {
            var newpath = get_path_from_element (el);
            print("Move to: %s\n", newpath);
            var target_file = GLib.File.new_for_uri(newpath);
            on_file_droped(uris, target_file, real_action);
        }
    }
        
    protected abstract void on_file_droped(List<GLib.File> uris, GLib.File target_file, Gdk.DragAction real_action);


    bool on_drag_motion(Gdk.DragContext context, int x, int y, uint time) {
        Gtk.drag_unhighlight(this);
        
        foreach(BreadcrumbsElement element in elements)
            element.pressed = false;
        var el = get_element_from_coordinates (x, y);
        if (el != null) 
            el.pressed = true;
        else
            Gdk.drag_status (context, 0, time);
        queue_draw ();

        return false;
    }

    private BreadcrumbsElement? get_element_from_coordinates (int x, int y) 
    {
        double x_render = 0;
        foreach(BreadcrumbsElement element in elements) {
            if(element.display) {
                if(x_render <= x <= x_render + element.real_width)
                    return element;
                x_render += element.real_width;
            }
        }

        return null;
    }
   
    private string get_path_from_element (BreadcrumbsElement el)
    {
        string newpath = protocol;
        
        foreach(BreadcrumbsElement element in elements) {
            if(element.display) {
                newpath += element.text + "/";
                if (element == el)
                    break;
            }
        }

        return newpath;
    }

    protected void add_icon(IconDirectory icon)
    {
        if (icon.gicon != null)
            icon.icon = icon_factory.load_symbolic_icon_from_gicon (button_context, icon.gicon, 16);
        else
            icon.icon = icon_factory.load_symbolic_icon (button_context, icon.icon_name, 16);
        icons.append(icon);
    }

    protected void init_clipboard ()
    {
        clipboard_actions = new Gtk.ActionGroup ("ClipboardActions");
        clipboard_actions.add_actions (action_entries, this);
    }

    static const Gtk.ActionEntry[] action_entries = {
/* name, stock id */         { "Cut", Stock.CUT,
/* label, accelerator */       null, null,
/* tooltip */                  N_("Cut the selected text to the clipboard"),
                             action_cut },
/* name, stock id */         { "Copy", Stock.COPY,
/* label, accelerator */       null, null,
/* tooltip */                 N_("Copy the selected text to the clipboard"),
                            action_copy },
/* name, stock id */        { "Paste", Stock.PASTE,
/* label, accelerator */      null, null,
/* tooltip */                 N_("Paste the text stored on the clipboard"),
                            action_paste },
/* name, stock id */        { "Paste Into Folder", Stock.PASTE,
/* label, accelerator */      null, null,
/* tooltip */                 N_("Paste the text stored on the clipboard"),
                            action_paste }
     };

    /**
     * Get the current path of the PathBar, based on the elements that it contains
     **/
    public string get_elements_path ()
    {
        string strpath = "";
        strpath = protocol;
        foreach(BreadcrumbsElement element in elements)
        {
            if(element.display) 
                strpath += element.text + "/"; /* sometimes, + "/" is useless
                                             * but we are never careful enough */
            /* FIXME make sure the comment never happen
             * -> it seems to be necessary in all cases */
        }
        
        return strpath;
    }

    private void action_paste(Gtk.Action action)
    {
        var display = get_display();
        Gdk.Atom atom = Gdk.SELECTION_CLIPBOARD;
        Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display(display,atom);
        clipboard.request_text(request_text);
    }

    private void action_copy(Gtk.Action action)
    {
        string? selection = entry.get_selection();
        if(selection != null) { /* else, it means that there is no selection */
            var display = get_display();
            Gdk.Atom atom = Gdk.SELECTION_CLIPBOARD;
            Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display(display,atom);
            clipboard.set_text(entry.get_selection(), entry.get_selection().length);
        }
    }
    
    private void action_cut(Gtk.Action action)
    {
        action_copy(action);
        entry.delete_selection();
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
    private bool select_bread_from_coord(Gdk.EventButton event)
    {
        var el = get_element_from_coordinates ((int) event.x, (int) event.y);
        if (el != null) {
            var newpath = get_path_from_element (el);
            current_right_click_path = newpath;
            current_right_click_root = Marlin.Utils.get_parent(newpath);
            double menu_x_root;
            if (el.x - space_breads < 0)
                menu_x_root = event.x_root - event.x + el.x;
            else
                menu_x_root = event.x_root - event.x + el.x - space_breads;
            double menu_y_root = event.y_root - event.y + get_allocated_height ();
            load_right_click_menu (menu_x_root, menu_y_root);
            return true;
        }

        return false;
    }

    public override bool button_press_event(Gdk.EventButton event)
    {
        foreach(BreadcrumbsElement element in elements)
            element.pressed = false;
        var el = get_element_from_coordinates ((int) event.x, (int) event.y);
        if (el != null) 
            el.pressed = true;
        queue_draw();

        if(timeout == -1 && event.button == 1) {
            timeout = (int) Timeout.add(800, () => {
                select_bread_from_coord(event);
                timeout = -1;
                return false;
            });
        }
        if(event.button == 2) {
            if (el != null) {
                selected = elements.index_of(el);
                var newpath = get_path_from_element (el);
                activate_alternate (newpath);
            }
        }
        if(event.button == 3)
        {
            return select_bread_from_coord(event);
        }
        if(focus)
        {
            event.x -= x_render_saved;
            entry.mouse_press_event(event, get_allocated_width() - x_render_saved);
        }
        return true;
    }

    public override bool button_release_event(Gdk.EventButton event)
    {
        reset_elements_states ();
        if(timeout != -1){
            Source.remove((uint) timeout);
            timeout = -1;
        }
        if(event.button == 1)
        {
            var el = get_element_from_coordinates ((int) event.x, (int) event.y);
            if (el != null) {
                selected = elements.index_of(el);
                var newpath = get_path_from_element (el);
                print("%s\n\n\n", newpath);
                changed(newpath);
            } else {
                grab_focus ();
            }
        }
        if(focus)
        {
            event.x -= x_render_saved;
            entry.mouse_release_event(event);
        }
        return true;
    }

    private void on_entry_enter()
    {
        text = get_elements_path ();
        if(text != "")
            changed(text + "/" + entry.text + entry.completion);
        else
            changed(entry.text + entry.completion);
            
        //entry.reset();
    }

    public override bool key_press_event(Gdk.EventKey event)
    {
        entry.key_press_event(event);
        queue_draw();
        return true;
    }

    public override bool key_release_event(Gdk.EventKey event)
    {
        entry.key_release_event(event);
        queue_draw();
        return true;
    }

    public virtual string? update_breadcrumbs (string newpath, string breadpath)
    {
        string strloc;

        warning ("change_breadcrumb text %s", newpath);
        if (Posix.strncmp (newpath, "./", 2) == 0) {
            entry.reset ();
            return null;
        }

        if (newpath[0] == '/')
        {
            strloc = newpath;
        }
        else if (Posix.strncmp (newpath, "~/", 2) == 0)
        {
            strloc = Environment.get_home_dir ();
        }
        else
        {
            strloc = breadpath + newpath;
        }
        
        return strloc;

    }

    /**
     * Change the Breadcrumbs content.
     *
     * This function will try to see if the new/old BreadcrumbsElement can
     * be animated.
     **/
    public void change_breadcrumbs(string newpath)
    {
        var explode_protocol = newpath.split("://");
        if(explode_protocol.length > 1) {
            protocol = explode_protocol[0] + "://";
            text = explode_protocol[1];
        } else {
            text = newpath;
            protocol = Marlin.ROOT_FS_URI;
        }
        selected = -1;
        var breads = text.split("/");
        var newelements = new Gee.ArrayList<BreadcrumbsElement>();
        if(breads.length == 0 || breads[0] == "") {
            var element = new BreadcrumbsElement(protocol, left_padding, right_padding);
            newelements.add(element);
        }
        
        
        /* Add every mounted volume in our IconDirectory in order to load them properly in the pathbar if needed */
        var volume_monitor = VolumeMonitor.get();
        var mount_list = volume_monitor.get_mounts();
        var icons_list = icons.length();
        foreach(var mount in mount_list) {
            IconDirectory icon_directory = { mount.get_root().get_path(),
                                             null, false,
                                             mount.get_icon(),
                                             null, mount.get_root().get_path().split("/"),
                                             true, mount.get_name() };
            if (mount.get_root().get_path() != null) {
                icon_directory.exploded[0] = "/";
                add_icon(icon_directory);
            }
        }


        foreach(string dir in breads)
        {
            if(dir != "")
            {
                var element = new BreadcrumbsElement(dir, left_padding, right_padding);
                newelements.add(element);
            }
        }
       
        if (protocol == Marlin.ROOT_FS_URI)
            newelements[0].text = "/";
        int max_path = int.min(elements.size, newelements.size);
        
        bool same = true;
       
        for(int i = 0; i < max_path; i++)
        {
            if(newelements[i].text != elements[i].text)
            {
                same = false;
                break;
            }
        }
        
        foreach(IconDirectory icon in icons)
        {
            if(icon.protocol && icon.path == protocol)
            {
                newelements[0].set_icon(icon.icon);
                newelements[0].text_displayed = icon.text_displayed;
                break;
            }
            else if(!icon.protocol && icon.exploded.length <= newelements.size)
            {
                bool found = true;
                int h = 0;
                for(int i = 0; i < icon.exploded.length; i++)
                {
                    if(icon.exploded[i] != newelements[i].text)
                    {
                        found = false;
                        break;
                    }
                    h = i;
                }
                if(found)
                {
                    for(int j = 0; j < h; j++)
                    {
                        newelements[j].display = false;
                    }
                    newelements[h].display = true;
                    newelements[h].set_icon(icon.icon);
                    newelements[h].display_text = (icon.text_displayed != null) || !icon.break_loop;
                    newelements[h].text_displayed = icon.text_displayed;
                    if(icon.break_loop)
                    {
                        newelements[h].text = icon.path;
                        break;
                    }
                }
            }
        }

        /* Remove the volume icons we added just before. */
        for(uint i = icons.length() - 1; i >= icons_list; i--) {
            icons.remove(icons.nth_data(i));
        }

        if(newelements.size > elements.size)
        {
            view_old = false;
            newbreads = newelements.slice(max_path, newelements.size);
            animate_new_breads();
        }
        else if(newelements.size < elements.size)
        {
            view_old = true;
            newbreads = elements.slice(max_path, elements.size);
            animate_old_breads();
        }
        else
        {
            queue_draw();
        }
        
        elements.clear();
        elements = newelements;
        entry.reset();
    }
    
    uint anim = -1;

    /* A threaded function to animate the old BreadcrumbsElement */
    private void animate_old_breads()
    {
        anim_state = 0;
        foreach(BreadcrumbsElement bread in newbreads)
        {
            bread.offset = anim_state;
        }
        if(anim > 0)
            Source.remove(anim);
        anim = Timeout.add(1000/60, () => {
            anim_state += 0.05;
            /* FIXME: Instead of this hacksih if( != null), we should use a
             * nice mutex */
            if(newbreads != null)
            {
                foreach(BreadcrumbsElement bread in newbreads)
                {
                    bread.offset = anim_state;
                }
            }
            queue_draw();
            if(anim_state >= 1)
            {
                foreach(BreadcrumbsElement bread in newbreads)
                {
                    bread.offset = 1.0;
                }
                newbreads = null;
                view_old = false;
                queue_draw();
                return false;
            }
            return true;
        } );
    }

    /* A threaded function to animate the new BreadcrumbsElement */
    private void animate_new_breads()
    {
        anim_state = 1;
        foreach(BreadcrumbsElement bread in newbreads)
        {
            bread.offset = anim_state;
        }
        if(anim > 0)
            Source.remove(anim);
        anim = Timeout.add(1000/60, () => {
            anim_state -= 0.08;
            /* FIXME: Instead of this hacksih if( != null), we should use a
             * nice mutex */
            if(newbreads != null)
            {
                foreach(BreadcrumbsElement bread in newbreads)
                {
                    bread.offset = anim_state;
                }
            }
            queue_draw();
            if(anim_state <= 0)
            {
                foreach(BreadcrumbsElement bread in newbreads)
                {
                    bread.offset = 0.0;
                }
                newbreads = null;
                view_old = false;
                queue_draw();
                return false;
            }
            return true;
        } );
    }

/* disabled, waiting for deletion or fix the hardcoded stuff 
 * or just draw elements by elements with widgets state flags */
#if 0
    private void draw_selection(Cairo.Context cr)
    {
        /* If a dir is selected (= mouse hover)*/
        if(selected != -1)
        {
            int height = get_allocated_height();
            /* FIXME: this block could be cleaned up, +7 and +5 are
             * hardcoded. */
            double x_hl = y + right_padding + left_padding;
            if(selected > 0)
            {
                foreach(BreadcrumbsElement element in elements)
                {
                    if(element.display)
                    {
                        x_hl += element.real_width;
                    }
                    if(element == elements[selected - 1])
                    {
                        break;
                    }
                }
            }
            x_hl += 7;
            double first_stop = x_hl - 7*(height/2 - y)/(height/2 - height/3) + 5;
            double text_width = (elements[selected].max_width > 0 ? elements[selected].max_width : elements[selected].text_width);
            cr.move_to(first_stop,
                       y + 1);
            cr.line_to(x_hl + 3,
                       height/2);
            cr.line_to(first_stop,
                       height - y - 1);

            x_hl += text_width;

            double second_stop = x_hl - 7*(height/2 - y)/(height/2 - height/3) + 5;
            cr.line_to(second_stop,
                       height - y - 1);
            cr.line_to(x_hl + 3,
                       height/2);
            cr.line_to(second_stop,
                       y + 1);
            cr.close_path();
#if VALA_0_14
            Gdk.RGBA color = button_context.get_background_color(Gtk.StateFlags.SELECTED);
#else
            Gdk.RGBA color = Gdk.RGBA();
            button_context.get_background_color(Gtk.StateFlags.SELECTED, color);
#endif
            
            Cairo.Pattern pat = new Cairo.Pattern.linear(first_stop, y, second_stop, y);
            pat.add_color_stop_rgba(0.7, color.red, color.green, color.blue, 0);
            pat.add_color_stop_rgba(1, color.red, color.green, color.blue, 0.6);

            cr.set_source(pat);
            cr.fill();
        }
    }
#endif

    public override bool motion_notify_event(Gdk.EventMotion event)
    {
        int x = (int)event.x;
        double x_render = 0;
        double x_previous = -10;
        selected = -1;
        set_tooltip_text("");
        foreach(BreadcrumbsElement element in elements)
        {
            if(element.display)
            {
                x_render += element.real_width;
                if(x <= x_render + 5 && x > x_previous + 5)
                {
                    selected = elements.index_of(element);
                    //TODO doesn't work
                    set_tooltip_text(_("Go to %s").printf(element.text));
                    break;
                }
                x_previous = x_render;
            }
        }
        event.x -= x_render_saved;
        entry.mouse_motion_event(event, get_allocated_width() - x_render_saved);
        if(event.x > 0 && event.x + x_render_saved < get_allocated_width() - entry.arrow_img.get_width())
        {
            get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.XTERM));
        }
        else
        {
            get_window().set_cursor(null);
        }
        queue_draw();
        return true;
    }

    public override bool leave_notify_event(Gdk.EventCrossing event)
    {
        selected = -1;
        entry.hover = false;
        queue_draw();
        get_window().set_cursor(null);
        return false;
    }

    public override bool focus_out_event(Gdk.EventFocus event)
    {
        focus = false;
        //button_context = button_widget_context;
        button_context.set_state (StateFlags.NORMAL);
        entry.hide();
        return true;
    }
    
    public override bool focus_in_event(Gdk.EventFocus event)
    {
        entry.show();
        //button_context = entry_context;
        //button_context.set_state (StateFlags.ACTIVE);
        focus = true;
        return true;
    }
    
    private void request_text(Gtk.Clipboard clip, string? text)
    {
        if(text != null)
            entry.insert(text.replace("\n", ""));
    }

    public double get_all_breadcrumbs_width(out int breadcrumbs_count)
    {
        double max_width = 0.0;
        breadcrumbs_count = 0;

        foreach(BreadcrumbsElement element in elements)
        {
            if(element.display)
            {
                max_width += element.width;
                element.max_width = -1;
                breadcrumbs_count++;
            }
        }
        return max_width;
    }

    public void reset_elements_states ()
    {
        foreach(BreadcrumbsElement element in elements)
            element.pressed = false;
        queue_draw();
    }

    public override bool draw(Cairo.Context cr)
    {
        if (button_context_active == null) {
            button_context_active = new Gtk.StyleContext();
            button_context_active.set_path(button_context.get_path());
            button_context_active.set_state(Gtk.StateFlags.ACTIVE);
        }

        //button_context.set_state (StateFlags.NORMAL);
        //propagate_draw (get_child (), cr);
        double height = get_allocated_height();
        double width = get_allocated_width();
        double margin = y;

        double width_marged = width - 2*margin;
        double height_marged = height - 2*margin;
        double x_render = margin;

        /* Draw toolbar background */
        button_context.render_background (cr, 0, margin, width, height_marged);

        int breadcrumbs_displayed = 0;
        double max_width = get_all_breadcrumbs_width(out breadcrumbs_displayed);

        if(max_width > width_marged) /* let's check if the breadcrumbs are bigger than the widget */
        {
            /* each element must not be bigger than the width/breadcrumbs count */
            double max_element_width = width_marged/breadcrumbs_displayed;

            foreach(BreadcrumbsElement element in elements)
            {
                if(element.display && element.width < max_element_width)
                {
                    breadcrumbs_displayed --;
                    max_element_width += (max_element_width - element.width)/breadcrumbs_displayed;
                }
            }

            foreach(BreadcrumbsElement element in elements)
            {
                if(element.display && element.width > max_element_width)
                {
                    element.max_width = max_element_width - element.left_padding - element.right_padding - element.last_height/2;
                }
            }
        }

        cr.save();
        /* Really draw the elements */
        foreach(BreadcrumbsElement element in elements)
        {
            if(element.display)
            {
                x_render = element.draw(cr, x_render, margin, height_marged, button_context, this);
                /* save element x axis position */
                element.x = x_render - element.real_width;
            }

        }

        /* Draw the old breadcrumbs, only for the animations */
        if(view_old)
        {
            foreach(BreadcrumbsElement element in newbreads)
            {
                if(element.display)
                {
                    x_render = element.draw(cr, x_render, margin, height_marged, button_context, this);
                }
            }
        }

        //draw_selection(cr);

        x_render_saved = x_render + space_breads/2;
        
        cr.restore();
        /* Draw frame: it must be done at the end to be on the background drawn by pressed breadcrumbs */

        if(focus) {
            cr.save();
            x_render -= height_marged/2 + 3;

            
            cr.move_to(0, 0);
            cr.line_to(0, y + height_marged + 3);
            cr.line_to(x_render, y + height_marged + 3);
            cr.line_to(x_render, y + height_marged);
            cr.line_to(x_render + height_marged/2, y+height_marged/2);
            cr.line_to(x_render, y);
            cr.line_to(x_render, 0);
            cr.close_path();
            cr.clip();
            button_context.render_frame (cr, 0, margin, width, height_marged);
            cr.restore();
            cr.save();

            cr.move_to(x_render, get_allocated_height());
            cr.line_to(x_render, y + height_marged);
            cr.line_to(x_render + height_marged/2, y+height_marged/2);
            cr.line_to(x_render, y);
            cr.line_to(x_render, 0);
            cr.line_to(get_allocated_width(), 0);
            cr.line_to(get_allocated_width(), y + height_marged);
            cr.close_path();
            cr.clip();
            button_context_active.render_background (cr, 0, margin, width, height_marged);
            button_context_active.render_frame (cr, 0, margin, width, height_marged);
            cr.restore();
            x_render += height_marged/2 + 3;
        }
        else {
            button_context.render_frame (cr, 0, margin, width, height_marged);
        }
        entry.draw(cr, x_render + space_breads/2, height, width - x_render, this, button_context);
        return true;
    }

    protected abstract void load_right_click_menu(double x, double y);
}


namespace Marlin.Utils
{
    public string get_parent(string newpath)
    {
        var file = File.new_for_commandline_arg (newpath);
        return file.get_parent ().get_uri ();
    }

    public bool has_parent(string newpath)
    {
        var file = File.new_for_commandline_arg (newpath);
        return (file.get_parent () != null);
    }
}
