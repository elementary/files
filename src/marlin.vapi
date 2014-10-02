public void marlin_toolbar_editor_dialog_show (Marlin.View.Window mvw);

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "marlin-global-preferences.h")]
namespace Preferences {
    public GLib.Settings settings;
    public GLib.Settings marlin_icon_view_settings;
    public GLib.Settings marlin_list_view_settings;
    public GLib.Settings marlin_column_view_settings;
    public GLib.Settings gnome_mouse_settings;
}


namespace Marlin {
    [CCode (cheader_filename = "marlin-thumbnailer.h")]
    public class Thumbnailer : GLib.Object {
        public static Thumbnailer get();
        public bool queue_file (GOF.File file, out uint request, bool large);
        public bool queue_files (GLib.List<GOF.File> files, out uint request, bool large);
        public void dequeue (uint request);
    }

    [CCode (cprefix = "MarlinConnectServer", lower_case_cprefix = "marlin_connect_server_")]
    namespace ConnectServer {
        [CCode (cheader_filename = "marlin-connect-server-dialog.h")]
        public class Dialog : Gtk.Dialog {
            public Dialog (Gtk.Window window);
            public async bool display_location_async (GLib.File location) throws GLib.Error;
            public async bool fill_details_async (GLib.MountOperation operation,
                                                 string default_user,
                                                 string default_domain,
                                                 GLib.AskPasswordFlags flags);
        }
    }

    [CCode (cprefix = "MarlinClipboardManager", lower_case_cprefix = "marlin_clipboard_manager_", cheader_filename = "marlin-clipboard-manager.h")]

        public class ClipboardManager : GLib.Object {
            public ClipboardManager.get_for_display (Gdk.Display display);
            public bool get_can_paste ();
            public bool has_cutted_files (GOF.File file);
            public bool has_file (GOF.File file);
            public void copy_files (GLib.List files);
            public void cut_files (GLib.List files);
            public void paste_files (GLib.File target, Gtk.Widget widget, GLib.Closure? new_file_closure);
            public signal void changed ();
        }

    [CCode (cheader_filename = "marlin-file-utilities.h")]
    public void restore_files_from_trash (GLib.List<GOF.File> *files, Gtk.Window *parent_window);
    [CCode (cheader_filename = "marlin-file-utilities.h")]
    public void get_rename_region (string filename, out int start_offset, out int end_offset, bool select_all);

    [CCode (cheader_filename = "marlin-icon-renderer.h")]
    public class IconRenderer : Gtk.CellRenderer {
        public IconRenderer ();
    }    

    [CCode (cheader_filename = "marlin-enum-types.h")]
    public enum ZoomLevel {
        SMALLEST,
        SMALLER,
        SMALL,
        NORMAL,
        LARGE,
        LARGER,
        LARGEST,
        N_LEVELS
    }

    [CCode (cheader_filename = "marlin-enum-types.h")]
    public static Gtk.IconSize zoom_level_to_stock_icon_size (ZoomLevel zoom);
    [CCode (cheader_filename = "marlin-enum-types.h")]
    public static Marlin.IconSize zoom_level_to_icon_size (ZoomLevel zoom);

    [CCode (cheader_filename = "marlin-enum-types.h")]
    public enum IconSize {
        SMALLEST = 16,
        SMALLER = 24,
        SMALL = 32,
        NORMAL = 48,
        LARGE = 64,
        LARGER = 96,
        LARGEST = 128
    }

    [CCode (cheader_filename = "marlin-view-window.h")]
    public enum OpenFlag {
        DEFAULT,
        NEW_ROOT,
        NEW_TAB,
        NEW_WINDOW
    }

    [CCode (cheader_filename = "marlin-view-window.h")]
    public enum ViewMode {
        ICON,
        LIST,
        MILLER_COLUMNS,
        CURRENT,
        PREFERRED,
        INVALID
    }
}

namespace Eel {
    [CCode (cprefix = "EelEditableLabel", lower_case_cprefix = "eel_editable_label_", cheader_filename = "eel-editable-label.h")]
    public class EditableLabel : Gtk.Misc, Gtk.Editable, Gtk.CellEditable {
        public EditableLabel (string? text = null);
        public void set_text (string text);
        public unowned string get_text ();
        public void set_justify (Gtk.Justification jtype);
        public Gtk.Justification get_justification ();
        public void set_line_wrap (bool wrap);
        public bool get_line_wrap ();
        public void set_line_wrap_mode (Pango.WrapMode mode);
        public Pango.WrapMode get_line_wrap_mode ();
        public void set_draw_outline (bool outline);
        public void select_region (int start_offset, int end_offset);
        public bool get_selection_bounds (out int start, out int end);
        public Pango.Layout get_layout ();
        public void get_layout_offsets (out int x, out int y);
        public void set_font_description (Pango.FontDescription font);
        public Pango.FontDescription get_font_description ();
        public signal void activate ();
        public signal void move_cursor (Gtk.MovementStep step, int count, bool extend_selection);
        public signal void insert_at_cursor (string text);
        public signal void delete_from_cursor (Gtk.DeleteType dtype, int count);
        public signal void cut_clipboard ();
        public signal void copy_clipboard ();
        public signal void paste_clipboard ();
        public signal void toggle_overwrite ();
        public signal void populate_popup (Gtk.Menu menu);
    }  

}
