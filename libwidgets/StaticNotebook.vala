/*
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
 *
 * This is a free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This is distributed in the hope that it will be useful,
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

using Marlin.View.Chrome;

public class Granite.Widgets.StaticNotebook :  Gtk.VBox
{
    Gtk.Notebook notebook;
    ModeButton switcher;
    public int page { set { switcher.selected = value; notebook.page = value; }
    get { return notebook.page; }}
    public StaticNotebook()
    {
        notebook = new Gtk.Notebook();
        notebook.show_tabs = false;
        switcher = new ModeButton();
        var hbox = new Gtk.HBox(false, 0);
        hbox.pack_start(new Gtk.HSeparator(), true, true);
        hbox.pack_start(switcher, false, false);
        switcher.set_margin_top(5);
        switcher.set_margin_bottom(5);
        hbox.pack_start(new Gtk.HSeparator(), true, true);
        pack_start(hbox, false, false);
        pack_start(notebook);
        
        switcher.mode_changed.connect(on_mode_changed);
    }
    
    public void append_page(Gtk.Widget widget, string label)
    {
        notebook.append_page(widget, null);
        var label_w = new Gtk.Label(label);
        label_w.set_margin_right(5);
        label_w.set_margin_left(5);
        switcher.append(label_w);
        if(switcher.selected == -1)
            switcher.selected = 0;
    }
    
    void on_mode_changed(Gtk.Widget widget)
    {
        notebook.page = switcher.selected;
    }
    
    public void remove_page(int number)
    {
        notebook.remove_page(number);
        switcher.remove(number);
    }
}