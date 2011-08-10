
public class Marlin.CellRendererDisk : Gtk.CellRendererText {

    public int free_space { set; get; }
    public int disk_size { set; get; }

    public CellRendererDisk () {
    }

    /**
     * Function called by gtk to determine the size request of the cell.
     **/
    public override void get_size (Gtk.Widget widget, Gdk.Rectangle? cell_area,
                                   out int x_offset, out int y_offset,
                                   out int width, out int height) {
        height = 50;
        width = 250; /* Hardcoded, maybe it should be configurable */
    }

    /**
     * Function called by gtk to draw the cell content.
     **/
    public override void render (Cairo.Context cr, Gtk.Widget widget,
                                 Gdk.Rectangle background_area, Gdk.Rectangle area,
                                 Gtk.CellRendererState flags) {
        base.render(cr, widget, background_area, area, flags);
        if(free_space > 0)
        {
            Gtk.StyleContext context = widget.get_style_context();
            Gdk.cairo_set_source_rgba(cr, context.get_background_color(Gtk.StateFlags.SELECTED));
            cr.set_line_width(2);
            cr.move_to(area.x, area.y + area.height);
            cr.line_to(area.x + area.width, area.y + area.height);
            cr.stroke();

            Gdk.cairo_set_source_rgba(cr, context.get_color(Gtk.StateFlags.SELECTED));
            cr.set_line_width(2);
            cr.move_to(area.x, area.y + area.height);
            cr.line_to(area.x + (int)(((double)free_space)/((double)disk_size)*((double)area.width)), area.y + area.height);
            cr.stroke();
        }
    }
}
