/***
    Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)  

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
***/

[DBus (name = "org.pantheon.files.db")]
interface Tags : Object {
    public abstract bool   	showTable	(string table) 	throws IOError;
    public abstract bool 	record_uris	(Variant[] entries, string directory) 	throws IOError;
    /*public abstract bool 	deleteEntry	(string uri)	throws IOError;
      public abstract bool	clearDB		()				throws IOError;*/
}

public class Miner : Object {

    public signal void done_loading ();

    public File location;
    public Cancellable cancellable;

    private Tags tags;
    private List<File> ufiles = null;
    private List<File> ufiles_hidden = null;

    public class Miner (File directory) 
    {
        location = directory;
        cancellable = new Cancellable ();

        try {
            tags = Bus.get_proxy_sync (BusType.SESSION, "org.pantheon.files.db",
                                       "/org/pantheon/files/db");
        } catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }
        done_loading.connect (process_unknown_files);
    }

    private Variant add_entry (string uri, string content_type, int modified_time)
    {
        //var vb = new VariantBuilder (new VariantType ("as"));

        char* ptr_arr[4];
        ptr_arr[0] = uri;
        ptr_arr[1] = content_type;
        ptr_arr[2] = modified_time.to_string ();
        ptr_arr[3] = "0"; /* color */
        return new Variant.strv ((string[]) ptr_arr);

        /*vb.add ("s", uri);
        vb.add ("s", content_type);
        vb.add ("s", modified_time.to_string ());

        return vb.end ();*/
    }

    private void process_unknown_files ()
    {
        warning ("process_unknown_files");
        //HashTable<string,string>[] entries = null;
        Variant[] entries = null;

        try {
            foreach (var file in ufiles) {
                var info = file.query_info (gio_full_attrs, 0, cancellable);
                //message ("%s : %s", info.get_name (), info.get_content_type ());
                /*tags.record_uri (file.get_uri (), 
                                 info.get_content_type (),
                                 (int) info.get_attribute_uint64 (FILE_ATTRIBUTE_TIME_MODIFIED));*/
                entries += add_entry (file.get_uri (), 
                                      info.get_content_type (),
                                      (int) info.get_attribute_uint64 (FILE_ATTRIBUTE_TIME_MODIFIED));
            }

            tags.record_uris (entries, location.get_uri ());
        } catch (Error err) {
            warning ("%s", err.message);
        }
        loop.quit ();
    }

    private string gio_attrs = "standard::name,standard::type,standard::is-hidden,standard::is-backup,standard::fast-content-type,time::modified";
    private string gio_full_attrs = "standard::name,standard::type,standard::is-hidden,standard::is-backup,standard::content-type,time::modified";

    public async void process_directory ()
    {
        try {
            var enumerator = yield location.enumerate_children_async (gio_attrs, 0, 0, cancellable);
            while (true) {
                var files = yield enumerator.next_files_async (1024, 0, cancellable);
                if (files == null)
                    break;

                foreach (var f in files)
                {
                    //unowned string name = f.get_name ();
                    /*if (f.get_file_type () == FileType.REGULAR && name.has_suffix (".desktop")
                      && !filenames_cache.contains (name))*/
                    //yield load_eaction_file (directory.get_child (name));
                    var ftype = f.get_attribute_string (FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE);
                    if (ftype == "application/octet-stream") {
                        //message ("%s", name);
                        if (f.get_is_hidden () || f.get_is_backup ())
                            ufiles_hidden.prepend (location.get_child (f.get_name()));
                        else
                            ufiles.prepend (location.get_child (f.get_name()));
                    }
                }
            }
        } catch (Error err) {
            warning ("%s", err.message);
        }
        done_loading ();
    }
}

MainLoop loop;

public static int main () {
    //Miner miner = new Miner (File.new_for_path ("/home/kitkat"));
    Miner miner = new Miner (File.new_for_path ("/usr/bin"));
    miner.process_directory ();

    loop = new MainLoop ();
    loop.run ();

    return 0;
}

