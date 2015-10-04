namespace Marlin.View.Chrome {
    public interface Navigatable : Gtk.Widget {
        public signal void entry_text_changed (string txt);
        public signal void activate_path (string path, Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT);
        public signal void action_icon_press ();
        public signal void primary_icon_press ();

        public abstract void set_breadcrumbs_path (string newpath);
        public abstract string get_breadcrumbs_path ();

        public abstract void set_action_icon_name (string? icon_name);
        public abstract void set_action_icon_tooltip (string? tip);
        public abstract void hide_action_icon ();

        public abstract void set_entry_text (string? txt);
        public abstract void reset ();

        public virtual void set_animation_visible (bool visible) {}
        public abstract void set_placeholder (string placeholder); /*Note: This is not the same as the Gtk.Entry placeholder_text */
        public abstract void show_default_action_icon ();
        public abstract void set_default_action_icon_tooltip ();

        public abstract string get_entry_text ();

    }
}