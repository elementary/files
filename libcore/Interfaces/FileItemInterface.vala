/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later

 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

public interface Files.FileItemInterface : Gtk.Widget {
    public abstract bool selected { get; set; default = false; }
    public abstract bool drop_pending { get; set; default = false; }
    public abstract bool cut_pending { get; set; default = false; }
    public abstract Files.File? file { get; set; default = null; }
    public abstract bool is_dummy { get; set; default = false; }
    public abstract uint pos { get; set; default = 0; }
    // x, y in view coords, not item coords
    public abstract bool is_draggable_point (double view_x, double view_y);

    public abstract void bind_file (Files.File? file);
    public abstract Gdk.Paintable get_paintable_for_drag ();
    public virtual void rebind () {bind_file (this.file);}
}
