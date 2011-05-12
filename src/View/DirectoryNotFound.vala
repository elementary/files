using Gtk;
namespace Marlin.View
{
    class ImageButton : Button
    {
        public ImageButton(string title, string subtitle, string icon_name)
        {
            var hbox = new HBox(false, 15);
            
            /* Image */
            hbox.pack_start(new Image.from_icon_name (icon_name, Gtk.IconSize.DIALOG), false, false);
            var vbox = new VBox(false, 0);
            
            /* Title */
            var label = new Label(title);
            label.set_alignment(0, 0.5f);
            vbox.pack_start(label);
            
            /* Subtitle */
            label = new Label(subtitle);
            label.set_sensitive(false);
            label.set_alignment(0, 0.5f);
            
            /* Pack all */
            vbox.pack_start(label);
            hbox.pack_start(vbox);

            set_relief(Gtk.ReliefStyle.NONE);
            add(hbox);
        }
    }

    public class DirectoryNotFound : Alignment
    {
        GOF.Directory.Async dir_saved;
        ViewContainer window;
        public DirectoryNotFound(GOF.Directory.Async dir, ViewContainer win)
        {
            set(0.5f,0.4f,0,0.1f);
            dir_saved = dir;
            window = win;
            var box = new VBox(false, 5);
            var label = new Label("");

            label.set_markup("<span size=\"x-large\">%s</span>".printf(_("Folder does not exist")));
            box.pack_start(label, false, false);

            label = new Label(_("Marlin can't find the folder %s").printf(dir.location.get_basename()));
            label.set_sensitive(false);
            label.set_alignment(0.5f, 0.0f);
            box.pack_start(label, true, true);

            var create_button = new ImageButton(_("Create"), _("Create the folder %s").printf(dir.location.get_basename()), "folder-new");
            create_button.pressed.connect( () => {
                Marlin.FileOperations.new_folder_with_name(null, null,
                                                           dir_saved.location.get_parent(),
                                                           dir_saved.location.get_basename(),
                                                           null, null);
                dir_saved.exists = true;
                window.reload();
                dir_saved.cancel();
                
            });
            box.pack_start(create_button, false, false);
            
            add(box);
        }
    }
}
