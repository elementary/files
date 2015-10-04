namespace Marlin.View.Chrome {
    public interface Searchable : Gtk.Widget {
        public signal void file_selected (GLib.File file);
        public signal void cursor_changed (GLib.File? file);
        public signal void first_match_found (GLib.File? file);
        public signal void exit ();

        public abstract void cancel ();
        public abstract void search (string txt, GLib.File search_location);
        public abstract void set_search_current_directory_only (bool only);
        public abstract void set_begins_with_only (bool only);
        public abstract bool has_popped_up ();
    }
}